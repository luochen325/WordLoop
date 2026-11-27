from __future__ import annotations

import hashlib
import json
from pathlib import Path

from fastapi import APIRouter, HTTPException, Query

from ..config import MEDIA_DIR
from ..database import get_conn, now_iso, row_to_word
from ..schemas import ContextRequest, LookupRequest
from ..services import llm
from ..services.image_gen import ImageError, generate_word_image

router = APIRouter(prefix="/api/ai", tags=["ai"])

# 语境短文/对话的进程内缓存：同一组单词和模式重复生成时直接返回
_context_cache: dict[str, dict] = {}


def _load_word(word_id: int):
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM words WHERE id = ?", (word_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="单词不存在")
    return row_to_word(row)


def _cached_card(word_id: int) -> dict | None:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT payload FROM cards WHERE word_id = ?", (word_id,)
        ).fetchone()
    return json.loads(row["payload"]) if row else None


def _cached_lookup(word: str) -> dict | None:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT payload FROM lookups WHERE word = ?", (word.lower(),)
        ).fetchone()
    return json.loads(row["payload"]) if row else None


def _build_image_prompt(word: str, card: dict) -> str:
    meaning = ""
    meanings = card.get("meanings") or []
    if meanings and isinstance(meanings[0], dict):
        meaning = str(meanings[0].get("zh") or "")
    scene = str(card.get("image_prompt") or "").strip()
    prompt = (
        f'Realistic editorial photograph that literally illustrates the English word "{word}". '
        f"Core meaning: {meaning}. {scene} "
        "The main subject and action must directly and obviously show this meaning, "
        "so a viewer can guess the word without any text. "
        "Natural light, 35mm photo, high detail. No text, no letters, no watermark."
    )
    return prompt[:480]


@router.post("/context")
async def create_context(body: ContextRequest):
    """用一组目标词生成语境短文或对话。"""
    words = [word.strip() for word in body.words if word.strip()][:10]
    if not words:
        raise HTTPException(status_code=400, detail="words 不能为空")

    key = hashlib.md5(
        f"{body.mode}|{'|'.join(sorted(word.lower() for word in words))}".encode(
            "utf-8"
        )
    ).hexdigest()
    if not body.force and key in _context_cache:
        return _context_cache[key]

    try:
        result = await llm.generate_context(words, body.mode)
    except llm.LLMError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    if len(_context_cache) > 60:
        _context_cache.clear()
    _context_cache[key] = result
    return result


