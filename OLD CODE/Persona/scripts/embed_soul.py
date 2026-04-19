#!/usr/bin/env python3
"""
embed_soul.py — Inject soul.md into a Gemma 4 E4B INT4 GGUF as custom metadata.

Run once per release, AFTER merging the Ranger-Handbook LoRA and re-quantizing
the model to GGUF, and BEFORE uploading to the TacNet model CDN.

Usage:
    python embed_soul.py \
        --src    model.int4.gguf \
        --soul   ../soul.md \
        --dst    model.int4.soul-v1.0.0.gguf \
        --version 1.0.0

Requires: gguf-py (ships with llama.cpp)
    pip install gguf
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    from gguf import GGUFReader, GGUFWriter
except ImportError:
    sys.exit("gguf-py missing. Install it: pip install gguf")

TACNET_KEYS = {
    "soul":         "tacnet.soul",
    "soul_sha256":  "tacnet.soul.sha256",
    "soul_version": "tacnet.soul.version",
    "build_time":   "tacnet.model.build_time",
    "base":         "tacnet.model.base",
    "finetune":     "tacnet.model.finetune",
}


def sha256_text(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def embed(
    src: Path,
    soul: Path,
    dst: Path,
    version: str,
    base_model: str,
    finetune_tag: str,
) -> dict:
    soul_text = soul.read_text(encoding="utf-8")
    soul_hash = sha256_text(soul_text)

    reader = GGUFReader(str(src))
    arch = reader.fields["general.architecture"].parts[0].tobytes().decode()
    writer = GGUFWriter(str(dst), arch)

    # Copy existing metadata fields.
    for name, field in reader.fields.items():
        # Skip the ones we are overriding (in case a previous soul is present).
        if name in TACNET_KEYS.values():
            continue
        writer.add_key_value(name, field.value, field.types)

    # Inject TacNet persona metadata.
    writer.add_string(TACNET_KEYS["soul"], soul_text)
    writer.add_string(TACNET_KEYS["soul_sha256"], soul_hash)
    writer.add_string(TACNET_KEYS["soul_version"], version)
    writer.add_string(TACNET_KEYS["build_time"], datetime.now(timezone.utc).isoformat(timespec="seconds"))
    writer.add_string(TACNET_KEYS["base"], base_model)
    writer.add_string(TACNET_KEYS["finetune"], finetune_tag)

    writer.write_header_to_file()
    writer.write_kv_data_to_file()

    # Copy tensors unchanged.
    for tensor in reader.tensors:
        writer.add_tensor(
            tensor.name,
            tensor.data,
            raw_shape=tensor.shape,
            raw_dtype=tensor.tensor_type,
        )
    writer.write_tensors_to_file()
    writer.close()

    summary = {
        "src":                str(src),
        "dst":                str(dst),
        "soul_version":       version,
        "soul_sha256":        soul_hash,
        "dst_sha256":         sha256_file(dst),
        "base_model":         base_model,
        "finetune":           finetune_tag,
        "build_time":         datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    print(json.dumps(summary, indent=2))
    return summary


def build_manifest(summary: dict, model_id: str, version: str, url: str, out: Path) -> None:
    manifest = {
        "model_id": model_id,
        "version":  version,
        "url":      url,
        "size":     Path(summary["dst"]).stat().st_size,
        "sha256":   summary["dst_sha256"],
        "soul": {
            "version":     summary["soul_version"],
            "sha256":      summary["soul_sha256"],
            "embedded_in": TACNET_KEYS["soul"],
        },
        "base_model": summary["base_model"],
        "finetune":   summary["finetune"],
        "build_time": summary["build_time"],
    }
    out.write_text(json.dumps(manifest, indent=2))
    print(f"Manifest written → {out}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--src",          required=True, type=Path)
    ap.add_argument("--soul",         required=True, type=Path)
    ap.add_argument("--dst",          required=True, type=Path)
    ap.add_argument("--version",      required=True, type=str, help="soul.md semver, e.g. 1.0.0")
    ap.add_argument("--base-model",   default="google/gemma-2-4b-it")
    ap.add_argument("--finetune-tag", default="ranger-handbook-tc-3-21.76")
    ap.add_argument("--manifest",     type=Path, help="Optional manifest.json output path")
    ap.add_argument("--model-id",     default="tacnet-gemma4-e4b-int4")
    ap.add_argument("--model-version",default=None, help="Manifest version; defaults to soul version")
    ap.add_argument("--cdn-url",      default="https://cdn.tacnet.local/models/<filename>")
    args = ap.parse_args()

    if not args.src.exists():
        sys.exit(f"Source GGUF not found: {args.src}")
    if not args.soul.exists():
        sys.exit(f"soul.md not found: {args.soul}")
    args.dst.parent.mkdir(parents=True, exist_ok=True)

    summary = embed(
        args.src,
        args.soul,
        args.dst,
        args.version,
        args.base_model,
        args.finetune_tag,
    )

    if args.manifest:
        build_manifest(
            summary,
            model_id=args.model_id,
            version=args.model_version or args.version,
            url=args.cdn_url.replace("<filename>", args.dst.name),
            out=args.manifest,
        )
