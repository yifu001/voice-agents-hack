# TTS Hard Hooks — PostProcessor Filter Chain Specification

**Version:** 1.0
**Status:** Authoritative reference
**Scope:** Every string emitted by the TacNet SLM must pass through this filter chain before reaching the TTS engine and the operator's earpiece.

---

## Architecture: Relay-Only Signal Processor

The TacNet SLM is **not** a conversational assistant. It is a **relay and compactor**.

```
Operator voice → STT → SLM (compacts/reformats) → PostProcessor → TTS → Earpiece
```

The model listens to voice input from one operator, compresses or summarizes it, and forwards the compressed version to other operators' earpieces via TTS. The SLM is a signal processor, not a participant. It never "replies" to the operator in a conversational sense — it reformats and routes.

The PostProcessor is the **last gate** between the SLM's raw text output and the TTS engine. Its job is to enforce hard constraints that are cheaper and more reliable to enforce in code than in weights. Every filter in this document is a deterministic, non-negotiable rule. The SLM should already be trained to approximate these rules, but the PostProcessor is the safety net.

---

## Filter Chain Order

Filters execute in this exact sequence. Output of each stage is input to the next.

```
1. FORMATTING   (HH-001 → HH-006)   Strip non-spoken artifacts
2. LENGTH       (HH-007 → HH-010)   Enforce word budgets
3. CLARITY      (HH-011 → HH-016)   Fix TTS-hostile patterns
4. NOISE        (HH-017 → HH-020)   Strip filler / hedging / pleasantries
5. SAFETY       (HH-021 → HH-024)   Flag fabrication / profanity
6. TEMPORAL     (HH-025 → HH-026)   Normalize time references
7. PHONETIC     (HH-027 → HH-029)   Military radio conventions
```

Formatting runs first because length enforcement needs a clean string to count words accurately. Length runs before clarity so that word-budget truncation operates on the already-stripped text. Safety runs late so it can inspect the near-final output. Phonetic runs last because replacements like "niner" change word shapes and must not be double-processed.

---

## Hooks

### Category 1: FORMATTING (strip before TTS)

---

#### HH-001 — No Emojis

| Field | Value |
|---|---|
| **ID** | HH-001 |
| **Name** | Strip Emojis |
| **Category** | FORMATTING |
| **Description** | Remove all Unicode emoji codepoints from output. TTS engines either skip them silently or read their Unicode names ("face with tears of joy"), both unacceptable on a tactical net. |
| **Detection** | Regex: match any codepoint in Unicode emoji ranges — `[\U0001F600-\U0001F64F\U0001F300-\U0001F5FF\U0001F680-\U0001F6FF\U0001F1E0-\U0001F1FF\U00002702-\U000027B0\U0000FE00-\U0000FE0F\U0001F900-\U0001F9FF\U0001FA00-\U0001FA6F\U0001FA70-\U0001FAFF\U00002600-\U000026FF\U0000200D\U00002B50\U0000231A-\U0000231B\U000023E9-\U000023F3\U000023F8-\U000023FA\U000025AA-\U000025AB\U000025B6\U000025C0\U000025FB-\U000025FE\U00002934-\U00002935\U00002B05-\U00002B07\U00002B1B-\U00002B1C\U00003030\U0000303D\U00003297\U00003299]` and general category `\p{Emoji_Presentation}` |
| **Action** | Strip (replace with empty string). |
| **Test** | Input: `"Foyer clear 👍, 1 EKIA 🔥"` → Output: `"Foyer clear, 1 EKIA"` |

---

#### HH-002 — No Markdown Formatting

