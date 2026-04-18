import { BracketedButton } from './primitives/BracketedButton';
import { PulsingDot } from './primitives/PulsingDot';
import { GridBackground } from './primitives/GridBackground';
import { DeviceMock } from './DeviceMock';
import { hero } from '@/content/copy';

export function Hero() {
  return (
    <section className="relative overflow-hidden">
      <GridBackground size={48} opacity={0.03} />

      <div className="relative mx-auto max-w-[1200px] px-6 pb-24 pt-28 sm:px-10 sm:pt-36 lg:px-14 lg:pt-40">
        <div className="grid items-center gap-12 lg:grid-cols-[1.2fr_1fr]">
          {/* Text column */}
          <div>
            <div className="flex items-center gap-5">
              <PulsingDot label="Operational" />
              <span
                className="text-[11px] uppercase tracking-[0.18em]"
                style={{
                  color: 'var(--color-text-dim)',
                  fontFamily: 'var(--font-mono)',
                }}
              >
                · Public Demo
              </span>
            </div>

            <div className="mt-10">
              <span
                className="text-[11px] uppercase tracking-[0.18em]"
                style={{
                  color: 'var(--color-text-muted)',
                  fontFamily: 'var(--font-mono)',
                }}
              >
                {hero.tag}
              </span>
            </div>

            <h1
              className="mt-6 font-semibold leading-[0.98]"
              style={{
                fontSize: 'clamp(2.75rem, 7vw + 1rem, 6.5rem)',
                letterSpacing: '-0.03em',
                color: 'var(--color-text)',
              }}
            >
              {hero.title}
            </h1>

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
            <div
              aria-hidden
              className="absolute inset-0 -z-10"
              style={{
                background:
                  'radial-gradient(circle at 60% 40%, rgba(184,255,44,0.08), transparent 60%)',
              }}
            />
            <DeviceMock />
          </div>
        </div>
      </div>
    </section>
  );
}
