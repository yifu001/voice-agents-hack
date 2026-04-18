'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { NODES, EDGES, nodeById, childrenOf, siblingsOf } from '@/lib/mesh/layout';
import { VIGNETTES } from '@/lib/mesh/scenarios';
import type { MeshNode } from '@/lib/mesh/types';
import { useReducedMotion } from '@/lib/motion';

type LayerMode = 'broadcast' | 'compaction' | 'both';

interface TickerEntry {
  id: string;
  time: string;
  text: string;
  kind: 'broadcast' | 'compaction';
  from: string;   // callsign
}

interface PulseState {
  byId: Map<string, 'transmitting' | 'compacting'>;
}

interface ActiveEdge {
  from: string;
  to: string;
  kind: 'broadcast' | 'compaction';
  /** 0..1 progress */
  t: number;
  /** ms to complete */
  duration: number;
  startedAt: number;
  /** Epoch ms when this edge should disappear. */
  endAt: number;
}

const VIEW_W = 1000;
const VIEW_H = 560;
const EDGE_MS = 800;
const VIGNETTE_GAP_MS = 6400;

/**
 * The interactive BLE-mesh simulation.
 *
 * - Renders all 9 nodes + parent/child edges in SVG.
 * - Scripted vignettes cycle every ~6.4 s.
 * - A leaf "transmits" → BROADCAST packets travel to siblings + parent.
 * - When a parent accumulates 3 transcripts, it pulses amber and emits
 *   one COMPACTION packet upward to the commander.
 * - Click any node to inspect it; selection persists across cycles.
 * - Reduced motion: state changes instantly, no packet animation.
 */