| Field | Value |
|---|---|
| **ID** | HH-002 |
| **Name** | Strip Markdown |
| **Category** | FORMATTING |
| **Description** | Remove all markdown syntax: bold (`**`), italic (`_`, `*`), headings (`#`), inline code (`` ` ``), code blocks (`` ``` ``), strikethrough (`~~`), links (`[text](url)`), images (`![alt](url)`), horizontal rules (`---`, `***`). TTS reads these as literal characters or pauses incorrectly. |
| **Detection** | Regex chain: `\*{1,3}`, `_{1,2}`, `#{1,6}\s`, `` `{1,3} ``, `~~`, `\[([^\]]*)\]\([^\)]*\)` (capture group 1 kept), `!\[([^\]]*)\]\([^\)]*\)` (strip entirely), `^-{3,}$`, `^\*{3,}$` |
| **Action** | Strip markers, keep enclosed text for bold/italic/links. Strip entire image/HR syntax. |
| **Test** | Input: `"**Contact** north, _urgent_"` → Output: `"Contact north, urgent"` |

---

#### HH-003 — No Bullet Points or Numbered Lists

| Field | Value |
|---|---|
| **ID** | HH-003 |
| **Name** | Flatten Lists |
| **Category** | FORMATTING |
| **Description** | TTS output is a single spoken string. Bullet points and numbered lists produce awkward pauses or literal "dash" / "one period" readings. Collapse all list items into a single comma-separated or semicolon-separated string. |
| **Detection** | Line-start patterns: `^\s*[-*+]\s`, `^\s*\d+[.)]\s` |
| **Action** | Strip the bullet/number prefix, join all list items with `"; "`. Collapse to one line. |
| **Test** | Input: `"- Foyer clear\n- Kitchen clear\n- 1 EKIA"` → Output: `"Foyer clear; Kitchen clear; 1 EKIA"` |

---

#### HH-004 — No Parenthetical Asides

| Field | Value |
|---|---|
| **ID** | HH-004 |
| **Name** | Strip Parentheticals |
| **Category** | FORMATTING |
| **Description** | Parenthesized text causes TTS to drop pitch and pace awkwardly, producing garbled output on low-quality earpiece speakers. Remove all parenthetical content entirely. |
| **Detection** | Regex: `\s*\([^)]*\)` |
| **Action** | Strip the parenthesized segment and any leading space. |
| **Test** | Input: `"1 EKIA (confirmed by thermal)"` → Output: `"1 EKIA"` |

---

#### HH-005 — No Stray Quotation Marks

| Field | Value |
|---|---|
| **ID** | HH-005 |
| **Name** | Strip Stray Quotes |
| **Category** | FORMATTING |
| **Description** | Quotation marks cause TTS to insert pauses or read "quote/unquote." Only acceptable when quoting a callsign or direct relay. Since the PostProcessor cannot reliably determine intent, strip all quotation marks (straight and curly). |
| **Detection** | Regex: `[""\u201C\u201D\u2018\u2019'']` |
| **Action** | Strip (replace with empty string). |
| **Test** | Input: `"SL said \"push north\""` → Output: `"SL said push north"` |

---

#### HH-006 — No Special Characters

| Field | Value |
|---|---|
| **ID** | HH-006 |
| **Name** | Strip/Spell-Out Special Characters |
| **Category** | FORMATTING |
| **Description** | Characters `@`, `&`, `%`, `+`, `=`, `<`, `>` are read inconsistently by TTS engines. Spell out where meaningful, strip otherwise. |
| **Detection** | Literal character match for each: `@`, `&`, `%`, `+`, `=`, `<`, `>` |
| **Action** | `&` → `"and"`, `%` → `"percent"`, `+` → `"plus"`, `@` → `"at"`. Strip `=`, `<`, `>` entirely. |
| **Test** | Input: `"Ammo at 50% & falling"` → Output: `"Ammo at 50 percent and falling"` |

---

### Category 2: LENGTH

---

#### HH-007 — Leader Earpiece Word Cap

| Field | Value |
|---|---|
| **ID** | HH-007 |
| **Name** | Leader 18-Word Cap |
| **Category** | LENGTH |
| **Description** | Output routed to the Squad Leader earpiece is hard-capped at 18 words per turn. The leader is under maximum cognitive load. Every extra word is a word that could kill them. |
| **Detection** | `len(text.split()) > 18` when `role == "leader"` |
| **Action** | Truncate to first 18 words. Do not add ellipsis or truncation markers — they waste a word. |
| **Test** | Input (role=leader): `"First floor 90 percent clear one EKIA Team two in contact upstairs request permission to reinforce from ground floor now"` (20 words) → Output: `"First floor 90 percent clear one EKIA Team two in contact upstairs request permission to reinforce from ground"` (18 words) |

---

#### HH-008 — Peer Routing Word Cap

| Field | Value |
|---|---|
| **ID** | HH-008 |
| **Name** | Peer 12-Word Cap |
| **Category** | LENGTH |
| **Description** | Output routed to peer operators is hard-capped at 12 words per turn. Peers need the shortest possible directive — they are likely in contact. |
| **Detection** | `len(text.split()) > 12` when `role == "peer"` |
| **Action** | Truncate to first 12 words. No ellipsis. |
| **Test** | Input (role=peer): `"Push upstairs now reinforce Team one hold landing zone until further orders come through"` (14 words) → Output: `"Push upstairs now reinforce Team one hold landing zone until further orders"` (12 words) |

---

#### HH-009 — SITREP Relay Cap

| Field | Value |
|---|---|
| **ID** | HH-009 |
| **Name** | SITREP 20-Word Cap |
| **Category** | LENGTH |
| **Description** | Summarized conversation or SITREP relay must be one sentence, max 20 words. Applied universally regardless of role when the output is detected as a SITREP. |
| **Detection** | Output contains `"SITREP"` (case-insensitive) AND `len(text.split()) > 20` |
| **Action** | Truncate to first 20 words. |
| **Test** | Input: `"OP1 SITREP: First floor clear one EKIA no friendly casualties ammo green moving to second floor stairwell west side of building now"` (21 words) → Output: `"OP1 SITREP: First floor clear one EKIA no friendly casualties ammo green moving to second floor stairwell west side of building"` (20 words) |

---

#### HH-010 — Overflow Truncation

| Field | Value |
|---|---|
| **ID** | HH-010 |
| **Name** | Hard Overflow Truncation |
| **Category** | LENGTH |
| **Description** | Final safety net: if after role-based capping the output still exceeds the applicable word budget (should not happen, but defense-in-depth), truncate to the most tactically relevant fragment. Heuristic: keep the first N words, as the model is trained to front-load critical information. Never overflow — silence is better than garbled overflow. |
| **Detection** | `len(text.split()) > max_words` after HH-007/HH-008/HH-009 |
| **Action** | Truncate to `max_words`. This is a redundant backstop. |
| **Test** | Input (role=leader, 25 words after prior filters somehow): any string > 18 words → Output: first 18 words |

---

### Category 3: SPOKEN CLARITY (TTS-hostile patterns)

---

#### HH-011 — Unapproved Acronyms

| Field | Value |
|---|---|
| **ID** | HH-011 |
| **Name** | Acronym Gating |
| **Category** | CLARITY |
| **Description** | TTS engines mangle unfamiliar acronyms (reading them letter-by-letter or as words). Only acronyms in the pre-approved operator vocabulary pass through. Unapproved acronyms are flagged for expansion or stripped. |
| **Pre-Approved List** | `EKIA, SITREP, SALUTE, CASEVAC, MEDEVAC, LACE, ACE, BDA, CCIR, PIR, EEI, PACE, ROE, METT-TC, SOP, TTP, CAS, WIA, PC, HVT, LZ, PZ, ORP, SBF, TRP, PL, LD, SP, RP, NVG, GPNVG, BLE, UNK, RTN` |
| **Detection** | Regex: `\b[A-Z]{2,}(?:-[A-Z]{2,})?\b` — match any 2+ uppercase-letter sequence (with optional hyphenated compound like METT-TC). Check if match is in the approved set. |
| **Action** | If not in approved set, flag for review. In automated mode, strip the unapproved acronym and replace with `"UNK"` if no expansion is available. |
| **Test** | Input: `"EKIA confirmed, JTAC requesting CAS"` → Output: `"EKIA confirmed, UNK requesting CAS"` (JTAC not in approved list) |

---

#### HH-012 — Homophone Disambiguation

| Field | Value |
|---|---|
| **ID** | HH-012 |
| **Name** | Homophone Safety |
| **Category** | CLARITY |
| **Description** | Words like "right", "fire", "round", "clear" are ambiguous when spoken without context. TTS cannot add vocal emphasis. When a homophone-ambiguous word appears without a disambiguating modifier, flag it. |
| **Detection** | Watchlist: `right, left, fire, round, clear, cover, check, hold, mark, point, base, contact`. Regex: `\b(right|left)\b` not followed within 2 words by a direction/side/correct qualifier. |
| **Action** | Flag for human review. In automated mode, the filter is advisory — it logs a warning but does not alter text, since false-positive rewriting is worse than the ambiguity. |
| **Test** | Input: `"Move right"` → Output: `"Move right"` + warning log: `"HH-012: 'right' may be ambiguous — consider 'right side' or cardinal direction"` |

---

#### HH-013 — Number Normalization

| Field | Value |
|---|---|
| **ID** | HH-013 |
| **Name** | Number Spoken Form |
| **Category** | CLARITY |
| **Description** | Numbers 1–9 are spoken as words for clarity on noisy channels ("three" not "3"). Numbers 10+ remain as digits ("15" not "fifteen") because digit strings are faster for TTS and the operator is trained to parse them. |
| **Detection** | Regex: `\b([1-9])\b` for single digits (word-boundary on both sides to avoid matching digits within larger numbers). |
| **Action** | Replace single digit with its word form: 1→one, 2→two, 3→three, 4→four, 5→five, 6→six, 7→seven, 8→eight, 9→nine. Leave 10+ as digits. |
| **Test** | Input: `"3 hostiles, 15 meters north"` → Output: `"three hostiles, 15 meters north"` |

---

#### HH-014 — Grid Coordinate Formatting

| Field | Value |
|---|---|
| **ID** | HH-014 |
| **Name** | Grid Digit Groups |
| **Category** | CLARITY |
| **Description** | Grid coordinates must be spoken in digit groups for radio clarity. A 6-digit grid like `972416` is spoken as "niner-seven-two, four-one-six" (two groups of three). An 8-digit grid is two groups of four. |
| **Detection** | Regex: `\bgrid\s*(\d{6,8})\b` (case-insensitive) |
| **Action** | Split the digit string into two equal halves. Render each digit as its spoken word (applying HH-029 "niner" rule). Separate groups with comma. Prefix with "grid". |
| **Test** | Input: `"grid 972416"` → Output: `"grid niner-seven-two, four-one-six"` |

---

#### HH-015 — No Double Negatives

| Field | Value |
|---|---|
| **ID** | HH-015 |
| **Name** | Eliminate Double Negatives |
| **Category** | CLARITY |
| **Description** | Double negatives ("not unlikely", "not impossible", "no one didn't") are confusing on a tactical net where operators are under cognitive load. Rewrite to affirmative form. |
| **Detection** | Pattern pairs: `not un\w+`, `not im\w+`, `not in\w+` (where the root word starts with a negative prefix), `no one didn't`, `never not`, `not without` |
| **Action** | Rewrite to affirmative. `"not unlikely"` → `"likely"`, `"not impossible"` → `"possible"`, `"not without risk"` → `"risky"`. |
| **Test** | Input: `"Area is not unlikely hostile"` → Output: `"Area is likely hostile"` |

