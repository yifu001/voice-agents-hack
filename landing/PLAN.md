# TacNet — Landing Site Plan

> Comprehensive plan for the public landing site that explains TacNet's architecture, hosts the demo video, and runs an interactive BLE-mesh simulation — for hackathon judges, the Cactus/Gemma developer community, and defense-adjacent operators.

**Folder**: `/landing/` (this directory).
**Stack**: Next.js 15 App Router · React 19 · Tailwind CSS v4 · Three.js (ambient effects) · Framer Motion (optional) · MDX (docs).
**Hosting**: Vercel (assumption — flag if different).
**Domain**: TBD (see "Open decisions").

**Revision 2** — palette A (tactical lime) locked · DM Sans + JetBrains Mono locked · subtle YC footer framing locked · Next.js project will live in `landing/site/` (built manually, *not* via `create-next-app`).

---

## 1. Goal & non-goals

### Goal
A single-page site (with a couple of optional deeper routes) that:
1. Explains the **problem** (radio scaling wall) in one paragraph a civilian can absorb in 10 seconds.
2. Explains the **architecture** (BLE mesh + 2-layer comms + on-device compaction) as a visually dominant, *interactive* diagram.
3. Hosts the **cinematic demo video** (supplied separately).
4. Convinces **hackathon judges** that the technical novelty is real — Cactus, Gemma 4 E4B, BLE mesh, AES-256, auto-reparenting — with code snippets, data readouts, and honest latency numbers.
5. Convinces **operators** that the posture is serious — offline, resilient, zero-infra — with austere visuals and evidence over adjectives.
6. Uses **"Go deeper" accordions** so the scannable surface stays short while the depth is one click away.

### Non-goals
- **Not** a customer portal, auth, pricing page, or dashboard.
- **Not** a docs site (docs can live at `/docs` as a follow-on — plan ships without them).
- **Not** a web version of the iOS app. The demo is a *video + a simulation*, not the real client.
- **Not** a marketing site in the consumer-SaaS sense (no avatars, no testimonials, no "Trusted by" logos unless Cactus/Gemma/YC give permission).

### Success criteria (measurable)
- Time-to-understand: a technical reader understands the system in ≤ 90s of scrolling.
- Demo video is visible above the fold on the Architecture section without scrolling past hero.
- Interactive simulation runs at 60fps on a 2020 MacBook Air, and degrades gracefully to a static SVG when `prefers-reduced-motion` is set.
- Lighthouse: Performance ≥ 90, Accessibility ≥ 95, SEO ≥ 95.
- All body copy passes WCAG AA contrast (ruling out the "dark gray on black" trap).

---

## 2. Visual direction

### 2.1 Palette — **LOCKED: A · Tactical lime**

| Token | Value |
|---|---|
| `--bg` | `#0A0D0B` |
| `--surface` | `#111511` |
| `--elevated` | `#1A1F1A` |
| `--border` | `#1F251F` |
| `--border-hot` | `#2B3329` |
| `--text` | `#E8ECE9` |
| `--text-muted` | `#8A918C` |
| `--text-dim` | `#5A615C` |
| `--accent` | `#B8FF2C` |
| `--accent-soft` | `rgba(184,255,44,0.12)` |
| `--signal-amber` | `#FFB020` — "transmitting / live" state |
| `--signal-red` | `#FF4D3A` — alerts only, used sparingly |

Reads as defense-tech immediately without cloning any one reference site; pairs cleanly with amber as a second signal colour. Red is reserved for genuine alerts only (never decoration).

### 2.2 Typography — **LOCKED: DM Sans + JetBrains Mono**

- **Display / Body** — **DM Sans** (single family, weights 100–1000 via optical-size axis). Tight tracking `-0.025em` on display headlines, `-0.01em` on body. Fluid display size: `clamp(2.25rem, 6vw + 1rem, 6.5rem)`. Body never below 15px.
- **Mono** — **JetBrains Mono**, 400/500. Used exclusively for: callsigns, coordinates, timestamps, stats, code blocks, section numbers (`01 /`, `02 /`), and footer metadata. Never body copy.

**Why this pair over alternatives considered:**
- Shield AI ships DM Sans + IBM Plex Mono for real defense marketing — proven in-category.
- Anduril's Helvetica Now Display is paid-licence, ruled out.
- Space Grotesk would mirror aliaskit's stack too closely and dilute distinctiveness.
- JetBrains Mono has richer ligature/variant support than Plex and is already loved by the team.
- Single display family keeps the page disciplined; hierarchy comes from weight (300 → 700) not family-swapping.

### 2.3 Motifs

**AliasKit lifts — locked.** The team explicitly approved pulling heavily from `aliaskit.com`'s chrome. We adopt these patterns verbatim and only change their palette + copy:

