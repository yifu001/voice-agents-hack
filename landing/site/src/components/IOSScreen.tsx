export type ScreenKind = 'live' | 'tree' | 'flow' | 'map';

interface IOSScreenProps {
  kind: ScreenKind;
}

/**
 * SVG renderings of the four TacNet iOS screens (Live Feed, Tree View,
 * Data Flow, Map). Pure SVG — crisp at any zoom, no image assets.
 */
export function IOSScreen({ kind }: IOSScreenProps) {
  return (
    <svg
      viewBox="0 0 260 560"
      xmlns="http://www.w3.org/2000/svg"
      className="h-full w-full"
      role="img"
      aria-label={LABELS[kind]}
    >
      <defs>
        <clipPath id="ios-clip">
          <rect x="0" y="0" width="260" height="560" rx="26" />
        </clipPath>
      </defs>
      <g clipPath="url(#ios-clip)">
        <rect x="0" y="0" width="260" height="560" fill="#0A0D0B" />
        {/* Status bar */}
        <text
          x="16"
          y="30"
          fill="#E8ECE9"
          fontSize="11"
          fontFamily="var(--font-mono)"
          letterSpacing="0.06em"
        >
          14:02
        </text>
        <g transform="translate(210,20)">
          <circle cx="4" cy="10" r="2" fill="#B8FF2C" />
          <text
            x="12"
            y="14"
            fill="#8A918C"
            fontSize="10"
            fontFamily="var(--font-mono)"
          >
            MESH
          </text>
        </g>

        {kind === 'live' && <LiveScreen />}
        {kind === 'tree' && <TreeScreen />}
        {kind === 'flow' && <FlowScreen />}
        {kind === 'map'  && <MapScreen />}
      </g>
    </svg>
  );
}

const LABELS: Record<ScreenKind, string> = {
  live: 'TacNet live feed — broadcast and compaction messages',
  tree: 'TacNet tree view — command hierarchy with claim status',
  flow: 'TacNet data flow — incoming, processing, outgoing',
  map:  'TacNet map view — node positions from embedded GPS',
};

// ── Live Feed ─────────────────────────────────────────────────────────
function LiveScreen() {
  return (
    <g>
      <text
        x="16"
        y="70"
        fill="#8A918C"
        fontSize="10"
        fontFamily="var(--font-mono)"
        letterSpacing="0.14em"
      >
        [ ALPHA LEAD · LIVE FEED ]
      </text>

      {/* Messages */}
      {[
        { t: '14:02:05', who: 'Alpha-1', msg: 'Movement sector 7, three o\'clock.', type: 'BROADCAST' },
        { t: '14:02:12', who: 'Alpha-2', msg: 'Confirmed, four armed individuals.', type: 'BROADCAST' },
        { t: '14:02:30', who: 'Alpha-3', msg: 'Rear clear, holding position.', type: 'BROADCAST' },
      ].map((m, i) => (
        <g key={i} transform={`translate(16, ${100 + i * 60})`}>
          <text fill="#5A615C" fontSize="9" fontFamily="var(--font-mono)">
            {m.t} · {m.who}
          </text>
          <rect x="0" y="6" width="228" height="44" fill="#111511" stroke="#1F251F" />
          <text x="8" y="26" fill="#E8ECE9" fontSize="10">
            {m.msg}
          </text>
          <text x="8" y="42" fill="#8A918C" fontSize="8" fontFamily="var(--font-mono)" letterSpacing="0.1em">
            {m.type}
          </text>
        </g>
      ))}

      {/* Compaction */}
      <g transform="translate(16, 300)">
        <rect x="0" y="0" width="228" height="2" fill="#FFB020" />
        <text x="0" y="16" fill="#FFB020" fontSize="9" fontFamily="var(--font-mono)" letterSpacing="0.14em">
          — COMPACTION → COMMANDER —
        </text>
        <rect x="0" y="22" width="228" height="58" fill="#1A1F1A" stroke="#2B3329" />
        <text x="8" y="42" fill="#E8ECE9" fontSize="10">
          Squad Alpha: 4 armed contacts
        </text>
        <text x="8" y="58" fill="#E8ECE9" fontSize="10">
          sector 7 (2× confirmed).
        </text>
        <text x="8" y="74" fill="#E8ECE9" fontSize="10">
          Rear clear, holding.
        </text>
      </g>

      {/* PTT button */}
      <g transform="translate(130, 470)">
        <circle cx="0" cy="0" r="38" fill="#B8FF2C" />
        <text
          x="0"
          y="5"
          fill="#0A0D0B"
          fontSize="11"
          fontFamily="var(--font-mono)"
          fontWeight="600"
          textAnchor="middle"
          letterSpacing="0.1em"
        >
          PTT
        </text>
      </g>
    </g>
  );
}

