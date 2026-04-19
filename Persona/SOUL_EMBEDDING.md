# Embedding `soul.md` Directly Into the SLM Artifact

*How we make the TacNet personality inseparable from the Gemma 4 E4B weights shipped to the user's phone.*

---

## Goal

When a user downloads the TacNet app and the app fetches the model, the downloaded model **is the personality**. The user cannot strip `soul.md`, cannot swap it, cannot load the weights without the persona. There is no "neutral Gemma" path reachable in production.

The fine-tune teaches the model *how* to talk like a Ranger. The embedded `soul.md` tells it *which* Ranger to be, on every turn, forever. Both need to ship as one artifact.

## Architecture — Four Layers of Defense in Depth

```
                ┌────────────────────────────────────────────┐
                │  LAYER 1  Weight-level priming             │
                │  soul.md prepended to every SFT pair       │
                │  during Ranger-Handbook LoRA training      │
                └────────────────┬───────────────────────────┘
                                 │ merge + quantize
                                 ▼
                ┌────────────────────────────────────────────┐
                │  LAYER 2  GGUF metadata embedding          │
                │  soul.md written into model.gguf header    │
                │  as custom metadata key  "tacnet.soul"     │
                └────────────────┬───────────────────────────┘
                                 │ packaging
                                 ▼
                ┌────────────────────────────────────────────┐
                │  LAYER 3  Signed manifest                  │
                │  SHA-256(soul.md) stored in manifest.json  │
                │  verified on download + on every app boot  │
                └────────────────┬───────────────────────────┘
                                 │ download
                                 ▼
                ┌────────────────────────────────────────────┐
                │  LAYER 4  Runtime inject from GGUF, not    │
                │  from bundle. Cactus reads tacnet.soul     │
                │  and prepends it to every inference turn.  │
                └────────────────────────────────────────────┘
```

The insight is **Layer 2**. GGUF (the format llama.cpp / Cactus use) supports arbitrary string metadata keys. If we write `soul.md` into the GGUF header itself, the persona is physically part of the weights file. No companion file, no side-channel, no way to decouple.

---

## Layer 1 — Weight-Level Priming

During the Ranger Handbook fine-tune (see `../RangerHandbook/FINE_TUNING_PLAN.md`), the SFT phase must prepend `soul.md` to every training pair so gradients learn the identity alongside the vocabulary.

### Training-time pair shape

```json
{
  "messages": [
    {"role": "system",    "content": "<contents of soul.md>"},
    {"role": "user",      "content": "<raw operator utterance>"},
    {"role": "assistant", "content": "<terse doctrine-compliant output>"}
  ]
}
```

Every single pair in `sft_pairs.jsonl` contains the full `soul.md` in the system slot. Yes, it's repetitive. That repetition is exactly what burns the identity into the weights.

Loss is computed on the assistant tokens only — the system and user tokens are masked. This lets Gemma treat `soul.md` as a fixed conditioning context, not as output it should imitate.

### Why not just rely on runtime injection?

A weights-level prime is cheap insurance. If a future JIT prompt stripper, fine-tune-on-top, or accidental system-prompt omission happens in the wild, the model still defaults to terse Ranger register because its weights have internalized the identity. Belt and suspenders.

---

## Layer 2 — GGUF Metadata Embedding (the load-bearing trick)

After the LoRA adapter is merged and the model is re-quantized to INT4 for Cactus, we rewrite the GGUF file to inject `soul.md` as a custom metadata key before shipping.

### GGUF custom keys

GGUF files begin with a key-value header. Keys have a namespace pattern (e.g., `general.name`, `llama.context_length`, `tokenizer.ggml.model`). We add:

```
tacnet.soul                = "<full soul.md text>"
tacnet.soul.sha256         = "<hex sha256 of soul.md>"
tacnet.soul.version        = "1.0.0"
tacnet.model.build_time    = "2026-04-18T20:00:00Z"
tacnet.model.base          = "google/gemma-2-4b-it"
tacnet.model.finetune      = "ranger-handbook-tc-3-21.76"
```

The `tacnet.soul` key holds the entire `soul.md` contents (~12 KB — trivial compared to a 4 GB quantized model).

### Injection script

`scripts/embed_soul.py` (provided below) uses the `gguf-py` library (ships with llama.cpp) to read an existing `model.gguf`, add the custom metadata, and write `model.tacnet.gguf`.

