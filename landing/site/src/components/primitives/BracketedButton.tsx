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
 * Tactical-brand CTA. Primary = lime fill; Ghost = bordered transparent;
 * Link = text-only with arrow.
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
      background: 'var(--color-accent)',
      color: 'var(--color-bg)',
      border: '1px solid var(--color-accent)',
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
    },
  };

  const classes = `inline-flex items-center gap-2 font-medium transition-opacity hover:opacity-90 ${
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