---

#### HH-016 — Cardinal Directions Over Relative

| Field | Value |
|---|---|
| **ID** | HH-016 |
| **Name** | Prefer Cardinal Directions |
| **Category** | CLARITY |
| **Description** | Cardinal directions ("north", "south", "east", "west") are unambiguous regardless of the listener's facing. Relative directions ("left", "right", "front", "back") depend on orientation and cause confusion when relayed between teams. Flag relative directions for upgrade to cardinal. |
| **Detection** | Regex: `\b(left side|right side|front side|back side|left flank|right flank)\b` (case-insensitive) |
| **Action** | Advisory flag — log warning. The PostProcessor cannot know the correct cardinal equivalent without spatial context, so this is a log-and-flag rule, not auto-replace. |
| **Test** | Input: `"Hostiles on left side"` → Output: `"Hostiles on left side"` + warning log: `"HH-016: 'left side' — prefer cardinal direction if known"` |

---

### Category 4: NOISE DISCIPLINE

---

#### HH-017 — No Filler Phrases

| Field | Value |
|---|---|
| **ID** | HH-017 |
| **Name** | Strip Filler |
| **Category** | NOISE |
| **Description** | Filler phrases are conversational artifacts that waste airtime and add no tactical information. The SLM is a relay, not a participant — it has no reason to acknowledge, confirm, or stall. |
| **Filler List** | `I understand, Copy that, Roger let me think, Understood, Acknowledged, Let me check, Sure, Okay so, Alright, OK, Well, So, Basically, Actually, Just, Right so, Yeah, Yes sir, Got it, Affirmative` |
| **Detection** | Case-insensitive prefix/substring match. Regex: `(?i)^(I understand|Copy that|Roger let me think|Understood|Acknowledged|Let me check|Sure|Okay so|Alright|OK|Well|So|Basically|Actually|Right so|Yeah|Yes sir|Got it|Affirmative)[,.:;!\s]*` for leading fillers. Also scan mid-sentence for `, (okay so|basically|actually|just),?`. |
| **Action** | Strip the filler phrase. If the entire output is filler, emit nothing (silence). |
| **Test** | Input: `"Copy that, moving to second floor"` → Output: `"moving to second floor"` |

