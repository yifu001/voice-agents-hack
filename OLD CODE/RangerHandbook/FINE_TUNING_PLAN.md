# Fine-Tuning Gemma 4 E4B on the Ranger Handbook — Communication-Style Plan

**Base model:** `google/gemma-2-4b-it` (or the Gemma 4 `e4b` variant shipped with the TacNet Cactus XCFramework — INT4-quantized at inference time).
**Training corpus:** `RANGER_HANDBOOK.md` (~600 KB, ~8k lines, 370 pages of US Army TC 3-21.76 rendered as structured Markdown).
**Target behavior:** When TacNet's on-device SLM receives raw operator voice-to-text, it should route / compact / summarize it in the communication style of a Tier-1 Ranger — terse, doctrine-compliant, formatted per SALUTE / SITREP / ACE / LACE / CASEVAC / SPOTREP conventions, using correct brevity codes and acronyms.

This document is the end-to-end plan: data prep → training → evaluation → deployment.

---

## 1. Why the Ranger Handbook Works as a Style Corpus

The handbook is exactly the right shape for a style fine-tune:

1. **Doctrine-bounded vocabulary.** Every acronym, every report format, every command phrase used on a real Ranger radio net is defined here (OPORD, FRAGORD, WARNORD, SALUTE, SITREP, ACE, LACE, CASEVAC, MEDEVAC 9-line, METT-TC, OCOKA/OAKOC, ROE, PACE, SBF, ORP, LZ/PZ, EEI, CCIR, PIR, FFIR, SP, RP, TRP, PL, LD, IOC, etc.).
2. **Canonical report formats.** The handbook contains literal templates (5-paragraph OPORD, MEDEVAC 9-line, SALUTE report, etc.) that are the exact "output schemas" we want the SLM to emit.
3. **Terse register.** Ranger prose is imperative, declarative, compressed. This is the tone we want the leader-earpiece TTS line in the TacNet demo to carry.
4. **Real-world operator cadence.** Chapters on patrolling, ambush, raid, urban ops, waterborne ops provide the situational scaffolding the SLM can map user utterances onto.

The goal is NOT to make the SLM a doctrine encyclopedia. It is to make it **speak like a Ranger squad leader does on the net** when it compacts an operator's raw utterance into a summary for the commander.

---

## 2. Data Preparation Pipeline

The raw handbook MD is long-form text. Two complementary training signals are needed:

### 2.1 Continued-Pretraining Signal (Raw MD)

Train a single-epoch (or 2) causal-LM loss pass over the raw MD chunked at ~1k tokens with 128-token overlap. This adapts the model's distribution toward handbook vocabulary and phrasing.

- **Split the MD on chapter/section boundaries** (`#` and `##` markers in the stitched file).
- Pack contiguous chunks to the context window (e.g., 4k or 8k for Gemma 4 E4B).
- Mask page-header artifacts if they re-appear (`TC 3-21.76`, `26 April 2017`).

### 2.2 Instruction-Tuning Signal (Curated Pairs)

This is where the style-transfer behavior actually gets locked in. Generate ~5k–20k instruction pairs with the following schema patterns — either hand-authored, teacher-model-generated (e.g., Claude/GPT-4 distillation), or both.

Pair categories to build:

| Category | Input (user / operator raw) | Output (doctrine-compliant) |
|---|---|---|
| SITREP compaction | "yeah we're in the foyer, saw one guy, dropped him, rest of this room is clear" | `"OP1 SITREP: foyer clear, 1 EKIA, no further contact."` |
| SALUTE report | "uh there's like four guys, AKs, maybe two hundred meters northwest, they're walking toward the tree line" | `"SALUTE: Size 4, Activity moving NW toward tree line, Location 200m NW, Unit/Uniform civilian w/ AKs, Time current, Equipment small arms."` |
| LACE summary | "I got about half a mag left, Smitty's hit in the leg, we're out of water, comms are fine" | `"LACE: L — 1 WIA, leg. A — 50% basic load remaining. C — Green. E — water depleted."` |
| 9-line MEDEVAC | "we need pickup for one urgent at the LZ near the generator shed" | Properly formatted 9-line with all blanks filled where derivable, `UNKN` for missing. |
| OPORD → FRAGORD | "change of plan — Alpha goes upstairs instead of holding the foyer" | Paragraph-3-flavored FRAGORD text. |
| Brevity compression | "squad leader this is sniper I'm seeing heat signatures in the northwest room upstairs two of them possibly with weapons hard to tell" | `"OVER → SL: 2 heat sigs, 2nd-floor NW, armed unk."` |
| Query resolution | Operator asks a procedural question | Doctrine-grounded short answer pulled from the relevant handbook chapter. |

### 2.3 Synthetic TacNet Scenario Augmentation

Use the TacNet storyboard (`../DemoVideoStoryboard/`) as a seed. For each of the 10 shots, generate 20–50 plausible raw-operator utterances and their doctrine-compliant compacted form. That directly couples the training data to the product's deployment context.

### 2.4 Data File Layout

```
RangerHandbook/
├── RANGER_HANDBOOK.md              # Raw continued-pretraining corpus
├── training/
│   ├── pretrain_chunks.jsonl       # {"text": "..."} per ~1k-token chunk
│   ├── sft_pairs.jsonl             # {"instruction": "...", "input": "...", "output": "..."}
│   └── eval_prompts.jsonl          # Held-out TacNet scenarios for eval
```

JSONL format mirrors what Unsloth, Hugging Face TRL, and MLX-LM all consume.

---

## 3. Fine-Tuning Approach

### 3.1 Strategy: Two-Stage LoRA on Gemma 4 E4B

**Stage 1 — Domain adaptation (continued pretraining):**
- LoRA rank 16, alpha 32.
- Target modules: `q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj`.
- Learning rate 2e-4, cosine schedule, 1 epoch over `pretrain_chunks.jsonl`.
- Context length 4096 (bump to 8192 if memory allows).
- Loss: causal LM next-token.

**Stage 2 — Style instruction-tune (SFT on pairs):**
- Merge Stage 1 LoRA or keep as base adapter and stack a second LoRA.
- LoRA rank 32, alpha 64 (higher because this is where behavior gets locked in).
- Same target modules.
- Learning rate 1e-4, cosine schedule, 3 epochs over `sft_pairs.jsonl`.
- Use Gemma's ChatML / `<start_of_turn>user ... <end_of_turn>` template.
- Mask prompt tokens in the loss; train only on response tokens.

### 3.2 Tooling Options (all compatible with the project's Apple-Silicon macOS env)

**Option A — Unsloth (fastest, CUDA or Colab):**
```python
from unsloth import FastLanguageModel
import torch

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/gemma-2-4b-it-bnb-4bit",
    max_seq_length=4096,
    dtype=None,
    load_in_4bit=True,
)

model = FastLanguageModel.get_peft_model(
    model,
    r=32,
    target_modules=["q_proj","k_proj","v_proj","o_proj",
                    "gate_proj","up_proj","down_proj"],
    lora_alpha=64,
    lora_dropout=0.0,
    bias="none",
    use_gradient_checkpointing="unsloth",
    random_state=3407,
    use_rslora=False,
)

# ... TRL SFTTrainer with sft_pairs.jsonl ...
```

