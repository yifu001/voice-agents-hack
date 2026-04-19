import { ReactNode } from 'react';

interface BracketedButtonProps {
  children: ReactNode;
  href?: string;
  onClick?: () => void;
  variant?: 'primary' | 'ghost' | 'link';
  size?: 'sm' | 'md';
  className?: string;
  ariaLabel?: string;
}

/**
 * Tactical-brand CTA.
 * - Primary  = warm sand "etched plate" with dark ink (was neon lime).
 *              Reads as serious instrumentation, not a highlighter.
 * - Ghost    = thin neutral border, transparent.
 * - Link     = underline-on-hover, no chrome — quieter than the prior
 *              all-bracket-uppercase noise.
 */
export function BracketedButton({
  children,
  href,
  onClick,
  variant = 'primary',
  size = 'md',
  className = '',
  ariaLabel,
}: BracketedButtonProps) {
  const padding = size === 'sm' ? 'px-3.5 py-2' : 'px-5 py-3';
  const fontSize = size === 'sm' ? '11px' : '12px';

  const styles: Record<string, React.CSSProperties> = {
    primary: {
      background: 'var(--color-cta)',
      color: 'var(--color-cta-ink)',
      border: '1px solid var(--color-cta)',
      borderRadius: 'var(--radius-btn)',
    },
    ghost: {
      background: 'transparent',
      color: 'var(--color-text)',
      border: '1px solid var(--color-border-hot)',
      borderRadius: 'var(--radius-btn)',
    },
    link: {
      background: 'transparent',
      color: 'var(--color-text-muted)',
      border: 'none',
      borderBottom: '1px solid transparent',
      paddingBottom: '2px',
    },
  };

  const baseHover =
    variant === 'link'
      ? 'transition-colors hover:text-[color:var(--color-text)] hover:border-[color:var(--color-text-dim)]'
      : 'transition-[transform,opacity,background] duration-200 hover:opacity-95 hover:translate-y-[-1px]';

  const classes = `inline-flex items-center gap-2 font-medium ${baseHover} ${
    variant === 'link' ? '' : padding
  } ${className}`;

  const inner = (
    <span
      className={classes}
      style={{
        ...styles[variant],
        fontFamily: 'var(--font-mono)',
        fontSize,
        letterSpacing: '0.08em',
        textTransform: 'uppercase',
      }}
    >
      {children}
    </span>
  );

  if (href) {
    return (
      <a href={href} aria-label={ariaLabel}>
        {inner}
      </a>
    );
  }

  return (
    <button type="button" onClick={onClick} aria-label={ariaLabel}>
      {inner}
    </button>
  );
}