---

#### HH-018 — No Hedging

| Field | Value |
|---|---|
| **ID** | HH-018 |
| **Name** | Strip Hedging |
| **Category** | NOISE |
| **Description** | Hedging language is forbidden on a tactical net. The SLM must state what it knows or state UNK. There is no middle ground. "It seems like" costs lives. |
| **Hedge List** | `it seems like, it seems, probably, I think, might be, perhaps, possibly, likely, arguably, it appears, it looks like, it could be, there may be, I believe, I suspect, it's possible, potentially, presumably, supposedly, apparently` |
| **Detection** | Case-insensitive substring match. Regex: `(?i)\b(it seems like|it seems|probably|I think|might be|perhaps|possibly|likely|arguably|it appears|it looks like|it could be|there may be|I believe|I suspect|it's possible|potentially|presumably|supposedly|apparently)\b` |
| **Action** | Strip the hedge phrase. If stripping leaves a grammatically incomplete sentence, the output stands as-is (terse is acceptable). If the entire output is hedging, replace with `"UNK"`. |
| **Test** | Input: `"It seems like there are 3 hostiles north"` → Output: `"there are three hostiles north"` |

---

#### HH-019 — No Pleasantries

| Field | Value |
|---|---|
| **ID** | HH-019 |
| **Name** | Strip Pleasantries |
| **Category** | NOISE |
| **Description** | Pleasantries are social artifacts. The SLM is not a person and operators are not having a conversation with it. Every "please" and "thank you" wastes a word in the earpiece budget. |
| **Pleasantry List** | `please, thank you, thanks, good luck, be safe, stay safe, take care, you're welcome, no problem, my pleasure, God speed, Godspeed` |
| **Detection** | Case-insensitive substring match. Regex: `(?i)\b(please|thank you|thanks|good luck|be safe|stay safe|take care|you're welcome|no problem|my pleasure|God ?speed)\b` |
| **Action** | Strip the pleasantry. Clean up any resulting double spaces or leading/trailing punctuation. |
| **Test** | Input: `"Please move to second floor, stay safe"` → Output: `"move to second floor"` |