- **Floating / contracting nav** — fixed top, inset 16px from edges, `backdrop-filter: blur(24px)`, width transitions from `min(1200px, 100% - 2rem)` to `min(760px, 100% - 2rem)` on 500ms cubic-bezier past 80px scroll. Identical mechanism to aliaskit's `Navigation.tsx`.
- **Inset page border** — a 1px `rgba(232,236,233,0.06)` frame around the whole `<main>` on desktop, with a `clamp(0, 2vw, 16px)` outer margin. This is the "margin design" you liked; it reads as a document dossier instead of a boundless web page. Implemented in `src/app/page.tsx`.
- **Vertical grid rails** — 1px lines at `rgba(232,236,233,0.06)` at the 1200-max-width gutters, hidden on mobile. Adds a literal "ruled paper" feel to the whole page without shouting.
- **Section corner dots** — 3px circles at top-left/top-right of every section at `rgba(232,236,233,0.2)`.
- **Dot + grid backgrounds** — `radial-gradient` dot field at 16px for surface sections; `linear-gradient` 48px grid at 3% opacity for hero/architecture. Both CSS only.
- **Stacked-depth code window** — 3 overlapping divs with `translate-x-3/y-2 → translate-x-1.5/y-1 → 0,0`, each with progressively darker borders, plus a top glow line `gradient-to-r from-transparent via-[#333] to-transparent`. Direct lift from aliaskit's `HeroSection.tsx`.
- **Custom syntax tokenizer** in code windows — strings green, keywords purple, numbers orange (OneDark-adjacent). Lifted wholesale from aliaskit.
- **Fade-in-up stagger** — `.landing-stagger-1/2/3` at 40/120/200ms delays; killed by `prefers-reduced-motion`. Lifted verbatim.
- **StatsBand** big-numeral + tiny-uppercase-label mono readouts — lifted wholesale, repalette'd.

**TacNet-native additions on top of the lifts:**
- **Numbered section rail** — "01 / MESH DISCOVERY", "02 / ROLE CLAIM", etc., in mono uppercase (Saronic lift, not aliaskit).
- **`[ BRACKETED ]` labels** on CTAs and section tags — tactical without being costume.
- **One pulsing dot** in the nav labelled `OPERATIONAL` — 2.5s ease. That's the only blinky thing on the page.
- **Grain PNG overlay** at 4% opacity on body. 256×256 tile (placeholder until we generate).
- **No literal military imagery.** No weapons, uniforms, flags, crosshairs, camo.

**Explicit non-lifts from aliaskit** (things we deliberately skip):
- The **Three.js Dither background** — aliaskit runs a shader across the full viewport. For TacNet the visual focus is the interactive mesh, so ambient noise steals attention. We use grain + grid only.
- The **ASCII text shader effect** — too playful for defense posture.
- The **indigo `#6366F1` accent** — replaced with tactical lime `#B8FF2C`.
- The **Space Grotesk + Outfit** type pair — replaced with DM Sans to avoid clone feel.

### 2.4 Motion
- Fade-in-up stagger (40/120/200ms delays) on section entry.
- Nav contracts on scroll (AliasKit pattern).
- Interactive BLE mesh simulation plays continuously (paused when off-screen).
- Everything is gated on `prefers-reduced-motion: reduce` → all transitions drop to opacity-only 0.2s.

---

## 3. Information architecture

Single page, top-to-bottom. Anchor routes: `#problem`, `#architecture`, `#how`, `#ai`, `#demo`, `#specs`, `#security`, `#faq`.

```
┌──────────────────────────────────────────────────────────────┐
│ 0.  NAV                       sticky, contracts on scroll    │
├──────────────────────────────────────────────────────────────┤
│ 1.  HERO                      headline · video bg · CTAs     │
│                               · pulsing OPERATIONAL dot      │
├──────────────────────────────────────────────────────────────┤
│ 2.  DATA READOUT BAND         4 mono stats, full width       │
├──────────────────────────────────────────────────────────────┤
│ 3.  THE PROBLEM               plain-english paragraph        │
│                               + go deeper accordion          │
├──────────────────────────────────────────────────────────────┤
│ 4.  ARCHITECTURE              interactive BLE mesh sim       │
│  (hero of the page)           · broadcast / compaction toggle│
│                               · click a node to inspect      │
│                               · go deeper accordions         │
├──────────────────────────────────────────────────────────────┤
│ 5.  HOW IT WORKS              Saronic-style numbered 01-07   │
├──────────────────────────────────────────────────────────────┤
│ 6.  THE AI                    Cactus + Gemma 4 E4B           │
│                               · prompt template shown        │
│                               · code snippet + latency       │
├──────────────────────────────────────────────────────────────┤
│ 7.  DEMO                      cinematic video embed          │
│                               · annotated screenshots of 4   │
│                                 iOS screens                  │
├──────────────────────────────────────────────────────────────┤
│ 8.  SPECS                     mono data block (protocol,     │
│                               model, latency, range, E2E)    │
├──────────────────────────────────────────────────────────────┤
│ 9.  SECURITY & RESILIENCE     E2E, auto-reparent, organiser  │
│                                 promotion, offline posture   │
├──────────────────────────────────────────────────────────────┤
│ 10. FAQ                       5–8 questions, accordion       │
├──────────────────────────────────────────────────────────────┤
│ 11. CTA                       [ READ THE SPEC → ]            │
│                               [ WATCH DEMO →    ]            │
├──────────────────────────────────────────────────────────────┤
│ 12. FOOTER                    dossier card · build version · │
│                                 commit hash · team · subtle  │
│                                 "Built at YC × Cactus ×      │
│                                 Gemma 4 hackathon" line      │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. Section-by-section specs

### 4.1 Nav (`components/Nav.tsx`)
- Fixed top, inset 16px from edges.
- Background `rgba(10,13,11,0.8)` + `backdrop-filter: blur(24px)`.
- Border 1px `#1F251F`.
- Left: wordmark `TacNet` in DM Sans 600, 18px. Adjacent: tiny pulsing dot + mono label `OPERATIONAL` in `--accent` at 11px.
- Center (desktop only): `[ ARCHITECTURE ]  [ DEMO ]  [ SPEC ]  [ FAQ ]` — mono uppercase 11px, tracking 0.08em.
- Right: `[ GITHUB ]` ghost button + `[ WATCH DEMO → ]` filled CTA.
- Mobile: hamburger → overlay with same links stacked.
- **Contracts on scroll**: width `min(1200px, 100% - 2rem)` → `min(760px, 100% - 2rem)` on 500ms cubic-bezier past 80px scroll.

