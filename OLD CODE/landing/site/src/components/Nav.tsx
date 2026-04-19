'use client';
import { useEffect, useState } from 'react';
import { PulsingDot } from './primitives/PulsingDot';
import { BracketedButton } from './primitives/BracketedButton';

const NAV_LINKS = [
  { label: 'Architecture', href: '#architecture' },
  { label: 'How',          href: '#how' },
  { label: 'AI',           href: '#ai' },
  { label: 'Demo',         href: '#demo' },
  { label: 'Spec',         href: '#specs' },
  { label: 'FAQ',          href: '#faq' },
];

/**
 * Floating, inset, scroll-contracting nav.
 * Mechanism lifted directly from aliaskit/Navigation.tsx — width shrinks
 * from min(1200px, calc(100% - 2rem)) to min(760px, calc(100% - 2rem))
 * past 80px scroll with a 500ms cubic-bezier transition.
 */
export function Nav() {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 80);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <>
      <header
        className="fixed left-0 right-0 top-4 z-40 mx-auto"
        style={{
          width: scrolled
            ? 'min(760px, calc(100% - 2rem))'
            : 'min(1200px, calc(100% - 2rem))',
          transition: 'width 500ms cubic-bezier(0.22, 1, 0.36, 1)',
        }}
      >
        <nav
          className="flex items-center justify-between border px-4 py-2.5 sm:px-5"
          style={{
            background: 'rgba(10, 13, 11, 0.8)',
            backdropFilter: 'blur(24px)',
            WebkitBackdropFilter: 'blur(24px)',
            borderColor: 'var(--color-border)',
            borderRadius: 'var(--radius-panel)',
          }}
        >
          {/* Left: wordmark + status */}
          <a
            href="#"
            className="flex items-center gap-3"
            aria-label="TacNet — top of page"
          >
            <span
              className="font-semibold"
              style={{
                color: 'var(--color-text)',
                fontSize: '15px',
                letterSpacing: '-0.01em',
              }}
            >
              TacNet
            </span>
            <span className="hidden sm:inline-flex">
              <PulsingDot size="sm" label="Operational" />
            </span>
          </a>

          {/* Center: links — hidden on mobile, hidden when contracted */}
          <div
            className="hidden items-center gap-6 lg:flex"
            style={{
              opacity: scrolled ? 0 : 1,
              visibility: scrolled ? 'hidden' : 'visible',
              transition: 'opacity 200ms ease',
            }}
          >
            {NAV_LINKS.map((l) => (
              <a
                key={l.href}
                href={l.href}
                className="text-[11px] uppercase tracking-[0.12em] transition-colors hover:text-[color:var(--color-text)]"
                style={{
                  color: 'var(--color-text-muted)',
                  fontFamily: 'var(--font-mono)',
                }}
              >
                {l.label}
              </a>
            ))}
          </div>

          {/* Right: CTAs */}
          <div className="hidden items-center gap-3 sm:flex">
            <BracketedButton
              variant="ghost"
              size="sm"
              href="https://github.com/Nalin-Atmakur/YC-hack"
              ariaLabel="GitHub repository"
            >
              GitHub
            </BracketedButton>
            <BracketedButton variant="primary" size="sm" href="#demo">
              Watch Demo →
            </BracketedButton>
          </div>

          {/* Mobile: hamburger */}
          <button
            type="button"
            className="sm:hidden"
            onClick={() => setMenuOpen((v) => !v)}
            aria-label={menuOpen ? 'Close menu' : 'Open menu'}
            aria-expanded={menuOpen}
            style={{
              color: 'var(--color-text)',
              fontFamily: 'var(--font-mono)',
              fontSize: '14px',
            }}
          >
            {menuOpen ? '×' : '≡'}
          </button>
        </nav>
      </header>

      {/* Mobile menu overlay */}
      {menuOpen && (
        <div
          className="fixed inset-x-4 top-20 z-40 border p-6 sm:hidden"
          style={{
            background: 'rgba(10, 13, 11, 0.95)',
            backdropFilter: 'blur(24px)',
            borderColor: 'var(--color-border)',
          }}
        >
          <ul className="flex flex-col gap-5">
            {NAV_LINKS.map((l) => (
              <li key={l.href}>
                <a
                  href={l.href}
                  onClick={() => setMenuOpen(false)}
                  className="text-[13px] uppercase tracking-[0.12em]"
                  style={{
                    color: 'var(--color-text)',
                    fontFamily: 'var(--font-mono)',
                  }}
                >
                  {l.label}
                </a>
              </li>
            ))}
          </ul>
          <div className="mt-6 flex flex-col gap-3">
            <BracketedButton variant="ghost" size="sm" href="https://github.com/Nalin-Atmakur/YC-hack">
              GitHub
            </BracketedButton>
            <BracketedButton variant="primary" size="sm" href="#demo">
              Watch Demo →
            </BracketedButton>
          </div>
        </div>
      )}
    </>
  );
}
