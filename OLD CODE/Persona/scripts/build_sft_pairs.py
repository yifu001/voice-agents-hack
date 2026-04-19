#!/usr/bin/env python3
"""
build_sft_pairs.py — Expand a seed instruction file into an SFT dataset where
every pair has soul.md prepended as the system turn.

Input:  seed.jsonl   with rows {"input": "<raw>", "output": "<terse doctrine>"}
Output: sft.jsonl    with rows in Gemma chat-template shape, system = soul.md

This is the Layer-1 step from SOUL_EMBEDDING.md — weight-level priming.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--soul",  required=True, type=Path)
    ap.add_argument("--seed",  required=True, type=Path)
    ap.add_argument("--out",   required=True, type=Path)
    args = ap.parse_args()

    soul = args.soul.read_text(encoding="utf-8")
    args.out.parent.mkdir(parents=True, exist_ok=True)

    written = 0
    with args.seed.open("r", encoding="utf-8") as src, args.out.open("w", encoding="utf-8") as dst:
        for line_no, line in enumerate(src, 1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as e:
                print(f"skip line {line_no}: {e}", file=sys.stderr)
                continue
            if "input" not in row or "output" not in row:
                print(f"skip line {line_no}: missing input/output", file=sys.stderr)
                continue
            pair = {
                "messages": [
                    {"role": "system",    "content": soul},
                    {"role": "user",      "content": row["input"]},
                    {"role": "assistant", "content": row["output"]},
                ]
            }
            dst.write(json.dumps(pair, ensure_ascii=False) + "\n")
            written += 1

    print(f"Wrote {written} soul-primed SFT pairs → {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