```python
# Persona/scripts/embed_soul.py
# Run once after merge+quantize, before packaging for distribution.

import argparse
import hashlib
from pathlib import Path
from gguf import GGUFReader, GGUFWriter, GGMLQuantizationType

TACNET_SOUL_KEY          = "tacnet.soul"
TACNET_SOUL_SHA_KEY      = "tacnet.soul.sha256"
TACNET_SOUL_VERSION_KEY  = "tacnet.soul.version"

def embed(src_gguf: Path, soul_md: Path, dst_gguf: Path, soul_version: str) -> None:
    soul_text = soul_md.read_text(encoding="utf-8")
    soul_sha  = hashlib.sha256(soul_text.encode("utf-8")).hexdigest()

    reader = GGUFReader(src_gguf, "r")
    writer = GGUFWriter(dst_gguf, reader.fields["general.architecture"].parts[0].tobytes().decode())

    # Copy all existing metadata and tensors unchanged.
    for field_name, field in reader.fields.items():
        writer.add_key_value(field_name, field.value, field.types)
    # Inject our custom keys.
    writer.add_string(TACNET_SOUL_KEY, soul_text)
    writer.add_string(TACNET_SOUL_SHA_KEY, soul_sha)
    writer.add_string(TACNET_SOUL_VERSION_KEY, soul_version)

    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    for tensor in reader.tensors:
        writer.add_tensor(tensor.name, tensor.data, raw_shape=tensor.shape, raw_dtype=tensor.tensor_type)
    writer.write_tensors_to_file()
    writer.close()

    print(f"Embedded soul.md v{soul_version} (sha256={soul_sha[:12]}...) into {dst_gguf}")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--src",     required=True, type=Path, help="Input GGUF (merged + quantized)")
    p.add_argument("--soul",    required=True, type=Path, help="Path to soul.md")
    p.add_argument("--dst",     required=True, type=Path, help="Output GGUF path")
    p.add_argument("--version", required=True, type=str,  help="soul.md semver, e.g. 1.0.0")
    args = p.parse_args()
    embed(args.src, args.soul, args.dst, args.version)
```

The GGUF with the embedded soul is what gets uploaded to the model CDN. Nothing else in the distribution path needs to change yet.

---

## Layer 3 — Signed Manifest

The existing `ModelDownloadService` uses a manifest. Extend it:

```json
{
  "model_id": "tacnet-gemma4-e4b-int4",
  "version":  "2026.04.18-r1",
  "url":      "https://cdn.tacnet.local/models/gemma4-e4b-int4-soul-v1.gguf",
  "size":     4123456789,
  "sha256":   "<hex sha256 of the full .gguf>",
  "soul": {
    "version":     "1.0.0",
    "sha256":      "<hex sha256 of soul.md text>",
    "embedded_in": "tacnet.soul"
  }
}
```

`AppBootstrapViewModel` verifies:
1. After download: hash the full `.gguf` and compare to `manifest.sha256`.
2. On model load: Cactus reads `tacnet.soul` from the GGUF, hashes it, and compares to `manifest.soul.sha256`. Mismatch → reject load, force redownload.

This catches both bit-rot and any man-in-the-middle who stripped or swapped the persona.

---

## Layer 4 — Runtime Inject from GGUF

`TacNet/Services/Cactus.swift` today loads the model and exposes a `complete(prompt:)` API. We extend it to expose the embedded soul and require that every inference path go through a helper that prepends it.

### Cactus bridge change (Swift)

```swift
public struct LoadedModel {
    let handle: OpaquePointer         // Cactus model handle
    let soul:   String                // extracted from tacnet.soul metadata key
    let soulVersion: String
    let soulSHA: String
}

public final class CactusBridge {
    public func load(gguf url: URL, expectedSoulSHA: String) throws -> LoadedModel {
        let handle = try cactus_load_model(url.path)
        guard let soul = cactus_get_metadata_string(handle, "tacnet.soul") else {
            cactus_free_model(handle)
            throw ModelError.missingSoul
        }
        guard let soulSHA = cactus_get_metadata_string(handle, "tacnet.soul.sha256"),
              soulSHA == expectedSoulSHA else {
            cactus_free_model(handle)
            throw ModelError.soulIntegrity
        }
        let soulVersion = cactus_get_metadata_string(handle, "tacnet.soul.version") ?? "unknown"
        return LoadedModel(handle: handle, soul: soul, soulVersion: soulVersion, soulSHA: soulSHA)
    }
}
```

The bundle's copy of `soul.md` is never read by the inference path. Only the GGUF's embedded copy is.

### Inference wrapper

```swift
public final class TacNetInference {
    private let model: LoadedModel
    private let enforcer = BrevityEnforcer(leaderCap: 18, peerCap: 12)

    public init(model: LoadedModel) { self.model = model }

    public func respond(to userTurn: String, role: EarpieceRole) async throws -> String {
        let prompt = """
        <start_of_turn>system
        \(model.soul)
        <end_of_turn>
        <start_of_turn>user
        \(userTurn)
        <end_of_turn>
        <start_of_turn>model
        """
        let raw = try await CactusBridge.shared.complete(
            model: model.handle,
            prompt: prompt,
            maxTokens: 64,
            temperature: 0.3
        )
        return enforcer.cap(raw, for: role)
    }
}

public enum EarpieceRole { case leader, peer }

public struct BrevityEnforcer {
    let leaderCap: Int
    let peerCap: Int
    func cap(_ text: String, for role: EarpieceRole) -> String {
        let words = text.split(separator: " ")
        let limit = role == .leader ? leaderCap : peerCap
        return words.prefix(limit).joined(separator: " ")
    }
}
```

