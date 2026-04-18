/**
 * Single source of truth for all page copy.
 * Edit here; components render what's here.
 */

export const hero = {
  tag: '[ Offline-First Tactical Comms ]',
  title: 'Voice. Mesh. Offline.',
  subhead:
    "Every phone runs Gemma 4 on-device and compacts its children's transmissions as summaries that climb the command tree. Zero servers. Zero cloud. Full spec.",
  primaryCta: 'Watch Demo →',
  secondaryCta: 'Read the Spec →',
};

export const dataBand = [
  { big: '4',      small: 'Phones in demo network' },
  { big: '0',      small: 'Servers required' },
  { big: '< 2 s',  small: 'Compaction latency target' },
  { big: '6.7 GB', small: 'Model weight on-device' },
];

export const problem = {
  eyebrow: '03 / THE PROBLEM',
  title: 'One commander cannot listen to fifty radios.',
  body: [
    'Traditional comms push that human problem onto the commander: more subordinates, more channels, more fatigue. Summarisation falls to whoever happens to be least busy, and detail is lost.',
    'TacNet pushes the problem onto an on-device model in every phone. Every node summarises its children upward. The commander hears one line, not fifty.',
  ],
};

export const architecture = {
  eyebrow: '04 / ARCHITECTURE',
  title: 'Two layers, one mesh.',
  intro:
    "Broadcast is the radio replacement: a leaf's transcript reaches only its siblings and parent. Compaction climbs: a parent's Gemma 4 summarises those transcripts and emits one line upward. The mesh is fully decentralised — every phone is both client and relay. Messages flood with TTL; the app layer filters by role.",
};

export const howItWorks = {
  eyebrow: '05 / HOW IT WORKS',
  title: 'Seven steps, every one on-device.',
  steps: [
    {
      n: '01',
      title: 'Mesh Discovery',
      body: 'Phones advertise and scan on the TacNet service UUID; peers link over BLE 5.0 with no external infrastructure.',
      evidence: 'Services/BluetoothMeshService.swift · 24 tests passing',
    },
    {
      n: '02',
      title: 'Role Claim',
      body: 'Participants tap a node in the published tree; CLAIM floods; the organiser wins races. Release after 60s disconnect.',
      evidence: 'RoleClaimService.swift · conflict: organiser_wins',
    },
    {
      n: '03',
      title: 'Speak (PTT)',
      body: 'Push-to-talk records 16 kHz mono 16-bit PCM through AVAudioEngine. Audio stays local; only text crosses the mesh.',
      evidence: 'AudioService.swift · AVAudioEngine · PCM 16 kHz',
    },
    {
      n: '04',
      title: 'Transcribe On-Device',
      body: "Gemma 4 E4B's native ~300M param audio conformer produces a transcript with no Whisper or Apple Speech in the loop.",
      evidence: 'cactusTranscribe(context, audioPath) · ~300M conformer',
    },
    {
      n: '05',
      title: 'Compact Upward',
      body: 'A parent queues three transcripts, runs the summariser prompt, and emits one COMPACTION upward.',
      evidence: 'CompactionEngine.swift · trigger: msg_count ≥ 3',
    },
    {
      n: '06',
      title: 'Top-Level SITREP',
      body: "The root compacts all L1 summaries into a single situation report. The commander sees one line per branch.",
      evidence: 'root prompt template · output cap 64 tokens',
    },
    {
      n: '07',
      title: 'Persist & Audit',
      body: 'Every message persists to SwiftData with full-text search so the network state is reviewable after-action.',
      evidence: 'SwiftData · history · full-text search',
    },
  ],
};