### 4.2 Hero (`components/Hero.tsx`)
Layout: two-column on desktop (text left, visual right), stacked on mobile.

**Left column** (text):
```
[ OFFLINE-FIRST TACTICAL COMMS ]              ← bracketed tag, mono 11px

Voice. Mesh. Offline.                          ← H1, DM Sans 700
                                                  clamp(48px, 7vw, 112px)
                                                  letter-spacing -0.03em

Every phone runs Gemma 4 on-device and       ← subhead, DM Sans 400, 18–20px
compacts its children's transmissions as         max-width ~ 560px
summaries that climb the command tree.
Zero servers. Zero cloud. Full spec.

[ WATCH DEMO → ]   READ THE SPEC →            ← primary + text-link
```

**Right column** (visual):
- Device frame mock (single iPhone) with a loop of 4–5 key screens (Live Feed, Tree View, Data Flow, Map) auto-cycling every 3s.
- Behind it: a **muted looped snippet** of the cinematic video at 30% opacity.
- Overlaid: the 48px grid at 3% opacity.

**Hero variant for mobile**: text top, device mock bottom, video background moves to a full-bleed behind both with a dark overlay `rgba(10,13,11,0.75)`.

### 4.3 Data readout band (`components/DataBand.tsx`)
Horizontal strip below hero, on `--surface`, with 1px `--border` top and bottom. Four columns:

```
┌────────────────┬────────────────┬────────────────┬────────────────┐
│ 4              │ 0              │ < 2 s          │ 6.7 GB         │
│ PHONES IN      │ SERVERS        │ COMPACTION     │ MODEL WEIGHT   │
│ DEMO NETWORK   │ REQUIRED       │ LATENCY TARGET │ ON-DEVICE      │
└────────────────┴────────────────┴────────────────┴────────────────┘
```
- Numerals in JetBrains Mono 500, `clamp(32px, 4.5vw, 64px)`.
- Labels in JetBrains Mono 400 uppercase 10–11px, tracking 0.1em, `--text-muted`.
- Vertical dividers between columns (1px `--border`).

### 4.4 The problem (`#problem`)
One short paragraph, then two accordions.

**Surface copy**:
> A commander with 50 subordinates cannot listen to 50 radios at once. Traditional comms push that human problem onto the commander. **TacNet pushes it onto an on-device model in every phone.** Every node summarises its children upward. The commander hears one line, not fifty.

**Accordions**:
- `[+] Why existing radios hit this wall` — the scaling math, how platoons currently manually relay.
- `[+] How TacNet inverts the model` — diagram showing the two layers (broadcast horizontally, compaction vertically).

### 4.5 **Architecture** (`#architecture`) — the hero of the page

This is the section judges will screenshot. It has to do the most work.

**Layout**: Large interactive canvas (70% of viewport width on desktop), with a side panel (30%) showing the currently-inspected node's role, messages in its queue, and its compaction output.

**Canvas contents**: The 4-phone demo tree.
```
                      [0] Commander
                         /      \
                    [1] Alpha    [2] Bravo
                        |
                    [3] Alpha-1
```

Plus three extra ghost nodes (semi-transparent) at the L2 layer to hint at scale.

**Interaction**:
- **Toggle at top**: `[ BROADCAST LAYER ]  [ COMPACTION LAYER ]  [ BOTH ]`. Default: BOTH.
- **Click a node** → side panel populates with:
  - Role / position (`ALPHA LEAD`)
  - Latitude / longitude (fake coordinates in mono)
  - Messages in queue for compaction
  - Last emitted summary
- **Simulated message flow** (plays continuously, pauses when section scrolls out of view):
  - A leaf node pulses `--accent-soft`.
  - A `BROADCAST` dot travels along BLE edges to siblings + parent, fading at each hop.
  - After 3 broadcasts accumulate at a parent, the parent pulses `--signal-amber` (compacting), briefly shows a mock prompt in mono, then emits a `COMPACTION` dot upward.
  - At the root, a `SITREP` line appears in a ticker: `14:02:36 · SITREP: Alpha reports contact bldg 4.`

**Go-deeper accordions below the canvas**:
- `[+] BLE flooding with TTL + UUID dedup` — the 10-hop TTL, seen-set ring buffer, pseudo-code.
- `[+] Routing rules` — table from `Orchestrator.md` §8 (BROADCAST → siblings + parent; COMPACTION → parent only).
- `[+] Message envelope schema` — the full JSON envelope from spec §8.
- `[+] Auto-reparenting on parent disconnect` — the 60s timeout, nearest-ancestor traversal, `TREE_UPDATE` fan-out.
- `[+] Organiser promotion (PROMOTE)` — how command transfers mid-operation.
- `[+] Encryption + pre-shared key` — PIN-derived key exchange, AES-256.

### 4.6 How it works (`#how`) — numbered rail
Saronic-style. Seven steps, each in a card with:
- `01 /` mono number, huge, `--text-dim` (so it recedes).
- Tight headline (DM Sans 600, 22px).
- 2–3 lines of DM Sans body copy.
- One "evidence" line at the bottom in mono: code path, test name, or a metric.

```
01 / MESH DISCOVERY          — Phone advertises + scans on TacNet service UUID.
02 / ROLE CLAIM              — Participant taps a node; CLAIM floods; organiser wins conflicts.
03 / SPEAK (PTT)             — 16kHz mono PCM into AVAudioEngine.
04 / TRANSCRIBE ON-DEVICE    — Gemma 4 E4B audio conformer → text.
05 / COMPACT UPWARD          — Parent queues 3 transcripts, runs summariser, emits COMPACTION.
06 / TOP-LEVEL SITREP        — Root compacts all L1 summaries.
07 / PERSIST & AUDIT         — SwiftData + full-text search for after-action review.
```

