import { BracketedButton } from './primitives/BracketedButton';
import { GridBackground } from './primitives/GridBackground';
import { cta } from '@/content/copy';

export function CTA() {
  return (
    <section
      className="relative border-t"
      style={{ borderColor: 'rgba(236, 234, 228, 0.08)' }}
    >
      <GridBackground size={48} opacity={0.04} />
      <div className="relative mx-auto max-w-[1200px] px-6 py-24 text-center sm:px-10 sm:py-32 lg:px-14">
        <h2
          className="mx-auto max-w-2xl font-semibold"
          style={{
            color: 'var(--color-text)',
            fontSize: 'clamp(2rem, 4.2vw + 0.5rem, 3.5rem)',
            letterSpacing: '-0.02em',
            lineHeight: 1.05,
          }}
        >
          {cta.title}
        </h2>
        <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
          <BracketedButton variant="primary" href="#demo">
            {cta.primary}
          </BracketedButton>
          <BracketedButton variant="ghost" href="#architecture">
            {cta.secondary}
          </BracketedButton>
        </div>
      </div>
    </section>
  );
}
