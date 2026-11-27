"""把 NGSL 词表转换成后端统一词库 JSON。"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

import openpyxl

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from app.services.memory import initial_difficulty, initial_stability  # noqa: E402

NGSL_DIR = BACKEND_DIR.parent / "NGSL"
OUT_PATH = BACKEND_DIR / "app" / "data" / "words_seed.json"


def read_stats() -> list[dict]:
    path = NGSL_DIR / "NGSL_1.2_stats.csv"
    rows: list[dict] = []
    with path.open(encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            lemma = (row.get("Lemma") or "").strip()
            if not lemma:
                continue
            rows.append(
                {
                    "lemma": lemma,
                    "rank": int(float(row["SFI Rank"])),
                    "sfi": float(row["SFI"]),
                    "freq": int(float(row["Adjusted Frequency per Million (U)"])),
                }
            )
    return rows


def read_definitions() -> dict[str, str]:
    path = NGSL_DIR / "NGSL_1.2_with_English_definitions.xlsx"
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    ws = wb.worksheets[0]
    definitions: dict[str, str] = {}
    for index, row in enumerate(ws.iter_rows(values_only=True)):
        if index == 0:
            continue
        word, definition = row[0], row[1]
        if not word:
            continue
        definitions[str(word).strip().lower()] = (definition or "").strip()
    wb.close()
    return definitions


def main() -> None:
    stats = read_stats()
    definitions = read_definitions()
    total = len(stats)

    words = []
    for item in stats:
        word = item["lemma"]
        words.append(
            {
                "id": item["rank"],
                "word": word,
                "rank": item["rank"],
                "sfi": round(item["sfi"], 3),
                "freq": item["freq"],
                "definition_en": definitions.get(word.lower(), ""),
                "h0": round(initial_stability(item["rank"], total), 4),
                "d0": round(initial_difficulty(item["rank"], total), 3),
            }
        )

    words.sort(key=lambda w: w["rank"])
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(words, ensure_ascii=False, indent=1), encoding="utf-8")

    missing = sum(1 for w in words if not w["definition_en"])
    print(f"total words: {total}")
    print(f"missing definitions: {missing}")
    print(f"written to: {OUT_PATH}")


if __name__ == "__main__":
    main()
