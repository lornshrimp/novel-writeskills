#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Lightweight POV drift validator.

Design goals (SOP-aligned):
  - Validate BODY only (content before afterword marker).
  - Ignore dialogue inside quotes so 'I/you/我/你' in spoken lines won't fail.
  - Output JSON only; do not print chapter正文.

This script is used by scripts/validate_webnovel_pov.ps1.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


MARKERS = [
    "## 作者有话说",
    "## Author's Note",
]


def read_text_best_effort(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        # Windows locale fallback
        return p.read_text(encoding="gb18030", errors="replace")


def split_body(text: str) -> str:
    idx = -1
    for m in MARKERS:
        i = text.find(m)
        if i >= 0 and (idx < 0 or i < idx):
            idx = i
    return text if idx < 0 else text[:idx]


def strip_quoted(text: str) -> str:
    """Remove text inside common quote pairs (keeps outside narrative).

    Supports:
      - Chinese curly quotes: “ ... ”
      - ASCII double quotes: " ... "

    This is a heuristic; it is intentionally simple and conservative.
    """

    # Remove curly-quoted segments
    text = re.sub(r"“[^”]*”", " ", text, flags=re.DOTALL)
    # Remove ASCII double-quoted segments
    text = re.sub(r'"[^\"]*"', " ", text, flags=re.DOTALL)
    return text


def count_en_pronouns(narrative: str) -> dict:
    # Word-ish tokens; keep apostrophes for contractions.
    tokens = re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)?", narrative)
    tokens_l = [t.lower() for t in tokens]

    first_set = {
        "i",
        "me",
        "my",
        "mine",
        "myself",
        "i'm",
        "i've",
        "i'd",
        "i'll",
    }
    second_set = {
        "you",
        "your",
        "yours",
        "yourself",
        "yourselves",
    }

    first = sum(1 for t in tokens_l if t in first_set)
    second = sum(1 for t in tokens_l if t in second_set)

    # Third-person count is informative only; not used as a hard gate here.
    third_set = {
        "he",
        "him",
        "his",
        "himself",
        "she",
        "her",
        "hers",
        "herself",
        "they",
        "them",
        "their",
        "theirs",
        "themselves",
    }
    third = sum(1 for t in tokens_l if t in third_set)

    return {"first": first, "second": second, "third": third}


def count_zh_pronouns(narrative: str) -> dict:
    # Simple character-based counts.
    first = narrative.count("我")
    second = narrative.count("你")
    third = narrative.count("他") + narrative.count("她") + narrative.count("他们") + narrative.count("她们")
    return {"first": first, "second": second, "third": third}


def validate(expected: str, lang: str, path: Path) -> dict:
    reasons: list[str] = []

    if not path.exists():
        return {
            "path": str(path),
            "expected": expected,
            "lang": lang,
            "pass": False,
            "counts": {"first": 0, "second": 0, "third": 0},
            "reasons": ["file_not_found"],
        }

    raw = read_text_best_effort(path)
    body = split_body(raw)
    narrative = strip_quoted(body)

    if lang == "en":
        counts = count_en_pronouns(narrative)
    elif lang == "zh":
        counts = count_zh_pronouns(narrative)
    else:
        # auto: decide by presence of CJK
        if re.search(r"[\u4e00-\u9fff]", narrative):
            counts = count_zh_pronouns(narrative)
            lang = "zh"
        else:
            counts = count_en_pronouns(narrative)
            lang = "en"

    ok = True
    if expected == "third":
        if counts["first"] > 0:
            ok = False
            reasons.append("found_first_person_outside_dialogue")
        if counts["second"] > 0:
            ok = False
            reasons.append("found_second_person_outside_dialogue")
    elif expected == "first":
        # Minimal gate: must have at least some first-person outside dialogue.
        if counts["first"] == 0:
            ok = False
            reasons.append("no_first_person_outside_dialogue")
    elif expected == "second":
        if counts["second"] == 0:
            ok = False
            reasons.append("no_second_person_outside_dialogue")

    return {
        "path": str(path),
        "expected": expected,
        "lang": lang,
        "pass": ok,
        "counts": counts,
        "reasons": reasons,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--expected", choices=["first", "second", "third"], required=True)
    ap.add_argument("--lang", choices=["zh", "en", "auto"], default="auto")
    ap.add_argument("--path", required=True)
    args = ap.parse_args()

    p = Path(args.path)
    result = validate(args.expected, args.lang, p)
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result.get("pass") else 2


if __name__ == "__main__":
    raise SystemExit(main())
