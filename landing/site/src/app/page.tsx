import { Nav } from '@/components/Nav';
import { Hero } from '@/components/Hero';
import { DataBand } from '@/components/DataBand';
import { Problem } from '@/components/Problem';
import { Architecture } from '@/components/Architecture';
import { HowItWorks } from '@/components/HowItWorks';
import { AI } from '@/components/AI';
import { Demo } from '@/components/Demo';
import { Specs } from '@/components/Specs';
import { Security } from '@/components/Security';
import { FAQ } from '@/components/FAQ';
import { CTA } from '@/components/CTA';
import { Footer } from '@/components/Footer';

/**
 * TacNet landing page — full composition.
 * Spec: landing/PLAN.md §3 Information Architecture.
 */
export default function Home() {
  return (
    <>
      <Nav />
      <main
        className="relative"
        style={{ padding: 'clamp(0px, 2vw, 16px)' }}
      >
        {/* Inset page frame (the "margin design" — AliasKit lift) */}
        <div
          className="relative mx-auto max-w-[1400px] border"
          style={{ borderColor: 'var(--color-border)' }}
        >
          <Hero />
          <DataBand />
          <Problem />
          <Architecture />
          <HowItWorks />
          <AI />
          <Demo />
          <Specs />
          <Security />
          <FAQ />
          <CTA />
          <Footer />
        </div>
      </main>
    </>
  );
}
