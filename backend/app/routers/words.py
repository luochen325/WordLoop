from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query

from ..database import get_conn, row_to_word
from ..schemas import WordOut, WordPage

router = APIRouter(prefix="/api/words", tags=["words"])


@router.get("", response_model=WordPage)
def list_words(
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    q: str = Query("", max_length=64),
):
    with get_conn() as conn:
        if q.strip():
            pattern = f"{q.strip().lower()}%"
            total = conn.execute(
                "SELECT COUNT(*) AS c FROM words WHERE word LIKE ?", (pattern,)
            ).fetchone()["c"]
            rows = conn.execute(
                "SELECT * FROM words WHERE word LIKE ? ORDER BY rank LIMIT ? OFFSET ?",
                (pattern, limit, offset),
            ).fetchall()
        else:
            total = conn.execute("SELECT COUNT(*) AS c FROM words").fetchone()["c"]
            rows = conn.execute(
                "SELECT * FROM words ORDER BY rank LIMIT ? OFFSET ?", (limit, offset)
            ).fetchall()

    return WordPage(
        total=total,
        offset=offset,
        limit=limit,
        items=[WordOut(**row_to_word(row)) for row in rows],
    )


@router.get("/by-text/{word}", response_model=WordOut)
def get_word_by_text(word: str):
    with get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM words WHERE lower(word) = lower(?)", (word,)
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="单词不存在")
    return WordOut(**row_to_word(row))


@router.get("/{word_id}", response_model=WordOut)
def get_word(word_id: int):
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM words WHERE id = ?", (word_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="单词不存在")
    return WordOut(**row_to_word(row))