export const ai = {
  eyebrow: '06 / THE AI',
  title: 'Cactus + Gemma 4 E4B. On every phone.',
  intro:
    'TacNet runs Gemma 4 E4B (4.5B params, ~2.8 GB INT4) locally on every phone via Cactus, a low-latency inference runtime for mobile and edge. One model handles speech-to-text (native ~300M audio conformer) and summarisation. No Whisper, no Apple Speech, no cloud.',
  specs: [
    ['MODEL',     'gemma-4-e4b-it (INT4)'],
    ['PARAMS',    '4.5 B effective · 8 B with embeddings'],
    ['VRAM',      '~ 2.8 GB'],
    ['WEIGHTS',   '6.7 GB · downloaded on first launch'],
    ['STT',       'native audio conformer (~ 300 M params)'],
    ['SUMMARISE', 'cactusComplete · max 64 tokens'],
    ['LATENCY',   '30 s audio ≈ 0.3 s · 40 tok/s decode'],
    ['PLATFORM',  'Apple Silicon (iPhone 15 Pro / 16)'],
  ] as [string, string][],
  promptTitle: 'compaction prompt · gemma-4-e4b-it',
  promptBody: `SYSTEM: You are a tactical communications summarizer. Compress the
following radio messages from your subordinates into a brief, actionable
summary. Preserve: locations, threat counts, unit status, urgent items.
Remove: filler, repetition, acknowledgements. Keep under 30 words.

MESSAGES:
- [Alpha-1, 14:02:05]: We've spotted movement in sector 7, over
- [Alpha-2, 14:02:12]: Copy that, I can confirm, 4 individuals, armed
- [Alpha-3, 14:02:30]: Rear perimeter all clear, no movement, holding

SUMMARY:
> Squad Alpha: 4 armed contacts sector 7 (2× confirmed). Rear clear, holding.`,
};

export const demo = {
  eyebrow: '07 / DEMO',
  title: 'Four phones, two minutes, zero internet.',
  body: 'A cinematic walkthrough of a TacNet network under contact — push-to-talk at a leaf, compaction at squad level, a one-line SITREP at the commander. Captions on by default.',
};

export const specs = {
  eyebrow: '08 / SPEC',
  title: 'The readout.',
  columns: [
    {
      title: 'Protocol',
      rows: [
        ['Transport',  'BLE 5.0 mesh'],
        ['Encryption', 'AES-256 E2E'],
        ['Key',        'PIN-derived'],
        ['Envelope',   'JSON / Codable'],
        ['Message',    'UUID-deduped'],
        ['TTL',        'Decrement per hop'],
      ] as [string, string][],
    },
    {
      title: 'Model',
      rows: [
        ['Family',    'Gemma 4 E4B'],
        ['Runtime',   'Cactus iOS SDK'],
        ['Quant',     'INT4'],
        ['Weights',   '6.7 GB'],
        ['STT',       'native conformer'],
        ['Summarise', 'cactusComplete'],
      ] as [string, string][],
    },
    {
      title: 'Physical',
      rows: [
        ['Hops',     '10 (TTL)'],
        ['Range',    '30–100 m / hop'],
        ['iOS',      '16.0+'],
        ['Hardware', 'iPhone 15+ · 8 GB RAM'],
        ['Power',    'idle-BLE tolerant'],
        ['Audio',    '16 kHz mono PCM'],
      ] as [string, string][],
    },
  ],
};

export const security = {
  eyebrow: '09 / SECURITY & RESILIENCE',
  title: 'The network is the phones in the room.',
  cards: [
    {
      title: 'End-to-End Encryption',
      body: 'A PIN-derived session key establishes on network join. All messages use AES-256 on every hop; the mesh can route ciphertext it cannot read.',
    },
    {
      title: 'Auto-Reparenting',
      body: 'A parent gone 60 seconds triggers children to walk up the tree to the nearest connected ancestor. Routing rules update across the mesh via TREE_UPDATE.',
    },
    {
      title: 'Organiser Promotion',
      body: "If the commander's phone dies, any claimed node can inherit command via PROMOTE. created_by updates; the old organiser becomes a participant.",
    },
    {
      title: 'Fully Offline',
      body: 'No internet, no GPS-dependent routing, no backend. The entire AI stack — STT, summarisation — runs on-device. If the grid goes dark, the network stays up.',
    },
  ],
};

export const cta = {
  title: 'Ready to see it run?',
  primary: 'Watch Demo →',
  secondary: 'Read the Spec →',
};

export const footer = {
  tagline: 'Tactical comms for environments without infrastructure.',
  dossier: [
    ['BUILD',   'v0.1.0-hackathon'],
    ['LICENSE', 'MIT'],
    ['REPO',    'github.com/Nalin-Atmakur/YC-hack'],
    ['IOS',     '16.0+'],
    ['MODEL',   'gemma-4-e4b-it · INT4'],
    ['RUNTIME', 'Cactus iOS SDK'],
  ] as [string, string][],
  event:
    'Built at the YC × Cactus × Gemma 4 hackathon · 2025',
};