@router.post("/lookup")
async def lookup(body: LookupRequest):
    word = body.word.strip()
    if not word:
        raise HTTPException(status_code=400, detail="word 不能为空")

    cached = _cached_lookup(word)
    if cached is not None:
        return cached

    definition = ""
    with get_conn() as conn:
        row = conn.execute(
            "SELECT definition_en FROM words WHERE lower(word) = lower(?)", (word,)
        ).fetchone()
        if row is not None:
            definition = row["definition_en"] or ""

    try:
        card = await llm.generate_word_card(word, definition)
    except llm.LLMError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO lookups (word, payload, updated_at) VALUES (?, ?, ?)
            ON CONFLICT(word) DO UPDATE SET payload = excluded.payload,
                                            updated_at = excluded.updated_at
            """,
            (word.lower(), json.dumps(card, ensure_ascii=False), now_iso()),
        )
    return card


def _cached_text_image(word_key: str):
    with get_conn() as conn:
        return conn.execute(
            "SELECT filename FROM text_images WHERE word = ?", (word_key,)
        ).fetchone()


@router.post("/image-by-text")
async def create_image_by_text(body: LookupRequest, force: bool = Query(False)):
    """为不在 NGSL 词库里的单词/短语按文本生成并缓存配图。"""
    word = body.word.strip()
    if not word:
        raise HTTPException(status_code=400, detail="word 不能为空")
    key = word.lower()

    cached = _cached_text_image(key)
    if cached and not force:
        path = MEDIA_DIR / cached["filename"]
        if path.exists():
            return {"url": f"/api/media/{cached['filename']}", "cached": True}

    card = _cached_lookup(word)
    if card is None:
        definition = ""
        with get_conn() as conn:
            row = conn.execute(
                "SELECT definition_en FROM words WHERE lower(word) = lower(?)",
                (word,),
            ).fetchone()
            if row is not None:
                definition = row["definition_en"] or ""
        try:
            card = await llm.generate_word_card(word, definition)
        except llm.LLMError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc
        with get_conn() as conn:
            conn.execute(
                """
                INSERT INTO lookups (word, payload, updated_at) VALUES (?, ?, ?)
                ON CONFLICT(word) DO UPDATE SET payload = excluded.payload,
                                                updated_at = excluded.updated_at
                """,
                (key, json.dumps(card, ensure_ascii=False), now_iso()),
            )

    prompt = _build_image_prompt(word, card)
    digest = hashlib.md5(key.encode("utf-8")).hexdigest()[:16]
    try:
        filename = await generate_word_image(
            -1,
            word,
            prompt,
            filename_stem=f"text_{digest}",
            card=card,
        )
    except ImageError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO text_images (word, filename, prompt, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(word) DO UPDATE SET filename = excluded.filename,
                                            prompt = excluded.prompt,
                                            updated_at = excluded.updated_at
            """,
            (key, filename, prompt, now_iso()),
        )
    return {"url": f"/api/media/{filename}", "cached": False}


@router.get("/words/{word_id}/card")
def get_card(word_id: int):
    _load_word(word_id)
    card = _cached_card(word_id)
    if card is None:
        raise HTTPException(status_code=404, detail="尚未生成该单词的卡片")
    return card


@router.post("/words/{word_id}/card")
async def create_card(word_id: int, force: bool = Query(False)):
    word = _load_word(word_id)
    if not force:
        card = _cached_card(word_id)
        if card is not None:
            return card

    try:
        card = await llm.generate_word_card(word["word"], word["definition_en"])
    except llm.LLMError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO cards (word_id, payload, updated_at) VALUES (?, ?, ?)
            ON CONFLICT(word_id) DO UPDATE SET payload = excluded.payload,
                                               updated_at = excluded.updated_at
            """,
            (word_id, json.dumps(card, ensure_ascii=False), now_iso()),
        )
    return card


@router.post("/words/{word_id}/image")
async def create_image(word_id: int, force: bool = Query(False)):
    word = _load_word(word_id)

    with get_conn() as conn:
        row = conn.execute(
            "SELECT filename FROM images WHERE word_id = ?", (word_id,)
        ).fetchone()
    if row and not force:
        path = MEDIA_DIR / row["filename"]
        if path.exists():
            return {"url": f"/api/media/{row['filename']}", "cached": True}

    card = _cached_card(word_id)
    if card is None:
        try:
            card = await llm.generate_word_card(word["word"], word["definition_en"])
        except llm.LLMError as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc
        with get_conn() as conn:
            conn.execute(
                """
                INSERT INTO cards (word_id, payload, updated_at) VALUES (?, ?, ?)
                ON CONFLICT(word_id) DO UPDATE SET payload = excluded.payload,
                                                   updated_at = excluded.updated_at
                """,
                (word_id, json.dumps(card, ensure_ascii=False), now_iso()),
            )

    prompt = _build_image_prompt(word["word"], card)
    try:
        filename = await generate_word_image(
            word_id,
            word["word"],
            prompt,
            card=card,
        )
    except ImageError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO images (word_id, filename, prompt, updated_at) VALUES (?, ?, ?, ?)
            ON CONFLICT(word_id) DO UPDATE SET filename = excluded.filename,
                                               prompt = excluded.prompt,
                                               updated_at = excluded.updated_at
            """,
            (word_id, filename, prompt, now_iso()),
        )
    return {"url": f"/api/media/{filename}", "cached": False}
