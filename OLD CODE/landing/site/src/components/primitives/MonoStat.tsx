interface MonoStatProps {
  big: string;
  small: string;
  emphasis?: boolean;
}

/**
 * Big mono numeral + tiny uppercase label below.
 * Refinement: emphasis was previously color-coded (lime). Now emphasis
 * adds a thin amber underscore + slightly heavier weight, so all four
 * stats stay readable as a row of equals — color is reserved for true
 * signal moments, not decorative variation.
 */
export function MonoStat({ big, small, emphasis = false }: MonoStatProps) {
  return (
    <div className="flex flex-col">
      <div
        className="leading-none"
        style={{
          color: 'var(--color-text)',
          fontFamily: 'var(--font-mono)',
          fontSize: 'clamp(1.75rem, 3.2vw, 2.75rem)',
          fontWeight: emphasis ? 600 : 500,
          letterSpacing: '-0.02em',
        }}
      >
        {big}
      </div>
      <div
        className="mt-3 flex items-center gap-2 uppercase"
        style={{
          color: 'var(--color-text-muted)',
          fontFamily: 'var(--font-mono)',
          fontSize: '10px',
          letterSpacing: '0.14em',
        }}
      >
        {emphasis && (
          <span
            aria-hidden
            className="inline-block h-px w-3"
            style={{ background: 'var(--color-signal-amber)' }}
          />
        )}
        <span>{small}</span>
      </div>
    </div>
  );
}
