# RangerHandbook — Training Corpus for TacNet SLM Style Fine-Tune

This folder converts the **US Army Ranger Handbook, TC 3-21.76 (April 2017, 370 pages)** into clean structured Markdown that can be used to fine-tune Gemma 4 E4B so the on-device SLM in TacNet speaks like a Tier-1 Ranger on the net (SALUTE, SITREP, ACE, LACE, 9-line MEDEVAC, OPORD-flavored prose).

## Pipeline used

1. `pdftotext -layout` extracted raw text from the source PDF (`/Users/yifuzuo/Downloads/TC 3-21.76 Ranger Handbook.pdf`, 22 MB, 370 pages) into 15 chunks of ~25 pages each. Raw outputs live in `chunks_txt/`.
2. **15 sub-agents ran in parallel**, one per chunk, converting each raw text file into structured Markdown (`#` chapters, `##` sections, `###` doctrine paragraph numbers, preserved tables/figures/acronyms). Per-chunk outputs in `chunks_md/`.
3. A final concatenation stitched `chunks_md/01.md` … `chunks_md/15.md` in order into `RANGER_HANDBOOK.md`.

## Files

- `RANGER_HANDBOOK.md` — the stitched master (~600 KB, ~8k lines). Use this as the training corpus.
- `FINE_TUNING_PLAN.md` — end-to-end plan: data prep → LoRA/QLoRA two-stage training → evaluation → redeployment into TacNet via Cactus.
- `chunks_txt/NN_pX-Y.txt` — intermediate raw pdftotext output per 25-page chunk. Kept for traceability.
- `chunks_md/NN.md` — per-chunk structured Markdown. Kept for reproducibility — if any chunk needs to be re-rendered, just re-run that one sub-agent.
- `README.md` — this file.

## Known source artifacts preserved verbatim

The pdftotext extraction introduced a few doctrine-paragraph-number dropouts (e.g., `**10-.**` instead of `**10-18.**`) and a handful of table-column OCR misalignments. Sub-agents preserved these verbatim rather than guess — it's safer to surface them than to hallucinate. A cleanup pass before training is trivial (search for `**NN-\.\*\*` patterns) but for most training purposes these are harmless.

## Next step

See `FINE_TUNING_PLAN.md` for the full training recipe. Fastest path: Unsloth on a T4 Colab with 4-bit QLoRA, Stage-1 + Stage-2 in under 8 hours.
