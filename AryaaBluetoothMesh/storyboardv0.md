# MeshNode — Demo Video Storyboard v0

**Runtime:** 60 seconds
**Tone:** product explainer, not trailer. Plain narration, minimal music, direct visuals.

---

## Pitch

> Military radios drown soldiers in noise. **MeshNode gives every soldier a smart radio that filters exactly what they need to hear.**

Later in the video we reveal the second half: because every phone already holds the whole squad's context, every soldier also gets an on-device AI they can *ask* — instead of having to radio another soldier.

---

## Structure at a glance

| Block | Seconds | Purpose |
|---|---|---|
| Problem statement | 0:00 – 0:08 | hook |
| Solution statement | 0:08 – 0:13 | hook |
| Demo Beat 1 — filtering | 0:13 – 0:32 | the *radio* half |
| Demo Beat 2 — the AI | 0:32 – 0:47 | the *intelligence* half |
| How it works (4 panels) | 0:47 – 0:55 | credibility |
| Close | 0:55 – 1:00 | tagline |

---

## Cast

Four real iPhones running MeshNode. Each phone is assigned a node identity that matches the graph in `graph.json`.

| Node ID | Role in the story | Graph role |
|---|---|---|
| **A** | Higher command (HQ) | A ↔ B both *exact* |
| **B** | Platoon lead | Central hub; receives *summaries* from C and D |
| **C** | Fireteam 1 | B → C *exact*, C → B *summary* |
| **D** | Fireteam 2 | B → D *exact*, D → B *summary* |

B is the story's eye. Noisy data comes up from the field (C, D) as summaries. Verbatim orders go out to everyone else.

---

## Full storyboard

| Time | Visual | Audio / VO | On-screen text |
|---|---|---|---|
| **0:00 – 0:08** | Plain dark frame. A single phone illustration on the left. On the right, speech bubbles stack in faster than the eye can read them. An ear icon at the top looks overwhelmed. | *"Squad radios have one problem. Everyone hears everything. A platoon lead trying to coordinate gets drowned in chatter from every fireteam below them."* | — |
| **0:08 – 0:13** | Clean cut. Two phones side by side, both running MeshNode. Title above: **MESHNODE**. Subtitle: *A smart radio that filters what each soldier hears.* | *"MeshNode is a smart radio. Every soldier gets a filtered view — verbatim where it matters, paraphrased where it doesn't."* | **MESHNODE** · *a smart radio that filters what each soldier hears* |
| **0:13 – 0:32** | **Demo Beat 1 — filtering.** Split screen: left phone labelled **CHARLIE (Fireteam 1)**, right phone labelled **BRAVO (Platoon Lead)**. Charlie taps the mic and speaks into it. Left phone: Charlie's exact message appears. Right phone: a shorter italic version appears with the `PARAPHRASED` left-rail treatment. Hold 2 seconds so the viewer can read both. | IRL: *"Two contacts, 200 meters, suppressed by Bravo."* VO over: *"Here, Charlie reports a contact from the field. His fireteam hears every word. But his platoon lead gets the gist — one line, no noise."* | (phone labels persistent top-centre of each screen) |
| **0:32 – 0:47** | **Demo Beat 2 — the AI.** Cut to Bravo's phone full-screen, Retrieval tab. Bravo holds the hero mic, asks the question aloud. Gemma's answer streams in, token by token. | IRL: *"Where's Delta right now?"* VO: *"And because every phone already holds the whole squad's picture, Bravo can just ask. The answer comes from an AI running on the phone. Not a server. Not the cloud."* | phone header: `NODE B · RETRIEVAL` |
| **0:47 – 0:55** | **How it works — 4 panels, same 4 nodes, only the edges change.** See "Tech panels" section below. | VO as one sentence in four beats — see "Narrator script". | each panel caption burns in for its 2-second hold |
| **0:55 – 1:00** | Single iPhone in frame, airplane-mode icon visible. Tagline card crossfades in. | *(silence, then one clean beep)* | **MESHNODE. OFFLINE. ON DEVICE.** · *team name, small caps, below* |

---

## Tech panels (0:47 – 0:55)

### Fixed layout

All four panels share the same four nodes in fixed positions — a diamond. Nodes **never move**, never re-label, never change size. Only the **edges** change between panels. That visual stillness is what makes the whole sequence read as progressive refinement rather than four disparate diagrams.

```
              A       (HQ)
              │
              B       (Platoon lead)
            ╱   ╲
          C       D   (Fireteam 1, Fireteam 2)
```

