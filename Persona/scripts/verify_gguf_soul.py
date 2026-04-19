#!/usr/bin/env python3
"""
verify_gguf_soul.py — Sanity-check that a GGUF has a valid embedded TacNet soul.
Exit code 0 on success, non-zero on any integrity problem.
Intended to run in CI before publishing a model to the CDN.
"""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

try:
    from gguf import GGUFReader
except ImportError:
    sys.exit("gguf-py missing. Install it: pip install gguf")


def get_str(reader: GGUFReader, key: str) -> str | None:
    field = reader.fields.get(key)
    if field is None:
        return None
    return field.parts[0].tobytes().decode("utf-8", errors="replace")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gguf", required=True, type=Path)
    ap.add_argument("--expected-soul", type=Path, help="If given, check text equality against this file")
    ap.add_argument("--expected-version", type=str, help="If given, check version equality")
    args = ap.parse_args()

    reader = GGUFReader(str(args.gguf))

    soul     = get_str(reader, "tacnet.soul")
    soul_sha = get_str(reader, "tacnet.soul.sha256")
    soul_ver = get_str(reader, "tacnet.soul.version")

    if not soul:
        print("FAIL: tacnet.soul key missing")
        return 2
    if not soul_sha:
        print("FAIL: tacnet.soul.sha256 key missing")
        return 2

    actual_sha = hashlib.sha256(soul.encode("utf-8")).hexdigest()
    if actual_sha != soul_sha:
        print(f"FAIL: embedded soul hash mismatch. Metadata={soul_sha[:12]}... Actual={actual_sha[:12]}...")
        return 3

    if args.expected_soul:
        exp_text = args.expected_soul.read_text(encoding="utf-8")
        if exp_text != soul:
            print("FAIL: embedded soul text does not match the expected soul.md on disk")
            return 4

    if args.expected_version and soul_ver != args.expected_version:
        print(f"FAIL: version mismatch. Embedded={soul_ver} Expected={args.expected_version}")
        return 5

    print("OK")
    print(f"  soul version : {soul_ver}")
    print(f"  soul sha256  : {soul_sha}")
    print(f"  soul bytes   : {len(soul.encode('utf-8'))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
