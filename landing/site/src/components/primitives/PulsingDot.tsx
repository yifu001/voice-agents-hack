interface PulsingDotProps {
  label?: string;
  tone?: 'accent' | 'amber' | 'red';
  size?: 'sm' | 'md';
}

/** Tiny pulsing dot + optional uppercase mono label. */
export function PulsingDot({
  label = 'Operational',
  tone = 'accent',
  size = 'md',
}: PulsingDotProps) {
  const color =
    tone === 'accent'
      ? 'var(--color-accent)'
      : tone === 'amber'
        ? 'var(--color-signal-amber)'
        : 'var(--color-signal-red)';

  const dim = size === 'sm' ? 'h-1.5 w-1.5' : 'h-2 w-2';

  return (
    <span className="inline-flex items-center gap-2">
      <span
        aria-hidden
        className={`${dim} pulse-op rounded-full`}
        style={{ background: color }}
      />
      <span
        className="text-[11px] uppercase tracking-[0.14em]"
        style={{
          color,
          fontFamily: 'var(--font-mono)',
        }}
      >
        {label}
      </span>
    </span>
  );
}
