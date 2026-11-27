from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone

from .config import DB_PATH, SEED_PATH

SCHEMA = """
CREATE TABLE IF NOT EXISTS words (
    id INTEGER PRIMARY KEY,
    word TEXT NOT NULL UNIQUE,
    rank INTEGER NOT NULL,
    sfi REAL,
    freq INTEGER,
    definition_en TEXT,
    h0 REAL NOT NULL,
    d0 REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS cards (
    word_id INTEGER PRIMARY KEY,
    payload TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS images (
    word_id INTEGER PRIMARY KEY,
    filename TEXT NOT NULL,
    prompt TEXT,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS graphs (
    center TEXT PRIMARY KEY,
    payload TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS lookups (
    word TEXT PRIMARY KEY,
    payload TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS text_images (
    word TEXT PRIMARY KEY,
    filename TEXT NOT NULL,
    prompt TEXT,
    updated_at TEXT NOT NULL
);
"""


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@contextmanager
def get_conn():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    with get_conn() as conn:
        conn.executescript(SCHEMA)
        count = conn.execute("SELECT COUNT(*) AS c FROM words").fetchone()["c"]
        if count > 0:
            return

        if not SEED_PATH.exists():
            return
        words = json.loads(SEED_PATH.read_text(encoding="utf-8"))
        conn.executemany(
            """
            INSERT INTO words (id, word, rank, sfi, freq, definition_en, h0, d0)
            VALUES (:id, :word, :rank, :sfi, :freq, :definition_en, :h0, :d0)
            """,
            words,
        )
        print(f"seeded {len(words)} words")


def row_to_word(row: sqlite3.Row) -> dict:
    return {key: row[key] for key in row.keys()}
