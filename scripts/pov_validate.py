#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Lightweight POV drift validator.

设计目标（符合SOP）：
    - 仅验证正文（作者有话说标记前的内容）。
    - 忽略引号内的对话，使得'I/you/我/你'在对白中不会失败。
    - 仅输出JSON，不打印章节正文。

本脚本由 scripts/validate_webnovel_pov.ps1 调用。
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
        # Windows系统编码回退
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

        删除常见引号对内的文本（保留叙述外的内容）。

        支持：
            - 中文弯引号："....."
            - ASCII双引号："....."

        这是一个启发式方法；故意保持简单和保守。
    """

        # 删除弯引号内的片段
    text = re.sub(r"“[^”]*”", " ", text, flags=re.DOTALL)
        # 删除ASCII双引号内的片段
    text = re.sub(r'"[^\"]*"', " ", text, flags=re.DOTALL)
    return text


def count_en_pronouns(narrative: str) -> dict:
    # Word-ish tokens; keep apostrophes for contractions.
        # 类单词的符号；保留缩略式的撇号。
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
        # 第三人称计数仅供参考；不在此用作硬门禁。
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
        # 简单的基于字符的计数。
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
            # 自动判断：根据CJK字符的存在决定
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
            # 最小门禁：必须至少有一些第一人称（对白外）。
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
