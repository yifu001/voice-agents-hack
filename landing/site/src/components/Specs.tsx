import { SectionFrame } from './primitives/SectionFrame';
import { specs } from '@/content/copy';

export function Specs() {
  return (
    <SectionFrame
      id="specs"
      code="S-08"
      eyebrow={specs.eyebrow}
      title={specs.title}
    >
      <div
        className="mt-8 grid gap-px border"
        style={{
          borderColor: 'var(--color-border)',
          background: 'var(--color-border)',
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
        }}
      >
        {specs.columns.map((col) => (
          <div
            key={col.title}
            className="p-6 sm:p-8"
            style={{ background: 'var(--color-surface)' }}
          >
            {/* Column header — restrained to muted text + thin amber rule
                so the spec table reads as a row of equals, not a wall of
                yellow titles. */}
            <div
              className="mb-5 flex items-center gap-3 text-[11px] uppercase tracking-[0.18em]"
              style={{
                color: 'var(--color-text-muted)',
                fontFamily: 'var(--font-mono)',
              }}
            >
              <span
                aria-hidden
                className="inline-block h-px w-3"
                style={{ background: 'var(--color-signal-amber)' }}
              />
              <span>{col.title}</span>
            </div>
            <dl className="space-y-2.5">
              {col.rows.map(([k, v]) => (
                <div key={k} className="flex items-baseline justify-between gap-4">
                  <dt
                    className="text-[11px] uppercase tracking-[0.1em]"
                    style={{
                      color: 'var(--color-text-muted)',
                      fontFamily: 'var(--font-mono)',
                    }}
                  >
                    {k}
                  </dt>
                  <dd
                    className="text-right text-[13px]"
                    style={{
                      color: 'var(--color-text)',
                      fontFamily: 'var(--font-mono)',
                    }}
                  >
                    {v}
                  </dd>
                </div>
              ))}
            </dl>
          </div>
        ))}
      </div>
    </SectionFrame>
  );
}
