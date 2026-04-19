import { BracketedButton } from './primitives/BracketedButton';
import { PulsingDot } from './primitives/PulsingDot';
import { GridBackground } from './primitives/GridBackground';
import { DeviceMock } from './DeviceMock';
import { hero } from '@/content/copy';

/**
 * Hero — the single biggest first-impression change in this refresh.
 *
 * What's new vs. the old hero:
 *  - Topographic underlay: a 96px coarse grid layered over the existing
 *    48px fine grid, with a subtle CRT scanline pass. Reads as a chart
 *    table, not a generic "tech grid".
 *  - Coordinate / timestamp readout in the corner — a bespoke detail
 *    that sells the tactical-instrument tone in one glance.
 *  - Headline uses Funnel Display with a small horizontal rule under it,
 *    like a stenciled mission patch.
 *  - Halo behind the device is now warm amber + dim cyan rim instead of
 *    the previous bright lime, so the device reads as illuminated by
 *    a phosphor lamp rather than a highlighter.
 */
export function Hero() {
  return (
    <section className="relative overflow-hidden">
      {/* Layered backgrounds: coarse + fine grid + scanlines. */}
      <div aria-hidden className="bg-grid-96 pointer-events-none absolute inset-0" />
      <GridBackground size={48} opacity={0.022} />
      <div aria-hidden className="bg-scanlines pointer-events-none absolute inset-0" />

      {/* Corner readout — top right, the bespoke "instrument" stamp */}
      <div
        aria-hidden
        className="absolute right-6 top-6 z-10 hidden items-center gap-2 border px-2.5 py-1.5 sm:right-10 sm:top-10 sm:flex lg:right-14"
        style={{
          borderColor: 'var(--color-border)',
          background: 'rgba(11, 11, 12, 0.55)',
          backdropFilter: 'blur(8px)',
        }}
      >
        <span
          className="inline-block h-1 w-1 rounded-full"
          style={{ background: 'var(--color-signal-cyan)' }}
        />
        <span
          className="text-[9.5px] uppercase tracking-[0.22em]"
          style={{
            color: 'var(--color-text-muted)',
            fontFamily: 'var(--font-mono)',
          }}
        >
          GRID 47N · 12E
        </span>
        <span
          className="mx-1 inline-block h-2.5 w-px"
          style={{ background: 'var(--color-border-hot)' }}
        />
        <span
          className="text-[9.5px] uppercase tracking-[0.22em]"
          style={{
            color: 'var(--color-text-muted)',
            fontFamily: 'var(--font-mono)',
          }}
        >
          14:32:07Z
          <span className="blink-cursor ml-0.5">_</span>
        </span>
      </div>

      <div className="relative mx-auto max-w-[1200px] px-6 pb-24 pt-28 sm:px-10 sm:pt-36 lg:px-14 lg:pt-40">
        <div className="grid items-center gap-12 lg:grid-cols-[1.2fr_1fr]">
          {/* Text column */}
          <div>
            <div className="flex items-center gap-5">
              <PulsingDot tone="amber" label="Operational" />
              <span
                className="text-[10.5px] uppercase tracking-[0.2em]"
                style={{
                  color: 'var(--color-text-dim)',
                  fontFamily: 'var(--font-mono)',
                }}
              >
                · Public Demo · v0.4
              </span>
            </div>

            <div className="mt-10">
              <span
                className="text-[10.5px] uppercase tracking-[0.2em]"
                style={{
                  color: 'var(--color-text-muted)',
                  fontFamily: 'var(--font-mono)',
                }}
              >
                {hero.tag}
              </span>
            </div>

            <h1
              className="display-tight mt-6 leading-[0.95]"
              style={{
                fontSize: 'clamp(2.75rem, 7vw + 1rem, 6.5rem)',
                color: 'var(--color-text)',
                fontWeight: 500,
              }}
            >
              {hero.title}
            </h1>

            {/* Stenciled rule under headline */}
            <div className="mt-6 flex items-center gap-3">
              <span
                aria-hidden
                className="block h-px w-16"
                style={{ background: 'var(--color-border-hot)' }}
              />
              <span
                className="text-[9.5px] uppercase tracking-[0.24em]"
                style={{
                  color: 'var(--color-text-dim)',
                  fontFamily: 'var(--font-mono)',
                }}
              >
                Field instrument · TacNet
              </span>
            </div>

            <p
              className="mt-8 max-w-xl text-base leading-[1.65] sm:text-lg"
              style={{ color: 'var(--color-text-muted)' }}
            >
              {hero.subhead}
            </p>

            <div className="mt-10 flex flex-wrap items-center gap-4">
              <BracketedButton variant="primary" href="#demo">
                {hero.primaryCta}
              </BracketedButton>
              <BracketedButton variant="link" href="#architecture">
                {hero.secondaryCta}
              </BracketedButton>
            </div>
          </div>

          {/* Visual column */}
          <div className="relative flex items-center justify-center">
            {/* Warm phosphor halo (amber) + cool rim (cyan) — duotone */}
            <div
              aria-hidden
              className="absolute inset-0 -z-10"
              style={{
                background:
                  'radial-gradient(circle at 60% 40%, rgba(232, 197, 71, 0.07), transparent 55%)',
              }}
            />
            <div
              aria-hidden
              className="absolute inset-0 -z-10"
              style={{
                background:
                  'radial-gradient(circle at 30% 75%, rgba(123, 182, 217, 0.05), transparent 50%)',
              }}
            />
            <DeviceMock />
          </div>
        </div>
      </div>
    </section>
  );
}
