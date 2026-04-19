import { SectionFrame } from './primitives/SectionFrame';
import { security } from '@/content/copy';

export function Security() {
  return (
    <SectionFrame
      id="security"
      code="S-09"
      eyebrow={security.eyebrow}
      title={security.title}
    >
      <div className="mt-8 grid gap-px sm:grid-cols-2" style={{ background: 'var(--color-border)' }}>
        {security.cards.map((c) => (
          <div
            key={c.title}
            className="p-6 sm:p-8"
            style={{ background: 'var(--color-surface)' }}
          >
            <div
              className="mb-3 flex items-center gap-3"
              style={{ color: 'var(--color-accent)' }}
            >
              <svg width="12" height="12" viewBox="0 0 12 12" aria-hidden>
                <rect x="1" y="1" width="10" height="10" fill="none" stroke="currentColor" />
                <line x1="1" y1="1" x2="11" y2="11" stroke="currentColor" />
              </svg>
              <span
                className="text-[11px] uppercase tracking-[0.14em]"
                style={{ fontFamily: 'var(--font-mono)' }}
              >
                locked
              </span>
            </div>
            <h3
              className="text-[18px] font-semibold"
              style={{
                color: 'var(--color-text)',
                letterSpacing: '-0.01em',
              }}
            >
              {c.title}
            </h3>
            <p
              className="mt-3 max-w-xl leading-[1.6]"
              style={{ color: 'var(--color-text-muted)', fontSize: 15 }}
            >
              {c.body}
            </p>
          </div>
        ))}
      </div>
    </SectionFrame>
  );
}