---

#### HH-020 — No Self-Referential Language

| Field | Value |
|---|---|
| **ID** | HH-020 |
| **Name** | Strip Self-Reference |
| **Category** | NOISE |
| **Description** | The SLM must never identify itself as an AI or describe its own capabilities. It is a transparent relay — operators should perceive clean tactical comms, not an AI talking about itself. |
| **Self-Reference List** | `As your AI, I'm here to help, Let me help, I can assist, My purpose is, As an AI, I'm designed to, My role is, I'm programmed to, Allow me to, I'd be happy to, I'm able to` |
| **Detection** | Case-insensitive substring match. Regex: `(?i)(As your AI|I'm here to help|Let me help|I can assist|My purpose is|As an AI|I'm designed to|My role is|I'm programmed to|Allow me to|I'd be happy to|I'm able to)` |
| **Action** | Strip the self-referential phrase. If the entire output is self-referential, emit nothing (silence). |
| **Test** | Input: `"As your AI, the foyer has 1 EKIA"` → Output: `"the foyer has one EKIA"` |

---

### Category 5: SAFETY / CONTENT

---

#### HH-021 — No Fabrication

| Field | Value |
|---|---|
| **ID** | HH-021 |
| **Name** | Fabrication Detection |
| **Category** | SAFETY |
| **Description** | The SLM must never invent grid coordinates, casualty counts, or intel. This is a soul.md hard rule enforced at the PostProcessor layer. If an output contains patterns that suggest fabricated data (grid coordinates not present in any recent input, precise counts without a source), flag it. |
| **Detection** | Heuristic markers: (1) grid coordinates in output that were not in the input context, (2) specific numeric claims without "confirmed" or "estimated" qualifier (see HH-022), (3) phrases like "I estimate" or "approximately" paired with precise numbers. This filter works in conjunction with the inference context — it needs access to recent input for cross-referencing. |
| **Action** | Replace suspected fabricated field with `"UNK"`. Log the replacement for audit. |
| **Test** | Input context had no grid. Output: `"Hostiles at grid 123456"` → Output: `"Hostiles at grid UNK"` |

