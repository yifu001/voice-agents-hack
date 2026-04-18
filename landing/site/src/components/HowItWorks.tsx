import { SectionFrame } from './primitives/SectionFrame';
import { howItWorks } from '@/content/copy';

export function HowItWorks() {
  return (
    <SectionFrame
      id="how"
      eyebrow={howItWorks.eyebrow}
      title={howItWorks.title}
      background="dots"
    >
      <div className="mt-8 grid gap-px" style={{ background: 'var(--color-border)' }}>
        {howItWorks.steps.map((s) => (
          <div
            key={s.n}
            className="relative grid gap-6 p-6 sm:grid-cols-[auto_1fr] sm:p-8"
            style={{ background: 'var(--color-surface)' }}
          >
            {/* Number */}
            <div
              className="leading-none"
              style={{
                color: 'var(--color-text-dim)',
                fontFamily: 'var(--font-mono)',
                fontSize: 'clamp(2rem, 3.8vw, 3rem)',
                fontWeight: 500,
                letterSpacing: '-0.03em',
              }}
            >
              {s.n} /
            </div>
            {/* Body */}
            <div>
              <h3
                className="text-[17px] font-semibold sm:text-[19px]"
                style={{
                  color: 'var(--color-text)',
                  letterSpacing: '-0.01em',
                }}
              >
                {s.title}
              </h3>
              <p
                className="mt-2 max-w-2xl leading-[1.6]"
                style={{ color: 'var(--color-text-muted)', fontSize: 15 }}
              >
                {s.body}
              </p>
              <p
                className="mt-4 text-[11px]"
                style={{
                  color: 'var(--color-text-dim)',
                  fontFamily: 'var(--font-mono)',
                  letterSpacing: '0.06em',
                }}
              >
                → {s.evidence}
              </p>
            </div>
          </div>
        ))}
      </div>
    </SectionFrame>
  );
}
