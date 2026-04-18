interface MonoStatProps {
  big: string;
  small: string;
  emphasis?: boolean;
}

/** Big mono numeral + tiny uppercase label below. AliasKit StatsBand lift. */
export function MonoStat({ big, small, emphasis = false }: MonoStatProps) {
  return (
    <div className="flex flex-col">
      <div
        className="leading-none"
        style={{
          color: emphasis ? 'var(--color-accent)' : 'var(--color-text)',
          fontFamily: 'var(--font-mono)',
          fontSize: 'clamp(1.75rem, 3.2vw, 2.75rem)',
          fontWeight: 500,
          letterSpacing: '-0.02em',
        }}
      >
        {big}
      </div>
      <div
        className="mt-3 uppercase"
        style={{
          color: 'var(--color-text-muted)',
          fontFamily: 'var(--font-mono)',
          fontSize: '10px',
          letterSpacing: '0.14em',
        }}
      >
        {small}
      </div>
    </div>
  );
}