---

#### HH-022 — Unverified Counts

| Field | Value |
|---|---|
| **ID** | HH-022 |
| **Name** | Count Qualifier Enforcement |
| **Category** | SAFETY |
| **Description** | Bare numbers without "confirmed" or "estimated" qualifier can be mistaken for verified intel. Every count relayed must carry a qualifier. |
| **Detection** | Regex: `\b(\d+)\s+(hostile|hostiles|EKIA|WIA|casualties|enemy|enemies|tangos|contacts)\b` NOT preceded within 3 words by `confirmed|estimated|approx|suspected|reported` |
| **Action** | Advisory flag — log warning: `"HH-022: unqualified count detected — add 'confirmed' or 'estimated'"`. In strict mode, prepend `"estimated"` before the count. |
| **Test** | Input: `"3 hostiles north"` → Output (strict): `"estimated three hostiles north"` |

---

#### HH-023 — Classification Marker Preservation

| Field | Value |
|---|---|
| **ID** | HH-023 |
| **Name** | Preserve Classification |
| **Category** | SAFETY |
| **Description** | If the input contains classification markers (SECRET, TOP SECRET, CONFIDENTIAL, UNCLASSIFIED, FOUO, NOFORN, REL TO), the output must preserve them verbatim. The SLM must never reword, abbreviate, or strip classification markings. |
| **Detection** | Regex: `\b(SECRET|TOP SECRET|CONFIDENTIAL|UNCLASSIFIED|FOUO|NOFORN|REL TO [A-Z]+)\b` in input. If present, verify same marker exists in output. |
| **Action** | If output is missing a classification marker that was in the input, prepend the marker to the output. Log the correction. |
| **Test** | Input: `"SECRET: grid 972416 is HVT location"`, Output missing marker: `"grid niner-seven-two, four-one-six is HVT location"` → Corrected output: `"SECRET: grid niner-seven-two, four-one-six is HVT location"` |