Each step's evidence line:
```
01  →  Services/BluetoothMeshService.swift · tests: 24 passing
02  →  RoleClaimService.swift · conflict: organiser_wins
03  →  AudioService.swift · AVAudioEngine · 16kHz mono 16-bit PCM
04  →  cactusTranscribe(context, audioPath) · ~300M conformer
05  →  CompactionEngine.swift · trigger: msg_count >= 3
06  →  root prompt template · output cap 64 tokens
07  →  SwiftData · message history · full-text search
```

### 4.7 The AI (`#ai`)
Two columns.

**Left**: short copy.
> TacNet runs **Gemma 4 E4B** (4.5B params, ~2.8GB INT4) locally on every phone, via **Cactus**, a low-latency inference runtime for mobile/edge. One model handles both speech-to-text (native ~300M conformer) and summarisation. No Whisper, no Apple Speech, no cloud.

Below, a mono data block:
```
MODEL       gemma-4-e4b-it (INT4)
PARAMS      4.5 B effective · 8 B with embeddings
VRAM        ~ 2.8 GB
WEIGHTS     6.7 GB · downloaded on first launch
STT         native audio conformer (~ 300 M params)
SUMMARISE   cactusComplete · max 64 tokens
LATENCY     30 s audio ≈ 0.3 s · 40 tok/s decode
PLATFORM    Apple Silicon (iPhone 15 Pro / 16)
```

**Right**: the compaction prompt template, in a code window with stacked-depth styling (AliasKit lift):
```
SYSTEM: You are a tactical communications summarizer. Compress the
following radio messages from your subordinates into a brief, actionable
summary. Preserve: locations, threat counts, unit status, urgent items.
Remove: filler, repetition, acknowledgements. Keep under 30 words.

MESSAGES:
- [Alpha-1, 14:02:05]: We've spotted movement in sector 7, over
- [Alpha-2, 14:02:12]: Copy that, I can confirm, 4 individuals, armed
- [Alpha-3, 14:02:30]: Rear perimeter all clear, no movement, holding

SUMMARY:
> Squad Alpha: 4 armed contacts sector 7 (2× confirmed). Rear clear, holding.
```

Below: `[+] See the Swift integration` accordion with the `CompactionEngine` snippet from `Orchestrator.md` §12.

### 4.8 Demo (`#demo`)
Full-bleed section. Cinematic video plays inline at up to 1200px wide, 16:9 aspect, dark overlay at `rgba(10,13,11,0.35)` when paused. Below: 4 iOS screen mocks in a row (Live Feed, Tree, Data Flow, Map) with scroll-linked annotation callouts in mono.

Video controls: minimal. Custom play/pause in `--accent`. No progress bar until hover. Captions on by default.

### 4.9 Specs (`#specs`) — pure mono data block
Three-column grid:
```
PROTOCOL                     MODEL                       PHYSICAL
────────                     ─────                       ────────
Transport   BLE 5.0 mesh      Family    Gemma 4 E4B       Hops     10 (TTL)
Encryption  AES-256 E2E       Runtime   Cactus iOS SDK    Range    30–100 m / hop
Key        PIN-derived        Quant     INT4              iOS      16.0+
Envelope   JSON / Codable     Weights   6.7 GB            Hardware iPhone 15+ · 8 GB RAM
Message    UUID-deduped       STT       native conformer  Power    idle-BLE tolerant
TTL        Decrement per hop  Summarise cactusComplete    Audio    16 kHz mono 16-bit PCM
```

### 4.10 Security & resilience (`#security`)
Four small cards (grid 2×2 on desktop, stacked on mobile):
1. **End-to-end encryption** — PIN-derived session key on join; AES-256 on every hop.
2. **Auto-reparenting** — 60s parent disconnect → children walk up the tree to the nearest ancestor.
3. **Organiser promotion** — command can transfer to any claimed node via `PROMOTE`; continuity survives commander loss.
4. **Fully offline** — no internet, no GPS-dependent routing, no backend. The network is the phones in the room.

### 4.11 FAQ
Accordion of 5–8 questions, copy drafted in §9.

### 4.12 CTA
Centered, large:
```
Ready to see it run?

[ WATCH DEMO → ]    [ READ THE SPEC → ]
```

### 4.13 Footer — dossier card
Two columns:
- Left: wordmark + short tagline + team names.
- Right: mono metadata block.
```
BUILD      v0.1.0-hackathon
COMMIT     <gitsha>
UPDATED    <build timestamp>
LICENSE    MIT
REPO       github.com/Nalin-Atmakur/YC-hack
CONTACT    hello@tacnet.example
```
Below: an ASCII rendering of the mesh tree. Small, at `--text-dim`.

Bottom strip (centered, 11px mono, `--text-dim`):
```
Built at the YC × Cactus × Gemma 4 hackathon · 2025
```
Links "Cactus" and "Gemma 4" to their respective product pages. Nothing else at the bottom.

---

## 5. Interactive BLE mesh simulation — detailed spec

File: `components/MeshSimulation.tsx` + `lib/mesh/*`.