// ── Tree View ─────────────────────────────────────────────────────────
function TreeScreen() {
  const node = (x: number, y: number, label: string, claimed: boolean, self = false) => (
    <g transform={`translate(${x}, ${y})`}>
      <rect
        x="-38" y="-14" width="76" height="28"
        fill={self ? '#1A1F1A' : '#111511'}
        stroke={self ? '#B8FF2C' : claimed ? '#2B3329' : '#1F251F'}
        strokeDasharray={claimed ? undefined : '3 3'}
      />
      <text x="0" y="4" fill="#E8ECE9" fontSize="10" textAnchor="middle" fontFamily="var(--font-mono)">
        {label}
      </text>
      <circle cx="30" cy="-8" r="3" fill={claimed ? '#B8FF2C' : '#5A615C'} />
    </g>
  );
  return (
    <g>
      <text x="16" y="70" fill="#8A918C" fontSize="10" fontFamily="var(--font-mono)" letterSpacing="0.14em">
        [ OPERATION NIGHTFALL · TREE ]
      </text>

      {/* Edges */}
      <g stroke="#2B3329" strokeWidth="1" fill="none">
        <line x1="130" y1="125" x2="80"  y2="195" />
        <line x1="130" y1="125" x2="180" y2="195" />
        <line x1="80"  y1="220" x2="60"  y2="300" />
        <line x1="80"  y1="220" x2="100" y2="300" />
        <line x1="180" y1="220" x2="160" y2="300" />
        <line x1="180" y1="220" x2="200" y2="300" />
      </g>

      {node(130, 110, 'Commander', true)}
      {node(80, 210, 'Alpha', true, true)}
      {node(180, 210, 'Bravo', true)}
      {node(60, 315, 'A-1', true)}
      {node(100, 315, 'A-2', false)}
      {node(160, 315, 'B-1', true)}
      {node(200, 315, 'B-2', false)}

      {/* Legend */}
      <g transform="translate(16, 420)">
        <circle cx="4" cy="4" r="3" fill="#B8FF2C" />
        <text x="14" y="8" fill="#8A918C" fontSize="9" fontFamily="var(--font-mono)">claimed</text>
        <circle cx="4" cy="24" r="3" fill="#5A615C" />
        <text x="14" y="28" fill="#8A918C" fontSize="9" fontFamily="var(--font-mono)">open</text>
      </g>

      <rect x="16" y="470" width="228" height="36" fill="#1A1F1A" stroke="#2B3329" />
      <text x="130" y="493" fill="#E8ECE9" fontSize="11" textAnchor="middle" fontFamily="var(--font-mono)" letterSpacing="0.1em">
        [ RELEASE MY ROLE ]
      </text>
    </g>
  );
}