---

#### HH-024 — No Profanity

| Field | Value |
|---|---|
| **ID** | HH-024 |
| **Name** | Profanity Filter |
| **Category** | SAFETY |
| **Description** | The SLM output must be clean. Profanity on a tactical net is unprofessional and can be misheard as a command. Maintain a blocklist and strip or replace. |
| **Detection** | Blocklist-based substring match (case-insensitive). The blocklist is maintained as a separate config and not printed in this spec for brevity. Common tactical-context profanity patterns are covered. |
| **Action** | Strip the profane word. If stripping breaks the sentence, replace with a clean tactical equivalent or omit entirely. |
| **Test** | Input: `"Get the hell out of there"` → Output: `"Get out of there"` |

---

### Category 6: TEMPORAL DISCIPLINE

---

#### HH-025 — Relative Time Over Absolute

| Field | Value |
|---|---|
| **ID** | HH-025 |
| **Name** | Relative Time Preference |
| **Category** | TEMPORAL |
| **Description** | Absolute timestamps (HH:MM:SS, "at 1432") require operators to do mental math against current time under stress. Relative time ("30 seconds ago", "2 mikes") is immediately actionable. Flag absolute time patterns for conversion. |
| **Detection** | Regex: `\b\d{1,2}:\d{2}(:\d{2})?\b` and `\b\d{4}(h|hrs|hours|Z|z)?\b` (military time patterns like "1432" or "1432Z") |
| **Action** | Advisory flag — log warning: `"HH-025: absolute time detected — prefer relative time ('X mikes ago')"`. Auto-conversion requires a clock reference the PostProcessor may not have, so this is flag-only. |
| **Test** | Input: `"Contact reported at 14:32"` → Output: `"Contact reported at 14:32"` + warning log: `"HH-025: absolute time '14:32' — prefer relative"` |

---

#### HH-026 — Present-Tense Urgency

| Field | Value |
|---|---|
| **ID** | HH-026 |
| **Name** | NOW/Current Enforcement |
| **Category** | TEMPORAL |
| **Description** | When describing a present-tense situation, the output should use "NOW" or "current" to convey urgency. Ambiguous present-tense without urgency markers can be mistaken for historical reports. |
| **Detection** | Heuristic: output contains present-tense action verbs (`is, are, moving, engaging, taking fire, pushing`) without "NOW", "current", or relative time markers. |
| **Action** | Advisory flag — log warning: `"HH-026: present-tense without urgency marker — consider adding 'NOW' or 'current'"`. |
| **Test** | Input: `"Team 2 is taking fire"` → Output: `"Team 2 is taking fire"` + warning log: `"HH-026: present-tense 'is taking fire' — consider 'NOW taking fire'"` |

---

### Category 7: PHONETIC SAFETY

---

#### HH-027 — Callsigns Over Names

| Field | Value |
|---|---|
| **ID** | HH-027 |
| **Name** | Name-to-Callsign |
| **Category** | PHONETIC |
| **Description** | Real names must never be broadcast on a tactical net. They compromise operator identity. The SLM should use callsigns (SL, TL-A, A1, BREACHER, etc.). The PostProcessor maintains a small blocklist of common first names and flags any match. This is primarily a soul.md rule; the PostProcessor is the safety net. |
| **Detection** | Blocklist of common first names (top 200 English first names). Regex: `\b(Name1|Name2|...)\b` case-insensitive. Also flag any word that looks like a proper name (capitalized, not at sentence start, not a known callsign or place name). |
| **Action** | Advisory flag — log warning: `"HH-027: possible real name detected — use callsign"`. In strict mode, replace with `"CALLSIGN"`. |
| **Test** | Input: `"Mike is hit, need CASEVAC"` → Output (strict): `"CALLSIGN is hit, need CASEVAC"` |

