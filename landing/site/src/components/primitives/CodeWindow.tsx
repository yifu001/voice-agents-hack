import { ReactNode } from 'react';

interface CodeWindowProps {
  filename?: string;
  lang?: string;
  children: ReactNode;
  stacked?: boolean;          // AliasKit stacked-depth effect
}

/**
 * Terminal-style code block. When stacked=true, renders 3 overlapping
 * divs for depth (direct AliasKit HeroSection lift).
 */
export function CodeWindow({
  filename,
  lang,
  children,
  stacked = false,
}: CodeWindowProps) {
  const frame = (
    <div
      className="relative border"
      style={{
        background: '#0E110E',
        borderColor: 'var(--color-border)',
        borderRadius: 'var(--radius-panel)',
      }}
    >
      {/* Top glow line */}
      <div
        aria-hidden
        className="pointer-events-none absolute left-0 right-0 top-0 h-px"
        style={{
          background:
            'linear-gradient(to right, transparent, rgba(184,255,44,0.25), transparent)',
        }}
      />
      {/* Title bar */}
      <div
        className="flex items-center gap-3 border-b px-4 py-2.5"
        style={{
          borderColor: 'var(--color-border)',
          background: 'rgba(0, 0, 0, 0.3)',
        }}
      >
        <div className="flex gap-1.5">
          <span
            className="h-2.5 w-2.5 rounded-full"
            style={{ background: '#2B3329' }}
          />
          <span
            className="h-2.5 w-2.5 rounded-full"
            style={{ background: '#2B3329' }}
          />
          <span
            className="h-2.5 w-2.5 rounded-full"
            style={{ background: '#2B3329' }}
          />
        </div>
        {filename && (
          <span
            className="text-[11px]"
            style={{
              color: 'var(--color-text-muted)',
              fontFamily: 'var(--font-mono)',
            }}
          >
            {filename}
          </span>
        )}
        {lang && (
          <span
            className="ml-auto text-[10px] uppercase tracking-[0.12em]"
            style={{
              color: 'var(--color-text-dim)',
              fontFamily: 'var(--font-mono)',
            }}
          >
            {lang}
          </span>
        )}
      </div>
      {/* Content */}
      <pre
        className="overflow-x-auto px-5 py-5 text-[13px] leading-[1.65]"
        style={{
          color: '#E2E8F0',
          fontFamily: 'var(--font-mono)',
        }}
      >
        {children}
      </pre>
    </div>
  );

  if (!stacked) return frame;

  return (
    <div className="relative">
      {/* Back layer */}
      <div
        aria-hidden
        className="absolute inset-0 translate-x-3 translate-y-2 border"
        style={{
          background: '#080B09',
          borderColor: '#141914',
          borderRadius: 'var(--radius-panel)',
        }}
      />
      {/* Mid layer */}
      <div
        aria-hidden
        className="absolute inset-0 translate-x-[6px] translate-y-1 border"
        style={{
          background: '#0B0E0B',
          borderColor: '#1A1F1A',
          borderRadius: 'var(--radius-panel)',
        }}
      />
      {/* Front */}
      <div className="relative">{frame}</div>
    </div>
  );
}

/**
 * Minimal syntax highlighter. Not trying to be shiki — just semantic
 * colouring for the handful of code snippets that appear on the page.
 * Accepts pre-tokenised <Token> children.
 */
export function Token({
  kind,
  children,
}: {
  kind:
    | 'keyword'
    | 'string'
    | 'number'
    | 'comment'
    | 'fn'
    | 'type'
    | 'tag'
    | 'punct';
  children: ReactNode;
}) {
  const colors: Record<string, string> = {
    keyword: '#C678DD',
    string: '#98C379',
    number: '#D19A66',
    comment: '#5A615C',
    fn: '#61AFEF',
    type: '#E5C07B',
    tag: '#B8FF2C',
    punct: '#8A918C',
  };
  return <span style={{ color: colors[kind] }}>{children}</span>;
}
