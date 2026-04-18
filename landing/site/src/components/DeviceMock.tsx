'use client';
import { useEffect, useState } from 'react';
import { IOSScreen, type ScreenKind } from './IOSScreen';

const CYCLE: ScreenKind[] = ['live', 'tree', 'flow', 'map'];

interface DeviceMockProps {
  cycleMs?: number;
  auto?: boolean;
}

/**
 * iPhone-shaped frame that auto-cycles through the four app screens.
 * Pure SVG/CSS — no images needed.
 */
export function DeviceMock({ cycleMs = 3200, auto = true }: DeviceMockProps) {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    if (!auto) return;
    const id = setInterval(() => {
      setIndex((i) => (i + 1) % CYCLE.length);
    }, cycleMs);
    return () => clearInterval(id);
  }, [auto, cycleMs]);

  return (
    <div className="relative mx-auto" style={{ width: 280 }}>
      {/* Device frame */}
      <div
        className="relative overflow-hidden"
        style={{
          aspectRatio: '280 / 580',
          background: '#050705',
          border: '1px solid var(--color-border-hot)',
          borderRadius: 34,
          padding: 8,
          boxShadow:
            '0 40px 80px -20px rgba(0,0,0,0.6), 0 0 0 1px rgba(232,236,233,0.04)',
        }}
      >
        {/* Notch */}
        <div
          aria-hidden
          className="absolute left-1/2 top-2 z-10 -translate-x-1/2"
          style={{
            width: 90,
            height: 18,
            background: '#050705',
            borderRadius: 12,
          }}
        />
        {/* Screen */}
        <div
          className="relative h-full w-full overflow-hidden"
          style={{
            background: 'var(--color-bg)',
            borderRadius: 26,
          }}
        >
          <IOSScreen kind={CYCLE[index]} />
        </div>
      </div>

      {/* Screen selector dots */}
      <div className="mt-6 flex items-center justify-center gap-2">
        {CYCLE.map((k, i) => (
          <button
            key={k}
            type="button"
            onClick={() => setIndex(i)}
            aria-label={`Show ${k} screen`}
            className="h-1.5 transition-all"
            style={{
              width: i === index ? 24 : 6,
              background:
                i === index ? 'var(--color-accent)' : 'var(--color-border-hot)',
            }}
          />
        ))}
      </div>
    </div>
  );
}