### 5.1 Data model
```ts
type NodeId = string;
type Role = 'commander' | 'l1' | 'l2';

interface MeshNode {
  id: NodeId;
  label: string;        // 'Commander', 'Alpha Lead', 'Alpha-1'
  role: Role;
  parent: NodeId | null;
  position: { x: number; y: number };
  queue: Broadcast[];
  lastSummary?: string;
  state: 'idle' | 'transmitting' | 'compacting';
}

interface Edge { from: NodeId; to: NodeId; }

type MessageType = 'BROADCAST' | 'COMPACTION';
interface Packet {
  id: string;
  type: MessageType;
  origin: NodeId;
  currentNode: NodeId;
  path: NodeId[];
  transcript?: string;
  summary?: string;
  progress: number;     // 0..1 along currentEdge
}
```

### 5.2 Render target
SVG (not Canvas) — smaller, crisper, keyboard-focusable nodes for a11y, exportable to static at SSR fallback.

Layer order:
1. `<defs>` — gradients, glyph symbols for node types.
2. Edges — 1px `--border`, active edges switch to `--accent` briefly during packet traversal.
3. Node cells — rounded rect 2px radius, `--surface` fill, 1px `--border`.
4. Packets — small filled circle travelling along edges.
5. Labels — mono 11px under each node.

### 5.3 Simulation loop
~20 FPS using `requestAnimationFrame` (skip frames aggressively on `prefers-reduced-motion`).
Every 6 seconds:
- Pick a random leaf.
- It transmits a scripted transcript (3 pre-written vignettes cycle).
- Packets animate along BLE edges to its siblings and parent (0.8s per hop).
- Receiving nodes show the transcript in their inspector if selected.
- When a parent's queue hits 3 items, it pulses `--signal-amber`, shows the mock prompt in the side panel, waits 0.35s (simulating compaction), and emits a `COMPACTION` packet up.
- At the root, the summary lands in a ticker log.

### 5.4 Accessibility
- Each node is `role="button"` with `aria-label="Alpha-1 · L2 leaf node · click to inspect"`.
- Keyboard: `Tab` cycles nodes, `Enter` inspects, `Esc` closes side panel.
- Live region on the ticker log (`role="log" aria-live="polite"`).
- `prefers-reduced-motion`: no packets animate — state transitions happen instantly; user can still click through to see the inspector.

### 5.5 Content — vignettes
Three scripted scenarios cycle:

**A — Contact.**
- Alpha-1: "Movement sector 7, three o'clock."
- Alpha (sibling): "Confirmed, four individuals, armed."
- (compact) → "Squad Alpha: 4 armed contacts sector 7 (2× confirmed)."

**B — Casualty.**
- Bravo-2: "Man down, need medic grid 482."
- Bravo (sibling): "Moving to 482, ETA 90 seconds."
- (compact) → "Bravo: casualty at grid 482, medic inbound 90s."

**C — Clear.**
- Alpha-1: "North perimeter, no contact."
- Alpha-2: "South perimeter, no contact."
- Alpha-3: "Rear secure, holding."
- (compact) → "Squad Alpha: perimeter clear, holding position."

---

## 6. Video integration plan

- The user is producing a cinematic military video separately.
- We accept two formats: `MP4 (H.264 AAC)` + `WebM (VP9)` — both with captions sidecar (`.vtt`).
- Stored in `/public/video/demo-hero.{mp4,webm}` and `/public/video/demo-hero.en.vtt`.
- **Three uses on the page**:
  1. **Hero background** — short 6–10s loop, muted, autoplay, `poster=...jpg`, `playsinline`, 30% opacity.
  2. **Demo section** — full video (30–90s), inline player, captions on by default.
  3. **Open Graph preview image** — a single frame exported as 1200×630 PNG.
- Preloading: `preload="metadata"` for hero, `preload="none"` for demo. `loading="lazy"` where supported on poster images.
- Respect `prefers-reduced-motion` → hero swaps to a static poster; demo gains a big manual play button with no autoplay.

---

## 7. Component inventory

```
components/
├── Nav.tsx                  sticky nav, contracts on scroll
├── Hero.tsx                 headline + device mock + video bg
├── DataBand.tsx             4-col mono stat strip
├── Problem.tsx              paragraph + 2 accordions
├── MeshSimulation.tsx       SVG mesh + side panel + ticker
├── MeshInspector.tsx        side panel for selected node
├── HowItWorks.tsx           numbered 01–07 rail
├── AI.tsx                   prompt template + code window
├── Demo.tsx                 video player + screen mocks
├── Specs.tsx                mono 3-col data block
├── Security.tsx             2×2 cards
├── FAQ.tsx                  accordion list
├── CTA.tsx                  dual CTA block
├── Footer.tsx               dossier card + ASCII tree + YC line
│
├── primitives/
│   ├── SectionFrame.tsx     corner dots + horizontal rule
│   ├── CodeWindow.tsx       stacked-depth code block
│   ├── Accordion.tsx        go-deeper blocks
│   ├── MonoStat.tsx         big numeral + tiny label
│   ├── BracketedButton.tsx  [ LABEL → ] CTA
│   ├── PulsingDot.tsx       status indicator
│   └── GridBackground.tsx   48px grid @ 3% opacity
│
└── effects/
    ├── NoiseOverlay.tsx     4% grain PNG tile
    └── InsetBorder.tsx      page-wrapping frame on desktop
```

Hooks/libs:
```
lib/
├── mesh/
│   ├── simulation.ts        requestAnimationFrame loop
│   ├── scenarios.ts         3 vignettes
│   └── layout.ts            tree → xy positions
├── motion.ts                prefers-reduced-motion helper
└── tokens.ts                re-export of CSS var names for TS consumption
```

---

## 8. Project scaffolding — manual, not `create-next-app`