### The four panels

| # | Edges shown | Visual treatment | Caption |
|---|---|---|---|
| **1** | All 6 pairs connected: A–B, A–C, A–D, B–C, B–D, C–D | Thin white undirected lines, equal weight | **Bluetooth mesh.** Peer-to-peer. |
| **2** | Hierarchy edges only (from `graph.json`): A↔B, B↔C, B↔D — 6 directed arrows total | Solid black arrows for `exact`; green dashed arrows for `summary` | **Hierarchy graph.** Verbatim vs paraphrased. |
| **3** | Undirected hierarchy: A–B, B–C, B–D (3 pairs, now as single undirected lines) | All edges white, no arrowheads. Dotted circle drawn around node **D** with radius = 2, encompassing D, B, A, C | **Context window.** Undirected BFS. |
| **4** | Edges fade to 20% opacity | A small pulsing dot glyph appears *inside* each node circle | **On-device models.** No cloud. |

### Transitions (0.5 s cross-fade each)

- **1 → 2** — The three off-hierarchy edges (A–C, A–D, C–D) fade out. The remaining three split into arrow pairs; two pairs take on the green-dashed `summary` treatment. Caption cross-fades.
- **2 → 3** — Arrowheads fade. Dashed edges become solid. Paired arrows collapse into single undirected lines. The `radius = 2` ring draws in with a quick stroke animation around node D.
- **3 → 4** — Ring fades. All edges drop to 20% opacity. A small dot appears inside each of the four nodes and begins a slow pulse.

---

## Narrator script

Record once, in one breath per paragraph. Calm, low, explanatory — at the pace of a product-demo voice, not a trailer voice.

> "Squad radios have one problem. Everyone hears everything. A platoon lead trying to coordinate gets drowned in chatter from every fireteam below them."
>
> "MeshNode is a smart radio. Every soldier gets a filtered view — verbatim where it matters, paraphrased where it doesn't."
>
> "Here, Charlie reports a contact from the field. His fireteam hears every word. But his platoon lead gets the gist — one line, no noise."
>
> "And because every phone already holds the whole squad's picture, Bravo can just ask. The answer comes from an AI running on the phone. Not a server. Not the cloud."

Tech section — read as a single sentence, with the "…" breaks timed to the panel cross-fades:

> "Under the hood: a Bluetooth mesh where every phone talks to every phone… a directed graph decides what each soldier hears verbatim, and what they hear as a summary… the same graph — undirected — defines the context window when a soldier asks a question… and every answer is generated on the phone itself."

**Total spoken time:** ~28 seconds. Plenty of headroom against the 60-second runtime.

---

## Production checklist

### Before shooting
- All four iPhones on airplane mode. Verify the mesh still establishes over Bluetooth.
- Each phone's node identity set to match the cast table (A/B/C/D).
- Screen-record on all four phones simultaneously via Control Center → Screen Recording, or individually via QuickTime for highest quality.
- Record IRL on a separate camera with a clip-on lav mic on whoever is speaking. On-board phone mics will ruin the contrast between "exact" and "paraphrased" when we dialogue-tag both.

### During shooting
- Pre-seed Beat 2 with real data. Before rolling, have C and D send 4–5 believable field messages so Bravo has genuine context to query. **Do not fake the Gemma answer** — record it streaming in live.
- Shoot Beat 1 twice: once silent (for VO overlay), once with IRL audio (for the tagged dialogue). Mix in post.

### In post
- Animate the tech panels in After Effects, Motion, Keynote, or Figma. One template, swap edges between keyframes. Do not screen-grab these from the app — they need to read at 2-second pace.
- Burn in subtitles for every narrator line. Judges watch on muted laptops.
- One low pad throughout (optional) or silence. No music beats. One clean beep at the end.
- Export 1080 × 1920 (vertical) for social, 1920 × 1080 (16:9) for demo day. Shoot vertical and crop if unsure.

---

## Variants

### 40-second "minimum viable pitch"
If you need to fit a shorter slot: keep the problem statement, the solution statement, Beat 1, and the tagline. Drop Beat 2, the tech panels, and the offline close. Lands the *radio* half cleanly in ~40 seconds without the AI payoff.

### 90-second "full pitch"
If time opens up: re-add the original Beat 2b ("orders go out verbatim") between the current Beats 1 and 2, and restore the silent airplane-mode close as a dedicated 10-second beat.

---

*Storyboard v0 · MeshNode*
