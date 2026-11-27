"""批量预生成单词卡（可选配图），用于答辩演示前预热缓存。

用法：
    python scripts/prefetch.py --start 1 --end 30
    python scripts/prefetch.py --words ability,abandon,accept --images
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from app.database import get_conn, init_db, now_iso  # noqa: E402
from app.services import llm  # noqa: E402
from app.services.image_gen import generate_word_image  # noqa: E402


def load_words(start: int, end: int, names: list[str]) -> list[dict]:
    with get_conn() as conn:
        if names:
            placeholders = ",".join("?" for _ in names)
            rows = conn.execute(
                f"SELECT * FROM words WHERE lower(word) IN ({placeholders}) ORDER BY rank",
                [name.lower() for name in names],
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM words WHERE rank BETWEEN ? AND ? ORDER BY rank",
                (start, end),
            ).fetchall()
        return [dict(row) for row in rows]


def has_card(word_id: int) -> bool:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT 1 FROM cards WHERE word_id = ?", (word_id,)
        ).fetchone()
    return row is not None


def save_card(word_id: int, card: dict) -> None:
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO cards (word_id, payload, updated_at) VALUES (?, ?, ?)
            ON CONFLICT(word_id) DO UPDATE SET payload = excluded.payload,
                                               updated_at = excluded.updated_at
            """,
            (word_id, json.dumps(card, ensure_ascii=False), now_iso()),
        )


def save_image(word_id: int, filename: str, prompt: str) -> None:
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


async def process(word: dict, with_image: bool, semaphore: asyncio.Semaphore) -> None:
    async with semaphore:
        word_id = word["id"]
        try:
            if has_card(word_id):
                with get_conn() as conn:
                    row = conn.execute(
                        "SELECT payload FROM cards WHERE word_id = ?", (word_id,)
                    ).fetchone()
                card = json.loads(row["payload"])
                print(f"[skip card] {word['word']}")
            else:
                card = await llm.generate_word_card(word["word"], word["definition_en"])
                save_card(word_id, card)
                print(f"[card] {word['word']}")

            if with_image:
                filename = await generate_word_image(
                    word_id,
                    word["word"],
                    card.get("image_prompt") or word["word"],
                )
                save_image(word_id, filename, card.get("image_prompt", ""))
                print(f"[image] {word['word']} -> {filename}")
        except Exception as exc:  # noqa: BLE001
            print(f"[error] {word['word']}: {exc}")


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", type=int, default=1)
    parser.add_argument("--end", type=int, default=20)
    parser.add_argument("--words", type=str, default="")
    parser.add_argument("--images", action="store_true")
    parser.add_argument("--concurrency", type=int, default=3)
    args = parser.parse_args()

    init_db()
    names = [item.strip() for item in args.words.split(",") if item.strip()]
    words = load_words(args.start, args.end, names)
    print(f"准备处理 {len(words)} 个单词")

    semaphore = asyncio.Semaphore(max(1, args.concurrency))
    await asyncio.gather(*(process(word, args.images, semaphore) for word in words))
    print("完成")


if __name__ == "__main__":
    asyncio.run(main())
