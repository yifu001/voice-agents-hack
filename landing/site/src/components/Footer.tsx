import { footer } from '@/content/copy';

const ASCII_TREE = `         ┌──[ COMMANDER ]──┐
         │                 │
   [ ALPHA LEAD ]     [ BRAVO LEAD ]
         │
   [ ALPHA-1 ]`;

export function Footer() {
  return (
    <footer
      className="border-t"
      style={{
        borderColor: 'rgba(236, 234, 228, 0.08)',
        background: 'var(--color-bg)',
      }}
    >
      <div className="mx-auto max-w-[1200px] px-6 py-14 sm:px-10 lg:px-14">
        <div className="grid gap-12 lg:grid-cols-[1.2fr_1fr]">
          {/* Left */}
          <div>
            {/* Custom sign-off mark — replaces the duplicate pulsing-dot the
                nav already shows. Reads as an end-stamp on a tactical doc. */}
            <div className="flex items-center gap-3">
              <span
                className="display-tight"
                style={{
                  color: 'var(--color-text)',
                  fontSize: 17,
                  fontWeight: 600,
                }}
              >
                TacNet
              </span>
              <span
                aria-hidden
                className="inline-block h-px w-6"
                style={{ background: 'var(--color-border-hot)' }}
              />
              <span
                className="text-[10px] uppercase tracking-[0.22em]"
                style={{
                  color: 'var(--color-text-dim)',
                  fontFamily: 'var(--font-mono)',
                }}
              >
                end of transmission
              </span>
            </div>
            <p
              className="mt-4 max-w-md leading-[1.6]"
              style={{ color: 'var(--color-text-muted)', fontSize: 14 }}
            >
              {footer.tagline}
            </p>

            <pre
              className="mt-8 overflow-x-auto text-[11px] leading-[1.6]"
              style={{
                color: 'var(--color-text-dim)',
                fontFamily: 'var(--font-mono)',
              }}
            >
              {ASCII_TREE}
            </pre>
          </div>

          {/* Right — dossier */}
          <div>
            <div
              className="mb-4 text-[11px] uppercase tracking-[0.14em]"
              style={{
                color: 'var(--color-text-muted)',
                fontFamily: 'var(--font-mono)',
              }}
            >
              // dossier
            </div>
            <dl
              className="divide-y border-y"
              style={{ borderColor: 'var(--color-border)' }}
            >
              {footer.dossier.map(([k, v]) => (
                <div
                  key={k}
                  className="flex items-baseline justify-between gap-4 py-2.5"
                  style={{ borderColor: 'var(--color-border)' }}
                >
                  <dt
                    className="text-[11px] uppercase tracking-[0.12em]"
                    style={{
                      color: 'var(--color-text-muted)',
                      fontFamily: 'var(--font-mono)',
                    }}
                  >
                    {k}
                  </dt>
                  <dd
                    className="text-right text-[12px]"
                    style={{
                      color: 'var(--color-text)',
                      fontFamily: 'var(--font-mono)',
                    }}
                  >
                    {v}
                  </dd>
                </div>
              ))}
            </dl>
          </div>
        </div>

        {/* YC line */}
        <div
          className="mt-14 border-t pt-6 text-center"
          style={{ borderColor: 'var(--color-border)' }}
        >
          <span
            className="text-[11px]"
            style={{
              color: 'var(--color-text-dim)',
              fontFamily: 'var(--font-mono)',
              letterSpacing: '0.06em',
            }}
          >
            Built at the{' '}
            <a
              href="https://www.ycombinator.com/"
              className="hover:text-[color:var(--color-text-muted)]"
              target="_blank"
              rel="noopener noreferrer"
            >
              YC
            </a>{' '}
            &times;{' '}
            <a
              href="https://cactus.ai/"
              className="hover:text-[color:var(--color-text-muted)]"
              target="_blank"
              rel="noopener noreferrer"
            >
              Cactus
            </a>{' '}
            &times;{' '}
            <a
              href="https://deepmind.google/models/gemma/"
              className="hover:text-[color:var(--color-text-muted)]"
              target="_blank"
              rel="noopener noreferrer"
            >
              Gemma 4
            </a>{' '}
            hackathon &middot; 2025
          </span>
        </div>
      </div>
    </footer>
  );
}