Because `model.soul` comes from the GGUF, not the bundle, the persona is **physically tied** to the weights that are in memory.

---

## Layer-by-Layer Tamper Analysis

| Attack | Defense |
|---|---|
| User jailbreaks phone, replaces `soul.md` in app bundle | No effect — inference reads from GGUF, not bundle |
| User replaces entire `.gguf` with a neutral Gemma build | Download manifest SHA mismatch → app refuses to load |
| User modifies one byte of `tacnet.soul` inside the GGUF | `tacnet.soul.sha256` mismatch → app refuses to load |
| User also modifies `tacnet.soul.sha256` to match | Manifest's `manifest.soul.sha256` still mismatches → app refuses to load |
| User modifies manifest too | Manifest is signed (see §"Manifest signing" below) → signature check fails |
| User runs an alternate app with the same `.gguf` | Not our problem — our app behaves correctly |
| Prompt-injection via user utterance | Runtime soul prompt is still active on every turn; Layer 1 also makes weights resistant |

### Manifest signing (one more hardening knob)

The manifest itself should be signed with an Ed25519 key held by the TacNet release team. The public key is compiled into the app binary. `AppBootstrapViewModel` verifies the signature before trusting any field of the manifest. This is the same pattern OTA-updater frameworks like Sparkle use.

---

## Versioning & Migration

- `soul.md` has a semver in its own header and in the GGUF metadata.
- A new persona version = a new model version = a new manifest entry. Treat persona changes as model changes from the user's perspective.
- When the app sees a manifest pointing at a newer `soul.version`, it triggers a redownload via the existing `ModelDownloadService`.
- Rollback is just redownloading the previous manifest.

---

## Build & Release Pipeline

```
1. Fine-tune Gemma 4 E4B on sft_pairs.jsonl  (where every pair has soul.md in system slot)
2. Merge LoRA into base weights
3. Quantize to INT4 GGUF
4. Run scripts/embed_soul.py:
     input:  model.int4.gguf  +  soul.md  +  --version 1.0.0
     output: model.int4.soul-v1.0.0.gguf
5. Compute SHA-256 of output file and of soul.md
6. Build manifest.json with both hashes
7. Sign manifest with release Ed25519 key
8. Upload {model.gguf, manifest.json, manifest.json.sig} to CDN
9. App build bundles:
     - public-key.pem  (for manifest verification)
     - CactusBridge    (for reading tacnet.soul from GGUF)
     - NO copy of soul.md is shipped in the bundle — only the GGUF contains it
```

---

## Migration from the Current Setup

Today:
- `Persona/soul.md` — exists as a file.
- Cactus inference path does not know about it.
- Model download pulls a stock Gemma weights file.

Migration steps:
1. **Training run.** Run the fine-tune with soul-prepended pairs. Produce a new LoRA.
2. **Packaging.** Merge + quantize + run `embed_soul.py`. Get the soul-embedded GGUF.
3. **Cactus bridge patch.** Add `cactus_get_metadata_string` wrapper (or wire to the existing llama.cpp `gguf_get_val_str`).
4. **ModelDownloadService patch.** Extend manifest schema, add hash verification of embedded soul.
5. **AppBootstrapViewModel patch.** Gate model-ready state on soul integrity check.
6. **Remove `soul.md` from the app bundle.** It lives only in the GGUF now.
7. **Red-team.** Write XCTest cases that:
    - Attempt to load a GGUF with no `tacnet.soul` key → expect `ModelError.missingSoul`.
    - Attempt to load a GGUF with tampered soul text → expect `ModelError.soulIntegrity`.
    - Send adversarial user turns designed to strip the persona → assert refusal per `soul.md §11`.

---

## Files to Create / Modify

```
Persona/
├── SOUL_EMBEDDING.md            ← this file
├── soul.md                      ← already exists
├── README.md                    ← already exists (update to reference embedding)
└── scripts/
    ├── embed_soul.py            ← NEW — GGUF metadata injector
    ├── build_sft_pairs.py       ← NEW — prepends soul.md to every SFT pair
    └── verify_gguf_soul.py      ← NEW — CI sanity-check

TacNet/Services/
├── Cactus.swift                 ← extend: cactus_get_metadata_string wrapper
├── ModelDownloadService.swift   ← extend: manifest schema + hash verification
└── TacNetInference.swift        ← NEW — wraps Cactus w/ soul prepend + brevity cap

TacNetTests/
└── SoulEmbeddingTests.swift     ← NEW — tamper/integrity/refusal tests
```

---

## Why This Matters for the Product

TacNet's pitch rests on the SLM behaving like a disciplined NCO, not a generic chatbot. If any single user can strip the persona by overwriting a file in `/Documents/`, the product value evaporates in that user's hands. By making the persona an intrinsic property of the model artifact — baked into weights **and** embedded in the GGUF header **and** verified against a signed manifest — the personality becomes as tamper-resistant as the model weights themselves.

From the user's perspective: **they don't download TacNet and a model. They download a TacNet operator AI.** The two concepts collapse.