> **Lesson logged.** A prior attempt used `npx create-next-app@latest` and the install failed mid-extract when disk headroom fell below its working threshold. `create-next-app`'s abort handler then removed the entire target-adjacent working tree, which in our case included committed TacNet source that had to be recovered via `git restore`. We do not use `create-next-app` again. We scaffold manually — fewer files, fewer moving parts, and if `npm install` fails partway, only `node_modules/` is affected.

### 8.1 Pre-flight checks before any `npm install`
```bash
# 1. Free disk ≥ 5 GB
df -h /
# 2. Node ≥ 18.17 (Next 15 requirement)
node --version
# 3. Optional: clean npm cache to reclaim space
npm cache verify
```
Abort scaffolding if disk free is under 5 GB. Clean caches or ask the user before proceeding.

### 8.2 Manual scaffold sequence
From `landing/site/` (create the directory first; do not let `create-next-app` create it):
```bash
mkdir -p landing/site && cd landing/site

# Minimal package.json written by hand:
#   { "name": "tacnet-site", "version": "0.1.0", "private": true,
#     "scripts": { "dev": "next dev", "build": "next build", "start": "next start", "lint": "next lint" },
#     "dependencies": { "next": "^15", "react": "^19", "react-dom": "^19" },
#     "devDependencies": { "typescript": "^5", "@types/node": "^20",
#       "@types/react": "^19", "@types/react-dom": "^19",
#       "tailwindcss": "^4", "@tailwindcss/postcss": "^4", "postcss": "^8" } }

npm install
# Then add fonts + three.js once the base builds:
npm install three @react-three/fiber
npm install -D @types/three
```

### 8.3 File structure (final)

Planning docs and the built site stay separate. `landing/` holds meta; `landing/site/` is the Next.js project.

```
landing/
├── PLAN.md                       ← this document
├── README.md                     folder orientation
├── research/
│   ├── 01-aliaskit-extract.md
│   └── 02-defense-tech-extract.md
└── site/                         ← Next.js 15 project root (manual scaffold)
    ├── src/
    │   ├── app/
    │   │   ├── layout.tsx        root layout, fonts, grain overlay
    │   │   ├── page.tsx          single-page composition
    │   │   ├── globals.css       tokens, keyframes, utilities
    │   │   ├── opengraph-image.tsx  dynamic OG image
    │   │   └── icon.tsx          favicon generator
    │   ├── components/           (see §7)
    │   ├── lib/                  (see §7)
    │   └── content/
    │       ├── copy.ts           all strings, single source
    │       ├── faq.ts
    │       └── specs.ts
    ├── public/
    │   ├── video/
    │   │   ├── demo-hero.mp4
    │   │   ├── demo-hero.webm
    │   │   ├── demo-hero.en.vtt
    │   │   └── demo-hero-poster.jpg
    │   ├── screens/              4 iOS screen PNGs
    │   ├── grain.png             256×256 noise tile
    │   └── og.png                1200×630 share image
    ├── next.config.ts
    ├── tsconfig.json
    ├── package.json
    └── README.md                 how to run
```

### 8.4 `globals.css` skeleton (Palette A — Tactical lime + DM Sans / JetBrains Mono)
```css
@import "tailwindcss";

@theme {
  --color-bg:           #0A0D0B;
  --color-surface:      #111511;
  --color-elevated:     #1A1F1A;
  --color-border:       #1F251F;
  --color-border-hot:   #2B3329;
  --color-text:         #E8ECE9;
  --color-text-muted:   #8A918C;
  --color-text-dim:     #5A615C;
  --color-accent:       #B8FF2C;
  --color-accent-soft:  rgba(184,255,44,0.12);
  --color-signal-amber: #FFB020;
  --color-signal-red:   #FF4D3A;
  --font-sans:          var(--font-dm-sans),      ui-sans-serif;
  --font-mono:          var(--font-jetbrains-mono), ui-monospace;
  --radius-panel:       2px;
  --radius-btn:         2px;
}

/* Grid overlay utility */
.bg-grid-48 {
  background-image:
    linear-gradient(to right,  rgba(232,236,233,0.03) 1px, transparent 1px),
    linear-gradient(to bottom, rgba(232,236,233,0.03) 1px, transparent 1px);
  background-size: 48px 48px;
}

/* Noise */
.bg-noise { background-image: url('/grain.png'); background-size: 256px; opacity: .04; }

/* Respect prefers-reduced-motion */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}

/* Pulsing dot */
@keyframes pulse-op { 0%,100% { opacity: 1 } 50% { opacity: .35 } }
```

### 8.5 `layout.tsx` font setup
```tsx
import { DM_Sans, JetBrains_Mono } from 'next/font/google';

const dmSans = DM_Sans({
  subsets: ['latin'],
  variable: '--font-dm-sans',
  display: 'swap',
});

const jetBrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-jetbrains-mono',
  display: 'swap',
});

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${dmSans.variable} ${jetBrainsMono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
```

---

## 9. Copy drafts

### 9.1 Voice rules
- Noun-first, imperative, short sentences.
- No adjectives where a readout would do. "2.8 GB on-device" beats "incredibly compact".
- No trademarked tough-guy phrasing ("warfighter", "Tier 1", "kill chain").
- Every technical claim has a piece of evidence adjacent — a code path, a readout, a test count.
- Accessibility note: the page must make sense if every accordion stays closed.

### 9.2 Hero
```
H1:     Voice. Mesh. Offline.
Sub:    Every phone runs Gemma 4 on-device and compacts its
        children's transmissions as summaries that climb the
        command tree. Zero servers. Zero cloud. Full spec.
Tag:    [ OFFLINE-FIRST TACTICAL COMMS ]
CTAs:   [ WATCH DEMO → ]   READ THE SPEC →
```

