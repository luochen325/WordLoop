from __future__ import annotations

import json

from fastapi import APIRouter, HTTPException

from ..database import get_conn, now_iso
from ..schemas import GraphRequest
from ..services import llm

router = APIRouter(prefix="/api/graph", tags=["graph"])


def _cached_graph(center: str) -> dict | None:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT payload FROM graphs WHERE center = ?", (center.lower(),)
        ).fetchone()
    return json.loads(row["payload"]) if row else None


@router.post("")
async def create_graph(body: GraphRequest):
    word = body.word.strip()
    if not word:
        raise HTTPException(status_code=400, detail="word 不能为空")

    if not body.force:
        cached = _cached_graph(word)
        if cached is not None:
            return {**cached, "cached": True}

    try:
        graph = await llm.generate_graph(word)
    except llm.LLMError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO graphs (center, payload, updated_at) VALUES (?, ?, ?)
            ON CONFLICT(center) DO UPDATE SET payload = excluded.payload,
                                              updated_at = excluded.updated_at
            """,
            (word.lower(), json.dumps(graph, ensure_ascii=False), now_iso()),
        )
    return {**graph, "cached": False}


@router.get("/{word}")
def get_graph(word: str):
    cached = _cached_graph(word)
    if cached is None:
        raise HTTPException(status_code=404, detail="尚未生成该单词的网络")
    return {**cached, "cached": True}
