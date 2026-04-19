import { ReactNode } from 'react';

interface SectionFrameProps {
  id?: string;
  eyebrow?: string;          // "03 / THE PROBLEM"
  title?: string;
  intro?: ReactNode;
  children: ReactNode;
  background?: 'plain' | 'grid' | 'dots';
  className?: string;
  /** Optional 2-3 char operational code shown as a small corner plate (e.g. "S-03"). */
  code?: string;
}

/**
 * Section wrapper.
 *  - Refined eyebrow: a horizontal rule + small mono designator, less
 *    "// section" comment-soup, more "instrument legend".
 *  - Title now uses the display font (Funnel Display) with tighter tracking.
 *  - Optional `code` plate sits in the upper-right corner — adds bespoke
 *    flavor without adding chromatic load.
 */
export function SectionFrame({
  id,
  eyebrow,
  title,
  intro,
  children,
  background = 'plain',
  className = '',
  code,
}: SectionFrameProps) {
  return (
    <section
      id={id}
      className={`section-dots relative border-t ${className}`}
      style={{ borderColor: 'rgba(236, 234, 228, 0.08)' }}
    >
      {background === 'grid' && (
        <div
          aria-hidden
          className="bg-grid-48 pointer-events-none absolute inset-0"
        />
      )}
      {background === 'dots' && (
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{
            backgroundImage:
              'radial-gradient(rgba(236,234,228,0.05) 1px, transparent 0)',
            backgroundSize: '16px 16px',
          }}
        />
      )}

      {/* Corner operational code plate */}
      {code && (
        <div
          aria-hidden
          className="absolute right-4 top-4 z-10 hidden items-center gap-1.5 border px-2 py-1 sm:flex"
          style={{
            borderColor: 'var(--color-border)',
            background: 'rgba(11, 11, 12, 0.6)',
            backdropFilter: 'blur(6px)',
          }}
        >
          <span
            className="inline-block h-1 w-1 rounded-full"
            style={{ background: 'var(--color-signal-amber)' }}
          />
          <span
            className="text-[9.5px] uppercase tracking-[0.18em]"
            style={{
              color: 'var(--color-text-muted)',
              fontFamily: 'var(--font-mono)',
            }}
          >
            {code}
          </span>
        </div>
      )}

      <div className="relative mx-auto max-w-[1200px] px-6 py-16 sm:px-10 sm:py-24 lg:px-14">
        {eyebrow && (
          <div className="mb-5 flex items-center gap-3">
            <span
              aria-hidden
              className="block h-px w-8"
              style={{ background: 'var(--color-border-hot)' }}
            />
            <div
              className="text-[10.5px] uppercase tracking-[0.2em]"
              style={{
                color: 'var(--color-text-muted)',
                fontFamily: 'var(--font-mono)',
              }}
            >
              {eyebrow}
            </div>
          </div>
        )}
        {title && (
          <h2
            className="display-tight mb-6 max-w-3xl font-medium leading-[1.05]"
            style={{
              color: 'var(--color-text)',
              fontSize: 'clamp(1.75rem, 3.2vw + 0.5rem, 3rem)',
            }}
          >
            {title}
          </h2>
        )}
        {intro && (
          <div
            className="mb-10 max-w-2xl text-base leading-[1.65] sm:text-lg"
            style={{ color: 'var(--color-text-muted)' }}
          >
            {intro}
          </div>
        )}
        {children}
      </div>
    </section>
  );
}