**Option B — MLX-LM (native Apple Silicon, matches this repo's hardware):**
```bash
pip install mlx-lm
python -m mlx_lm.lora \
    --model google/gemma-2-4b-it \
    --train \
    --data RangerHandbook/training \
    --iters 3000 \
    --lora-layers 16 \
    --batch-size 2 \
    --learning-rate 1e-4 \
    --save-every 500 \
    --adapter-path RangerHandbook/adapters/ranger-style
```

**Option C — Hugging Face TRL + PEFT (most flexible):**
Standard `SFTTrainer` with `LoraConfig` and a `DataCollatorForCompletionOnlyLM` to mask the instruction span from the loss.

### 3.3 Compute Budget (rough)

- M3 Max / 64 GB with MLX: ~6–10 hours for Stage 1 + Stage 2.
- A100 40 GB with Unsloth: ~1–2 hours.
- Colab T4 with Unsloth 4-bit: ~4–6 hours.

---

## 4. Evaluation

Build `eval_prompts.jsonl` from the TacNet storyboard + handbook-derived adversarial prompts. Score with:

### 4.1 Automatic Metrics

- **Format adherence.** Regex + schema check: does the output contain the expected sections (SALUTE/SITREP/LACE/9-line blocks)?
- **Acronym coverage.** Fraction of doctrine-required acronyms present when applicable.
- **Length budget.** Leader-earpiece outputs must be < 18 words. Enforce and measure.
- **ROUGE-L vs reference** for paraphrase-stability.

### 4.2 Human / LLM-Judge Qualitative

Rubric (1–5 each):
1. Tone matches a Ranger NCO on the net.
2. Brevity — no wasted words.
3. Doctrine compliance — correct acronyms, correct report skeleton.
4. Fidelity — no information lost from the raw input.
5. No hallucinated facts.

### 4.3 Regression — Base vs Tuned

For each of ~50 held-out TacNet prompts, diff base-Gemma output vs tuned-Gemma output. Store A/B side-by-side for human review.

---

## 5. Deployment Back Into TacNet

1. **Merge the Stage-2 LoRA adapter** into the base Gemma 4 E4B weights (`peft.merge_and_unload()`).
2. **Re-quantize to INT4** using Cactus's existing quantization pipeline so the output matches the binary format the `Frameworks/cactus-ios.xcframework` expects.
3. **Ship the new weights** via the existing `ModelDownloadService` bootstrap (see `TacNet/Services/Cactus.swift` and `AppBootstrapViewModel` in `ContentView.swift`) — update the manifest, bump the version, keep the on-device checksum validation intact.
4. **Guardrails.** Add a deterministic post-processor in Swift that enforces the brevity budget (hard-truncate leader-earpiece outputs at 18 words) and re-formats any near-miss SALUTE/SITREP output into the canonical shape before TTS. Style fine-tune + post-processor is strictly more robust than either alone.

---

## 6. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Model overfits to handbook phrasing and sounds rigid. | Cap Stage-1 at 1 epoch, mix 10% general-chat data in Stage 2. |
| Hallucinated doctrine citations. | Fine-tune for compaction, not recall; RAG from the same MD at inference for any "what does X mean" query. |
| Brevity budget violated. | Hard Swift-side post-processor truncation + regenerate on overflow. |
| Sensitive doctrine content leaked in prompts. | The handbook is public. Still scrub any live-mission metadata before training. |
| INT4 quant degrades fine-tune gains. | Evaluate both FP16 and INT4 on the eval set; if delta too large, use AWQ or GPTQ instead of naive int4. |

---

## 7. Next Concrete Steps

1. `pip install unsloth trl datasets peft bitsandbytes` (or MLX-LM on the macOS dev box).
2. Write `scripts/build_pretrain_chunks.py` — sliding-window chunker over `RANGER_HANDBOOK.md` → `training/pretrain_chunks.jsonl`.
3. Write `scripts/build_sft_pairs.py` — generate instruction pairs using a teacher model (Claude Sonnet or GPT-4o) seeded with handbook paragraphs + TacNet storyboard shots.
4. Run Stage 1 (pretraining LoRA).
5. Run Stage 2 (SFT LoRA).
6. Evaluate and iterate.
7. Merge, re-quantize, ship into TacNet.

This plan treats the Ranger Handbook not as a knowledge base but as a **voice coach** for the SLM — turning every raw operator utterance into a line of prose a squad leader would actually say on the net.