### 9.3 Problem
```
A commander with 50 subordinates cannot listen to 50 radios at once.
Traditional comms push that human problem onto the commander.
TacNet pushes it onto an on-device model in every phone.
Every node summarises its children upward. The commander hears
one line, not fifty.
```

### 9.4 Architecture intro
```
Two layers, one mesh.

— Broadcast: a leaf's transcript reaches only its siblings and parent.
— Compaction: a parent's Gemma 4 summarises those transcripts
  and emits one line upward.

The mesh is fully decentralised. Every phone is both client and
relay. Messages flood with TTL; the app layer filters by role.
```

### 9.5 FAQ (initial set — refine with team)
1. **Why not just use radios?** — Radios scale with human attention. TacNet scales with model context. Both co-exist: TacNet is the summariser layer.
2. **Why on-device AI?** — Because the cloud isn't there. Gemma 4 E4B runs entirely on iPhone 15+ with no internet.
3. **Why BLE and not LoRa / mesh Wi-Fi?** — BLE is ubiquitous, low-power, and already on every phone. Range per hop is 30–100m; we rely on hopping.
4. **What happens if the commander's phone dies?** — Any claimed node can be promoted to organiser via `PROMOTE`. Children auto-reparent on a 60s parent disconnect.
5. **How private is this?** — All messages are AES-256 end-to-end with a PIN-derived session key. Audio never leaves the device.
6. **Is this a real product?** — TacNet is a hackathon project built for the Cactus × Gemma 4 YC event. The architecture, protocol, and code are real; the brand is not a shipping product.
7. **Where's the code?** — GitHub link in the footer. See `Orchestrator.md` for the full spec and `DECISIONS.md` for the 21 design decisions that shaped it.

---

## 10. Implementation phases

Sized for small team. Phases are sequential; each ends with a deployable checkpoint.

### Phase 0 — Plan approval *(this document)* — **DONE (rev 2)**
- [x] Palette locked (A · tactical lime).
- [x] Typography locked (DM Sans + JetBrains Mono).
- [x] YC framing locked (subtle footer line).
- [ ] Cinematic video — separate track, owner = user.

### Phase 1 — Manual scaffold & tokens — **DONE**
- [x] Pre-flight disk check (26 GB free confirmed).
- [x] Hand-written `package.json`, `tsconfig.json`, `next.config.ts` (with `outputFileTracingRoot`), `postcss.config.mjs`, `.gitignore`, `next-env.d.ts`, `README.md`.
- [x] `npm install` — 47 packages, clean.
- [x] DM Sans + JetBrains Mono wired via `next/font/google` in `src/app/layout.tsx`.
- [x] `src/app/globals.css` with Palette A tokens + grid overlay + noise + pulse + fade-in-up + reduced-motion utilities.
- [x] `src/app/layout.tsx` with grain overlay pinned full-viewport.
- [x] `src/app/page.tsx` with inset border, 48px grid, OPERATIONAL pulsing dot, wordmark, H1, subhead, 8-swatch token probe, 4-stat data band, CTA stubs, YC footer line.
- [x] `npm run build` — green, 102 KB first-load JS, 4/4 static pages.
- [ ] Vercel preview URL — deferred (needs user auth).

### Phase 2 — Shell components — **DONE**
- [x] `Nav` with floating/contracting chrome (aliaskit lift). Mobile hamburger overlay.
- [x] `SectionFrame`, `Accordion` + `AccordionGroup`, `CodeWindow` with stacked-depth + `Token` tokenizer, `MonoStat`, `BracketedButton` (primary/ghost/link), `PulsingDot`, `GridBackground`.
- [x] `lib/motion.ts` with `useReducedMotion` hook.
- [x] `tsconfig.json` path alias `@/*` so content imports stay clean.

### Phase 3 — Content sections — **DONE**
- [x] `content/copy.ts` + `content/faq.ts` as single source of truth.
- [x] `Hero` with left-right two-column layout, device mock cycling 4 screens, primary + secondary CTAs, pulsing OPERATIONAL dot, bracketed tag.
- [x] `DataBand` — 4 mono stats (phones · servers · latency · weight).
- [x] `Problem` — surface paragraph + 2 go-deeper accordions.
- [x] `HowItWorks` — 7 numbered steps with evidence lines.
- [x] `AI` — spec table + compaction prompt in stacked CodeWindow + 3 go-deeper accordions (Swift integration, one-model justification, latency math).
- [x] `Specs` — 3-column mono data block (Protocol · Model · Physical).
- [x] `Security` — 2×2 resilience cards.
- [x] `FAQ` — 7 accordions.
- [x] `CTA` — dual bracketed buttons.
- [x] `Footer` — dossier card + ASCII tree + YC line with live links.

### Phase 4 — Mesh simulation — **DONE**
- [x] `lib/mesh/types.ts` — NodeId, MeshNode, MeshEdge, Packet, Vignette.
- [x] `lib/mesh/layout.ts` — 9 nodes (1 commander + 2 L1 + 6 L2) with viewBox coords, parent/child, callsign, lat/lon.
- [x] `lib/mesh/scenarios.ts` — 3 vignettes (Contact, Clear, Casualty) cycling every 6.4s.
- [x] `MeshSimulation.tsx` — SVG canvas with BROADCAST/COMPACTION/BOTH toggle, scripted transcripts fan out to siblings+parent, amber-pulse on compaction, ticker log (aria-live polite), selected-node pulse ring, keyboard-focusable nodes.
- [x] `MeshInspector` (same file) — callsign header, role label, LAT/LON readout, parent/siblings/children lists, live compaction queue, last emitted summary.
- [x] `Architecture.tsx` — wraps the sim + 6 go-deeper accordions (TTL flooding, routing rules table, envelope JSON, auto-reparenting, PROMOTE, encryption).
- [x] Reduced-motion gate — packet animation skips to end state.

