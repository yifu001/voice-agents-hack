interface PulsingDotProps {
  label?: string;
  tone?: 'amber' | 'cyan' | 'red';
  size?: 'sm' | 'md';
}

/**
 * Tiny pulsing dot + uppercase mono label.
 * Refinement: tone palette is now amber|cyan|red (was accent|amber|red,
 * where 'accent' meant lime). Label color is text-muted so only the
 * dot itself carries the signal color — much quieter than a colored
 * phrase, more in line with real instrument readouts.
 */
export function PulsingDot({
  label = 'Operational',
  tone = 'amber',
  size = 'md',
}: PulsingDotProps) {
  const color =
    tone === 'cyan'
      ? 'var(--color-signal-cyan)'
      : tone === 'red'
        ? 'var(--color-signal-red)'
        : 'var(--color-signal-amber)';

  const dim = size === 'sm' ? 'h-1.5 w-1.5' : 'h-2 w-2';

  return (
    <span className="inline-flex items-center gap-2">
      <span
        aria-hidden
        className={`${dim} pulse-op rounded-full`}
        style={{
          background: color,
          boxShadow: `0 0 0 2px rgba(0,0,0,0.0), 0 0 8px ${color}40`,
        }}
      />
      <span
        className="text-[10.5px] uppercase tracking-[0.16em]"
        style={{
          color: 'var(--color-text-muted)',
          fontFamily: 'var(--font-mono)',
        }}
      >
        {label}
      </span>
    </span>
  );
}