---

#### HH-028 — Phonetic Alphabet for Single Letters

| Field | Value |
|---|---|
| **ID** | HH-028 |
| **Name** | NATO Phonetic Singles |
| **Category** | PHONETIC |
| **Description** | Single letters spoken aloud are lost in noise. When a letter stands alone (e.g., "team A", "point B", "route C"), replace it with the NATO phonetic equivalent. Do NOT expand letters that are part of known acronyms (those are handled by HH-011). |
| **Detection** | Regex: `\b([A-Z])\b` — single uppercase letter surrounded by word boundaries, not part of a larger acronym token. |
| **Action** | Replace with NATO phonetic: A→Alpha, B→Bravo, C→Charlie, D→Delta, E→Echo, F→Foxtrot, G→Golf, H→Hotel, I→India, J→Juliet, K→Kilo, L→Lima, M→Mike, N→November, O→Oscar, P→Papa, Q→Quebec, R→Romeo, S→Sierra, T→Tango, U→Uniform, V→Victor, W→Whiskey, X→X-ray, Y→Yankee, Z→Zulu. |
| **Test** | Input: `"Team A push to point B"` → Output: `"Team Alpha push to point Bravo"` |

---

#### HH-029 — Niner Not Nine

| Field | Value |
|---|---|
| **ID** | HH-029 |
| **Name** | Niner Convention |
| **Category** | PHONETIC |
| **Description** | Standard military radio convention: "nine" is spoken as "niner" to avoid confusion with "nein" (German for "no") and "five" on noisy channels. Apply to all instances of the word "nine" or the digit "9" when spoken as a standalone word. |
| **Detection** | Regex: `\bnine\b` (case-insensitive) and `\b9\b` (when being converted to spoken form by HH-013). |
| **Action** | Replace `"nine"` with `"niner"`. When HH-013 converts the digit `9` to a word, it should produce `"niner"` not `"nine"`. |
| **Test** | Input: `"nine hostiles at grid 972416"` → Output: `"niner hostiles at grid niner-seven-two, four-one-six"` |

---

## Failure Mode

If the output fails final validation after all 29 filters have been applied (e.g., the result is empty, contains only whitespace, or is otherwise malformed):

**Emit nothing. Silence.**

It is better to drop a message than to deliver garbled, misleading, or dangerous output to an operator's earpiece during combat. The SLM will generate a new output on the next cycle.

Specifically:
1. If the final string after all filters is empty or whitespace-only → emit silence.
2. If the final string contains only `"UNK"` with no context → emit silence (a bare "UNK" with no field label is useless).
3. If the final string exceeds the word cap even after HH-010 (should be impossible, but defense-in-depth) → emit silence.

All failures are logged for post-mission debrief and model improvement.

---

## Integration Notes

- The PostProcessor runs **after** SLM inference and **before** TTS synthesis.
- It receives: `(text: String, role: String, inputContext: String?)` where `role` is `"leader"` or `"peer"` and `inputContext` is the original operator voice input (for fabrication cross-referencing in HH-021/HH-023).
- It returns: `(text: String?, warnings: [String])` where `text` is `nil` for silence.
- The Python reference implementation in `scripts/post_processor_filters.py` mirrors every filter as a pure function for testing and validation before the Swift port.
- The Swift port should live in `TacNet/PostProcessor/` and be called from the inference pipeline.

---

*End of TTS_HARD_HOOKS.md. This document is the single source of truth for PostProcessor behavior. Any conflict between this spec and the implementation is a bug in the implementation.*