// ── Data Flow ─────────────────────────────────────────────────────────
function FlowScreen() {
  return (
    <g fontFamily="var(--font-mono)">
      <text x="16" y="70" fill="#8A918C" fontSize="10" letterSpacing="0.14em">
        [ DATA FLOW · ALPHA LEAD ]
      </text>

      {/* INCOMING */}
      <rect x="16" y="90" width="228" height="120" fill="#111511" stroke="#1F251F" />
      <text x="26" y="106" fill="#8A918C" fontSize="9" letterSpacing="0.14em">INCOMING</text>
      {[
        ['14:02:05', 'Alpha-1', 'BROADCAST'],
        ['14:02:12', 'Alpha-2', 'BROADCAST'],
        ['14:02:30', 'Alpha-3', 'BROADCAST'],
      ].map(([t, who, k], i) => (
        <text key={i} x="26" y={126 + i * 22} fill="#E8ECE9" fontSize="9">
          {t} · {who} [{k}]
        </text>
      ))}

      {/* PROCESSING */}
      <rect x="16" y="222" width="228" height="110" fill="#1A1F1A" stroke="#2B3329" />
      <text x="26" y="238" fill="#FFB020" fontSize="9" letterSpacing="0.14em">⚙ PROCESSING</text>
      <text x="26" y="258" fill="#E8ECE9" fontSize="9">Status: ● Compacting (3 msgs)</text>
      <text x="26" y="274" fill="#8A918C" fontSize="9">Trigger: msg_count ≥ 3</text>
      <text x="26" y="290" fill="#8A918C" fontSize="9">Latency: 340 ms</text>
      <text x="26" y="306" fill="#8A918C" fontSize="9">Model: gemma-4-e4b-it</text>
      <text x="26" y="322" fill="#B8FF2C" fontSize="9">Compression: 74.7%</text>

      {/* OUTGOING */}
      <rect x="16" y="344" width="228" height="110" fill="#111511" stroke="#1F251F" />
      <text x="26" y="360" fill="#8A918C" fontSize="9" letterSpacing="0.14em">OUTGOING</text>
      <text x="26" y="380" fill="#FFB020" fontSize="9">14:02:36 [COMPACTION → HQ]</text>
      <text x="26" y="400" fill="#E8ECE9" fontSize="9">Squad Alpha: 4 armed</text>
      <text x="26" y="414" fill="#E8ECE9" fontSize="9">contacts bldg 4 (2× conf).</text>
      <text x="26" y="428" fill="#E8ECE9" fontSize="9">Rear secure.</text>
      <text x="26" y="448" fill="#5A615C" fontSize="8">Source: Alpha-1, 2, 3</text>
    </g>
  );
}

// ── Map ───────────────────────────────────────────────────────────────
function MapScreen() {
  return (
    <g>
      <text x="16" y="70" fill="#8A918C" fontSize="10" fontFamily="var(--font-mono)" letterSpacing="0.14em">
        [ MAP · OPERATION NIGHTFALL ]
      </text>

      {/* Map body — abstract contour/grid */}
      <g transform="translate(16, 90)">
        <rect x="0" y="0" width="228" height="360" fill="#0D1310" stroke="#1F251F" />
        {/* grid */}
        {Array.from({ length: 10 }).map((_, i) => (
          <line
            key={`h${i}`}
            x1={0}
            y1={36 * i}
            x2={228}
            y2={36 * i}
            stroke="rgba(232,236,233,0.04)"
          />
        ))}
        {Array.from({ length: 8 }).map((_, i) => (
          <line
            key={`v${i}`}
            x1={32 * i}
            y1={0}
            x2={32 * i}
            y2={360}
            stroke="rgba(232,236,233,0.04)"
          />
        ))}
        {/* contour rings */}
        <ellipse cx="100" cy="170" rx="90" ry="60" fill="none" stroke="#1F251F" />
        <ellipse cx="100" cy="170" rx="60" ry="42" fill="none" stroke="#1F251F" />
        <ellipse cx="100" cy="170" rx="30" ry="20" fill="none" stroke="#1F251F" />

        {/* Nodes */}
        {[
          { x: 90, y: 80,  l: 'CMD',  c: '#B8FF2C' },
          { x: 60, y: 150, l: 'ALPHA', c: '#B8FF2C' },
          { x: 140, y: 140, l: 'BRAVO', c: '#B8FF2C' },
          { x: 45, y: 210, l: 'A-1',  c: '#FFB020' },
          { x: 75, y: 240, l: 'A-2',  c: '#B8FF2C' },
          { x: 170, y: 220, l: 'B-1', c: '#B8FF2C' },
        ].map((n) => (
          <g key={n.l} transform={`translate(${n.x},${n.y})`}>
            <circle cx="0" cy="0" r="10" fill="#0A0D0B" stroke={n.c} />
            <circle cx="0" cy="0" r="3" fill={n.c} />
            <text x="14" y="4" fill="#E8ECE9" fontSize="9" fontFamily="var(--font-mono)">
              {n.l}
            </text>
          </g>
        ))}

        {/* Coordinate readout */}
        <text x="6" y="350" fill="#5A615C" fontSize="8" fontFamily="var(--font-mono)" letterSpacing="0.1em">
          LAT 37.7749  LON -122.4194  ACC ±4 m
        </text>
      </g>
    </g>
  );
}
