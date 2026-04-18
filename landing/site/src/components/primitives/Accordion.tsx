'use client';
import { ReactNode, useState } from 'react';

interface AccordionProps {
  title: string;
  children: ReactNode;
  defaultOpen?: boolean;
}

/** "Go deeper" expandable block. */
export function Accordion({ title, children, defaultOpen = false }: AccordionProps) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <div
      className="border-t"
      style={{ borderColor: 'var(--color-border)' }}
    >
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        className="flex w-full items-center justify-between gap-4 py-5 text-left transition-colors hover:text-[color:var(--color-text)]"
        style={{
          color: open ? 'var(--color-text)' : 'var(--color-text-muted)',
          fontFamily: 'var(--font-mono)',
          fontSize: '13px',
          letterSpacing: '0.04em',
        }}
      >
        <span className="flex items-center gap-3">
          <span
            aria-hidden
            className="inline-block w-4 text-center"
            style={{ color: 'var(--color-accent)' }}
          >
            {open ? '−' : '+'}
          </span>
          {title}
        </span>
        <span
          aria-hidden
          className="text-[11px] uppercase tracking-[0.14em]"
          style={{ color: 'var(--color-text-dim)' }}
        >
          {open ? 'close' : 'expand'}
        </span>
      </button>
      {open && (
        <div
          className="pb-8"
          style={{
            color: 'var(--color-text-muted)',
            fontSize: '15px',
            lineHeight: 1.65,
          }}
        >
          {children}
        </div>
      )}
    </div>
  );
}

/** Container that draws a bottom border under the last accordion. */
export function AccordionGroup({ children }: { children: ReactNode }) {
  return (
    <div
      className="border-b"
      style={{ borderColor: 'var(--color-border)' }}
    >
      {children}
    </div>
  );
}
