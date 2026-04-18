import { ReactNode } from 'react';

interface SectionFrameProps {
  id?: string;
  eyebrow?: string;          // "03 / THE PROBLEM"
  title?: string;
  intro?: ReactNode;
  children: ReactNode;
  background?: 'plain' | 'grid' | 'dots';
  className?: string;
}

/**
 * Every section on the page wraps in this.
 * - Horizontal scan rule at top (1px, rgba(232,236,233,0.08))
 * - Optional corner dots at top-left and top-right
 * - Optional eyebrow (mono number/label), title, intro
 * - Optional grid or dot background underlay
 */
export function SectionFrame({
  id,
  eyebrow,
  title,
  intro,
  children,
  background = 'plain',
  className = '',
}: SectionFrameProps) {
  return (
    <section
      id={id}
      className={`section-dots relative border-t ${className}`}
      style={{ borderColor: 'rgba(232, 236, 233, 0.08)' }}
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
              'radial-gradient(rgba(232,236,233,0.05) 1px, transparent 0)',
            backgroundSize: '16px 16px',
          }}
        />
      )}

      <div className="relative mx-auto max-w-[1200px] px-6 py-16 sm:px-10 sm:py-24 lg:px-14">
        {eyebrow && (
          <div
            className="mb-4 text-[11px] uppercase tracking-[0.14em]"
            style={{
              color: 'var(--color-text-muted)',
              fontFamily: 'var(--font-mono)',
            }}
          >
            {eyebrow}
          </div>
        )}
        {title && (
          <h2
            className="mb-6 max-w-3xl font-semibold leading-[1.05]"
            style={{
              color: 'var(--color-text)',
              fontSize: 'clamp(1.75rem, 3.2vw + 0.5rem, 3rem)',
              letterSpacing: '-0.02em',
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