export function MeshSimulation() {
  const reduced = useReducedMotion();
  const [layerMode, setLayerMode] = useState<LayerMode>('both');
  const [selectedId, setSelectedId] = useState<string>('alpha');
  const [vignetteIdx, setVignetteIdx] = useState(0);
  const [pulse, setPulse] = useState<PulseState>({ byId: new Map() });
  const [activeEdges, setActiveEdges] = useState<ActiveEdge[]>([]);
  const [queues, setQueues] = useState<Map<string, string[]>>(new Map());
  const [lastSummary, setLastSummary] = useState<Map<string, string>>(new Map());
  const [ticker, setTicker] = useState<TickerEntry[]>([]);

  const cycleTimerRef = useRef<number | null>(null);
  const stepTimersRef = useRef<number[]>([]);
  const rafRef = useRef<number | null>(null);

  // ── Helpers ─────────────────────────────────────────────
  const fmtTime = () => {
    const d = new Date();
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(
      2, '0',
    )}:${String(d.getSeconds()).padStart(2, '0')}`;
  };

  const pushTicker = useCallback((entry: Omit<TickerEntry, 'id'>) => {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    setTicker((t) => [{ id, ...entry }, ...t].slice(0, 12));
  }, []);

  const startEdge = useCallback(
    (from: string, to: string, kind: 'broadcast' | 'compaction') => {
      const now = performance.now();
      const duration = reduced ? 0 : EDGE_MS;
      setActiveEdges((prev) => [
        ...prev,
        { from, to, kind, t: 0, duration, startedAt: now, endAt: now + duration + 200 },
      ]);
    },
    [reduced],
  );

  const flagPulse = useCallback(
    (id: string, kind: 'transmitting' | 'compacting', ms = 900) => {
      setPulse((p) => {
        const next = new Map(p.byId);
        next.set(id, kind);
        return { byId: next };
      });
      const h = window.setTimeout(() => {
        setPulse((p) => {
          const next = new Map(p.byId);
          next.delete(id);
          return { byId: next };
        });
      }, ms);
      stepTimersRef.current.push(h);
    },
    [],
  );

  // ── The vignette runner ─────────────────────────────────
  const runVignette = useCallback(
    (idx: number) => {
      // Clear any in-flight step timers.
      stepTimersRef.current.forEach(clearTimeout);
      stepTimersRef.current = [];

      const v = VIGNETTES[idx];
      // Reset the queue of the parent we're about to populate.
      setQueues((q) => {
        const next = new Map(q);
        next.set(v.compaction.by, []);
        return next;
      });

      const STEP = 1800; // ms between leaf transmissions

      v.transcripts.forEach((t, i) => {
        const delay = reduced ? i * 250 : i * STEP;
        const h1 = window.setTimeout(() => {
          const leaf = nodeById(t.node)!;
          flagPulse(leaf.id, 'transmitting', 600);
          // Push to siblings + parent edges.
          const peers = [
            ...siblingsOf(leaf.id).map((s) => s.id),
            leaf.parent!,
          ];
          peers.forEach((pid) => startEdge(leaf.id, pid, 'broadcast'));
          // Add to parent queue.
          setQueues((q) => {
            const next = new Map(q);
            const arr = next.get(leaf.parent!) ?? [];
            next.set(leaf.parent!, [...arr, `${leaf.callsign}: ${t.text}`]);
            return next;
          });
          pushTicker({
            time: fmtTime(),
            text: t.text,
            kind: 'broadcast',
            from: leaf.callsign,
          });
        }, delay);
        stepTimersRef.current.push(h1);
      });

      // After the last transcript, the parent compacts → emits upward.
      const compactAt = (reduced ? v.transcripts.length * 250 : v.transcripts.length * STEP) + 400;
      const h2 = window.setTimeout(() => {
        const parent = nodeById(v.compaction.by)!;
        flagPulse(parent.id, 'compacting', 900);
        startEdge(parent.id, parent.parent!, 'compaction');
        setLastSummary((m) => new Map(m).set(parent.id, v.compaction.text));
        pushTicker({
          time: fmtTime(),
          text: v.compaction.text,
          kind: 'compaction',
          from: parent.callsign,
        });
      }, compactAt);
      stepTimersRef.current.push(h2);
    },
    [flagPulse, pushTicker, reduced, startEdge],
  );

  // Kick the cycle
  useEffect(() => {
    runVignette(vignetteIdx);
    const advance = window.setTimeout(() => {
      setVignetteIdx((i) => (i + 1) % VIGNETTES.length);
    }, VIGNETTE_GAP_MS);
    cycleTimerRef.current = advance;
    return () => {
      if (cycleTimerRef.current) clearTimeout(cycleTimerRef.current);
      stepTimersRef.current.forEach(clearTimeout);
      stepTimersRef.current = [];
    };
  }, [vignetteIdx, runVignette]);

  // Animate active edges + sweep expired ones
  useEffect(() => {
    if (reduced) return;
    const step = () => {
      const now = performance.now();
      setActiveEdges((edges) =>
        edges
          .map((e) => ({
            ...e,
            t: Math.min(1, (now - e.startedAt) / Math.max(1, e.duration)),
          }))
          .filter((e) => now < e.endAt),
      );
      rafRef.current = requestAnimationFrame(step);
    };
    rafRef.current = requestAnimationFrame(step);
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [reduced]);

  // ── Render ──────────────────────────────────────────────
  const selected = nodeById(selectedId) ?? NODES[0];
  const selQueue = queues.get(selected.id) ?? [];
  const selSummary = lastSummary.get(selected.id);

  const shouldDrawKind = (k: 'broadcast' | 'compaction') =>
    layerMode === 'both' || layerMode === k;

  return (
    <div className="grid gap-6 lg:grid-cols-[1.4fr_1fr]">
      {/* Canvas + toggle + ticker */}
      <div className="flex flex-col">
        {/* Layer toggle */}
        <div
          className="mb-4 inline-flex self-start border"
          style={{
            borderColor: 'var(--color-border)',
            background: 'var(--color-surface)',
          }}
        >
          {(['broadcast', 'compaction', 'both'] as LayerMode[]).map((m) => (
            <button
              key={m}
              type="button"
              onClick={() => setLayerMode(m)}
              aria-pressed={layerMode === m}
              className="px-3 py-2 text-[11px] uppercase tracking-[0.12em] transition-colors"
              style={{
                background: layerMode === m ? 'var(--color-accent)' : 'transparent',
                color: layerMode === m ? 'var(--color-bg)' : 'var(--color-text-muted)',
                fontFamily: 'var(--font-mono)',
              }}
            >
              {m === 'both' ? '[ Both ]' : m === 'broadcast' ? '[ Broadcast ]' : '[ Compaction ]'}
            </button>
          ))}
          <span
            className="flex items-center border-l px-3 text-[11px] uppercase tracking-[0.12em]"
            style={{
              borderColor: 'var(--color-border)',
              color: 'var(--color-text-dim)',
              fontFamily: 'var(--font-mono)',
            }}
          >
            {VIGNETTES[vignetteIdx].label}
          </span>
        </div>

        {/* Canvas */}
        <div
          className="relative border"
          style={{
            borderColor: 'var(--color-border)',
            background: 'var(--color-surface)',
          }}
        >
          <svg
            viewBox={`0 0 ${VIEW_W} ${VIEW_H}`}
            xmlns="http://www.w3.org/2000/svg"
            className="w-full"
            style={{ display: 'block' }}
            role="img"
            aria-label="Interactive tactical mesh diagram"
          >
            {/* subtle grid */}
            <defs>
              <pattern id="mesh-grid" width="40" height="40" patternUnits="userSpaceOnUse">
                <path d="M 40 0 L 0 0 0 40" fill="none" stroke="rgba(232,236,233,0.04)" strokeWidth="1" />
              </pattern>
            </defs>
            <rect x="0" y="0" width={VIEW_W} height={VIEW_H} fill="url(#mesh-grid)" />

            {/* Static edges */}
            {EDGES.map((e) => {
              const a = nodeById(e.from)!;
              const b = nodeById(e.to)!;
              return (
                <line
                  key={`${e.from}-${e.to}`}
                  x1={a.x} y1={a.y} x2={b.x} y2={b.y}
                  stroke="var(--color-border-hot)"
                  strokeWidth="1"
                />
              );
            })}

            {/* Active edge glow + packet dot */}
            {activeEdges
              .filter((e) => shouldDrawKind(e.kind))
              .map((e, i) => {
                const a = nodeById(e.from);
                const b = nodeById(e.to);
                if (!a || !b) return null;
                const stroke =
                  e.kind === 'broadcast'
                    ? 'rgba(184,255,44,0.55)'
                    : 'rgba(255,176,32,0.7)';
                const t = reduced ? 1 : e.t;
                const px = a.x + (b.x - a.x) * t;
                const py = a.y + (b.y - a.y) * t;
                return (
                  <g key={`${e.from}-${e.to}-${i}-${e.startedAt}`}>
                    <line
                      x1={a.x} y1={a.y} x2={b.x} y2={b.y}
                      stroke={stroke} strokeWidth="1.5"
                    />
                    <circle
                      cx={px} cy={py} r="5"
                      fill={e.kind === 'broadcast' ? 'var(--color-accent)' : 'var(--color-signal-amber)'}
                    />
                  </g>
                );
              })}

            {/* Nodes */}
            {NODES.map((n) => (
              <NodeCell
                key={n.id}
                node={n}
                selected={selectedId === n.id}
                pulse={pulse.byId.get(n.id)}
                onClick={() => setSelectedId(n.id)}
              />
            ))}
          </svg>
        </div>

        {/* Ticker */}
        <div
          className="mt-4 max-h-44 overflow-y-auto border"
          style={{
            borderColor: 'var(--color-border)',
            background: 'var(--color-surface)',
          }}
          role="log"
          aria-live="polite"
          aria-label="Mesh event ticker"
        >
          <div
            className="flex items-center justify-between gap-3 border-b px-4 py-2.5"
            style={{ borderColor: 'var(--color-border)' }}
          >
            <span
              className="text-[10px] uppercase tracking-[0.14em]"
              style={{
                color: 'var(--color-text-muted)',
                fontFamily: 'var(--font-mono)',
              }}
            >
              // live ticker · mesh events
            </span>
          </div>
          <ul className="divide-y" style={{ borderColor: 'var(--color-border)' }}>
            {ticker.length === 0 && (
              <li
                className="px-4 py-3 text-[12px]"
                style={{
                  color: 'var(--color-text-dim)',
                  fontFamily: 'var(--font-mono)',
                }}
              >
                awaiting transmission…
              </li>
            )}
            {ticker.map((e) => (
              <li
                key={e.id}
                className="flex items-baseline gap-3 px-4 py-2.5 text-[12px]"
                style={{ borderColor: 'var(--color-border)' }}
              >
                <span
                  style={{
                    color: 'var(--color-text-dim)',
                    fontFamily: 'var(--font-mono)',
                  }}
                >
                  {e.time}
                </span>
                <span
                  style={{
                    color: e.kind === 'compaction'
                      ? 'var(--color-signal-amber)'
                      : 'var(--color-accent)',
                    fontFamily: 'var(--font-mono)',
                    fontSize: 10,
                    letterSpacing: '0.1em',
                    textTransform: 'uppercase',
                    minWidth: 70,
                  }}
                >
                  {e.kind}
                </span>
                <span
                  style={{
                    color: 'var(--color-text-muted)',
                    fontFamily: 'var(--font-mono)',
                    minWidth: 48,
                  }}
                >
                  {e.from}
                </span>
                <span style={{ color: 'var(--color-text)' }}>{e.text}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>

      {/* Inspector */}
      <MeshInspector
        node={selected}
        queue={selQueue}
        lastSummary={selSummary}
      />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Node cell
// ─────────────────────────────────────────────────────────────
function NodeCell({
  node,
  selected,
  pulse,
  onClick,
}: {
  node: MeshNode;
  selected: boolean;
  pulse?: 'transmitting' | 'compacting';
  onClick: () => void;
}) {
  const stroke = selected
    ? 'var(--color-accent)'
    : pulse === 'compacting'
      ? 'var(--color-signal-amber)'
      : pulse === 'transmitting'
        ? 'var(--color-accent)'
        : 'var(--color-border-hot)';

  const fill = node.role === 'commander'
    ? 'var(--color-elevated)'
    : 'var(--color-surface)';

  const width = node.role === 'commander' ? 180 : 140;
  const height = 64;
  const x = node.x - width / 2;
  const y = node.y - height / 2;

  return (
    <g
      role="button"
      aria-label={`${node.label} · ${node.role} · click to inspect`}
      tabIndex={0}
      onClick={onClick}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          onClick();
        }
      }}
      style={{ cursor: 'pointer' }}
    >
      {/* Pulse ring when active */}
      {pulse && (
        <rect
          x={x - 6} y={y - 6} width={width + 12} height={height + 12}
          fill="none" stroke={stroke} strokeWidth="1" opacity="0.5"
        />
      )}
      <rect x={x} y={y} width={width} height={height} fill={fill} stroke={stroke} strokeWidth="1.25" />
      <text
        x={node.x} y={node.y - 8}
        fill="var(--color-text-muted)"
        fontSize="10" fontFamily="var(--font-mono)"
        textAnchor="middle" letterSpacing="0.12em"
      >
        {node.callsign}
      </text>
      <text
        x={node.x} y={node.y + 14}
        fill="var(--color-text)"
        fontSize="14" fontWeight="500"
        textAnchor="middle" letterSpacing="-0.01em"
      >
        {node.label}
      </text>
    </g>
  );
}

// ─────────────────────────────────────────────────────────────
// Inspector panel
// ─────────────────────────────────────────────────────────────
function MeshInspector({
  node,
  queue,
  lastSummary,
}: {
  node: MeshNode;
  queue: string[];
  lastSummary?: string;
}) {
  const kids = childrenOf(node.id);
  const sibs = siblingsOf(node.id);
  const parent = node.parent ? nodeById(node.parent) : null;

  return (
    <aside
      className="flex flex-col border"
      style={{
        borderColor: 'var(--color-border)',
        background: 'var(--color-surface)',
      }}
    >
      <div
        className="flex items-center justify-between gap-3 border-b px-5 py-3"
        style={{ borderColor: 'var(--color-border)' }}
      >
        <span
          className="text-[10px] uppercase tracking-[0.14em]"
          style={{
            color: 'var(--color-text-muted)',
            fontFamily: 'var(--font-mono)',
          }}
        >
          // inspector
        </span>
        <span
          className="text-[10px] uppercase tracking-[0.14em]"
          style={{
            color: 'var(--color-accent)',
            fontFamily: 'var(--font-mono)',
          }}
        >
          {node.callsign}
        </span>
      </div>

      <div className="space-y-5 px-5 py-5">
        {/* Role + location */}
        <div>
          <div
            className="text-[22px] font-semibold leading-tight"
            style={{ color: 'var(--color-text)', letterSpacing: '-0.02em' }}
          >
            {node.label}
          </div>
          <div
            className="mt-1 text-[11px] uppercase tracking-[0.14em]"
            style={{
              color: 'var(--color-text-muted)',
              fontFamily: 'var(--font-mono)',
            }}
          >
            {node.role === 'commander' ? 'Root · Commander' : node.role === 'l1' ? 'L1 · Squad lead' : 'L2 · Leaf operator'}
          </div>
        </div>

        {/* Coord readout */}
        <div
          className="grid grid-cols-2 gap-px border"
          style={{
            borderColor: 'var(--color-border)',
            background: 'var(--color-border)',
          }}
        >
          {[
            ['LAT', node.lat],
            ['LON', node.lon],
          ].map(([k, v]) => (
            <div
              key={k}
              className="px-3 py-2.5"
              style={{ background: 'var(--color-surface)' }}
            >
              <div
                className="text-[10px] uppercase"
                style={{
                  color: 'var(--color-text-dim)',
                  fontFamily: 'var(--font-mono)',
                  letterSpacing: '0.14em',
                }}
              >
                {k}
              </div>
              <div
                className="mt-1 text-[12px]"
                style={{
                  color: 'var(--color-text)',
                  fontFamily: 'var(--font-mono)',
                }}
              >
                {v}
              </div>
            </div>
          ))}
        </div>

        {/* Relations */}
        <InspectorList
          title="Parent"
          items={parent ? [parent.callsign] : ['— (root)']}
        />
        <InspectorList title="Siblings" items={sibs.map((s) => s.callsign)} />
        <InspectorList title="Children" items={kids.map((k) => k.callsign)} />

        {/* Queue */}
        <div>
          <div
            className="mb-2 text-[10px] uppercase tracking-[0.14em]"
            style={{
              color: 'var(--color-text-muted)',
              fontFamily: 'var(--font-mono)',
            }}
          >
            Compaction queue ({queue.length}/3)
          </div>
          <div
            className="border"
            style={{
              borderColor: 'var(--color-border)',
              background: 'var(--color-bg)',
            }}
          >
            {queue.length === 0 ? (
              <div
                className="px-3 py-3 text-[12px]"
                style={{
                  color: 'var(--color-text-dim)',
                  fontFamily: 'var(--font-mono)',
                }}
              >
                empty
              </div>
            ) : (
              queue.map((t, i) => (
                <div
                  key={i}
                  className="border-t px-3 py-2 text-[12px] first:border-t-0"
                  style={{
                    borderColor: 'var(--color-border)',
                    color: 'var(--color-text)',
                    fontFamily: 'var(--font-mono)',
                  }}
                >
                  {t}
                </div>
              ))
            )}
          </div>
        </div>

        {/* Last emitted summary */}
        {lastSummary && (
          <div>
            <div
              className="mb-2 text-[10px] uppercase tracking-[0.14em]"
              style={{
                color: 'var(--color-signal-amber)',
                fontFamily: 'var(--font-mono)',
              }}
            >
              Last emitted compaction
            </div>
            <div
              className="border p-3 text-[13px] leading-[1.55]"
              style={{
                borderColor: 'var(--color-border-hot)',
                background: 'var(--color-elevated)',
                color: 'var(--color-text)',
              }}
            >
              {lastSummary}
            </div>
          </div>
        )}
      </div>
    </aside>
  );
}

function InspectorList({ title, items }: { title: string; items: string[] }) {
  return (
    <div className="flex items-start gap-4">
      <span
        className="w-20 shrink-0 text-[10px] uppercase tracking-[0.14em]"
        style={{
          color: 'var(--color-text-muted)',
          fontFamily: 'var(--font-mono)',
        }}
      >
        {title}
      </span>
      <span
        className="text-[12px]"
        style={{
          color: items.length === 0 ? 'var(--color-text-dim)' : 'var(--color-text)',
          fontFamily: 'var(--font-mono)',
          letterSpacing: '0.02em',
        }}
      >
        {items.length === 0 ? 'none' : items.join(' · ')}
      </span>
    </div>
  );
}