### Phase 5 — Demo + OG + favicon — **DONE**
- [x] `Demo.tsx` — aspect-video placeholder that gracefully converts to real `<video>` once `/public/video/demo-hero.{mp4,webm}` + `.en.vtt` + poster are dropped in. Commented block shows the wiring.
- [x] 4-screen carousel below the video — tabs on left, active annotation inline, iPhone frame with selected `IOSScreen` on right.
- [x] `src/app/opengraph-image.tsx` — dynamic 1200×630 OG image with inset frame, 48px grid, pulsing dot, hero copy, YC line.
- [x] `src/app/icon.tsx` — lime-bordered favicon with 3-node mesh motif.
- [x] `IOSScreen.tsx` — pure SVG renderings of Live Feed, Tree View, Data Flow, Map screens. No image assets required.
- [x] `DeviceMock.tsx` — iPhone-shaped frame with auto-cycling screens + indicator dots.

### Phase 6 — Polish — **DONE**
- [x] SVG `feTurbulence` grain overlay — no external PNG needed.
- [x] `scroll-margin-top: 96px` on all `section[id]` so anchor jumps clear the fixed nav.
- [x] All nodes in the sim are keyboard-focusable with `aria-label`.
- [x] Ticker log wrapped in `role="log" aria-live="polite"`.
- [x] `prefers-reduced-motion` honoured globally and in the sim packet animation specifically.
- [x] OG + icon routes set correct runtime + content-type.

### Phase 7 — Launch
- [ ] Domain cutover (still open — see §11).
- [ ] Vercel deploy (needs user auth).
- [ ] Analytics (Vercel Analytics when live).
- [ ] Sanity-check on real iPhone Safari, Chrome Android, desktop Safari/Firefox/Chrome.
- [ ] Drop real cinematic video into `/public/video/`, uncomment the `<video>` block in `Demo.tsx`.

**Estimated total: ~4 working days for one dev. Faster with two (sim + copy tracks parallel).**

---

## 11. Open decisions

### Locked
| # | Decision | Choice |
|---|---|---|
| 1 | **Palette** | **A · Tactical lime** — `--accent: #B8FF2C`, amber `#FFB020` signal, red `#FF4D3A` alert |
| 2 | **Typography** | **DM Sans + JetBrains Mono** |
| 3 | **YC hackathon framing** | **Subtle footer line** + link to Cactus + Gemma 4 product pages |
| 4 | **Scaffold method** | **Manual**, not `create-next-app` (per Phase 1 lesson) |

### Still open
| # | Decision | Options | Recommendation |
|---|---|---|---|
| 5 | **Domain** | `tacnet.com` · `tacnet.app` · subdomain of existing · none (Vercel URL only) | Whatever's available; this doesn't block Phase 1 |
| 6 | **Team / credits page** | `/team` route · inline footer block · absent | Inline footer block |
| 7 | **Docs** | Host at `/docs` now · link to GitHub README · defer | Link to GitHub for now; defer `/docs` |
| 8 | **Analytics** | Vercel Analytics · Plausible · none | Vercel Analytics — no cookie banner overhead |
| 9 | **OG share image** | Auto-generated from hero frame · custom-designed | Auto-generated via Next.js `opengraph-image.tsx` |
| 10 | **Legal** | `/privacy` + `/terms` now · defer | Defer — no data collection, no auth → low urgency |
| 11 | **Newsletter / waitlist** | Add · skip | Skip unless there's a clear "what's next" |
| 12 | **Interactive mesh scope** | 3 vignettes (spec'd) · 1 vignette · interactive sandbox | 3 vignettes cycling |

---

## 12. Appendix — TacNet material inventory (what we can cite / embed)

From the TacNet repo, usable assets for the landing page:

| Source | Use on landing |
|---|---|
| `Orchestrator.md` §2 system diagram | Architecture hero diagram |
| `Orchestrator.md` §7 message flow | Script for mesh simulation |
| `Orchestrator.md` §8 envelope schema | "Message envelope" accordion |
| `Orchestrator.md` §9 tree + claim flow | "How it works" numbered rail |
| `Orchestrator.md` §11 compaction prompt | The AI section prompt display |
| `Orchestrator.md` §12 CompactionEngine Swift | "See the Swift integration" accordion |
| `Orchestrator.md` §14 demo scenario | Demo section script |
| `DECISIONS.md` (21 decisions) | FAQ source material + "depth" accordions |
| `LINEAR_ISSUES.md` | "Built" evidence — test counts, milestone completion |
| `MANUAL_TESTING.md` | 53 assertions → credibility badge in footer |
| `TacNet/Services/BluetoothMeshService.swift` | Code snippet for BLE section |
| `TacNet/Services/Cactus.swift` | Code snippet for AI section |

---

## 13. Out of scope for v1

Deliberately excluded:
- Auth, user accounts, dashboards.
- Multi-page docs (link to GitHub instead).
- Newsletter / CRM integration.
- Internationalisation (English-only v1).
- Light mode.
- Server-side rendering for the mesh simulation (it's client-side and that's fine).
- Real BLE interop via Web Bluetooth (the sim is scripted, not driven by a real device).

These can be added in later phases without refactor — component structure is designed to accept them.

---

*Plan revision 2 · palette/fonts/framing locked · scaffold method revised after create-next-app incident. Domain and video timing are the only remaining Phase 1 blockers.*
