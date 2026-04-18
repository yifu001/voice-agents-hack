'use client';

import { useState } from 'react';
import { SectionFrame } from './primitives/SectionFrame';
import { BracketedButton } from './primitives/BracketedButton';
import { IOSScreen, type ScreenKind } from './IOSScreen';
import { demo } from '@/content/copy';

const SCREENS: Array<{
  kind: ScreenKind;
  label: string;
  annotation: string;
}> = [
  {
    kind: 'live',
    label: 'Live Feed',
    annotation:
      "Transcripts from siblings and parent arrive as BROADCASTs. Compaction output from this node's Gemma 4 appears beneath, tagged and routed upward.",
  },
  {
    kind: 'tree',
    label: 'Tree View',
    annotation:
      'The command hierarchy with per-node claim status. Red = claimed, green = open. Drag-and-drop reparenting works in place for the organiser.',
  },
  {
    kind: 'flow',
    label: 'Data Flow',
    annotation:
      'Full transparency over the on-device model: incoming transcripts, processing state with latency + compression ratio, outgoing compaction summary.',
  },
  {
    kind: 'map',
    label: 'Map',
    annotation:
      'GPS auto-embedded in every message envelope. The root commander sees all claimed nodes on a shared map without any cloud tile service.',
  },
];

export function Demo() {
  const [active, setActive] = useState<ScreenKind>('live');
  const screen = SCREENS.find((s) => s.kind === active)!;

  return (
    <SectionFrame
      id="demo"
      eyebrow={demo.eyebrow}
      title={demo.title}
      intro={<p>{demo.body}</p>}
    >
      {/* Video */}
      <div className="mt-8">
        <VideoSurface />
      </div>

      {/* Screens carousel */}
      <div className="mt-16">
        <div
          className="mb-6 text-[11px] uppercase tracking-[0.14em]"
          style={{
            color: 'var(--color-text-muted)',
            fontFamily: 'var(--font-mono)',
          }}
        >
          // the four screens
        </div>
        <div className="grid gap-10 lg:grid-cols-[1fr_1.4fr]">
          {/* Tabs + annotation */}
          <div className="order-2 lg:order-1">
            <div className="flex flex-col gap-px">
              {SCREENS.map((s) => (
                <button
                  key={s.kind}
                  type="button"
                  onClick={() => setActive(s.kind)}
                  aria-pressed={active === s.kind}
                  className="flex items-baseline gap-4 border px-5 py-4 text-left transition-colors"
                  style={{
                    background:
                      active === s.kind ? 'var(--color-elevated)' : 'var(--color-surface)',
                    borderColor:
                      active === s.kind ? 'var(--color-accent)' : 'var(--color-border)',
                  }}
                >
                  <span
                    className="text-[11px] uppercase tracking-[0.14em]"
                    style={{
                      color: active === s.kind
                        ? 'var(--color-accent)'
                        : 'var(--color-text-dim)',
                      fontFamily: 'var(--font-mono)',
                      width: 28,
                    }}
                  >
                    {String(SCREENS.indexOf(s) + 1).padStart(2, '0')}
                  </span>
                  <span>
                    <span
                      className="block font-semibold"
                      style={{
                        color: 'var(--color-text)',
                        fontSize: 16,
                        letterSpacing: '-0.01em',
                      }}
                    >
                      {s.label}
                    </span>
                    {active === s.kind && (
                      <span
                        className="mt-2 block leading-[1.55]"
                        style={{
                          color: 'var(--color-text-muted)',
                          fontSize: 13,
                        }}
                      >
                        {s.annotation}
                      </span>
                    )}
                  </span>
                </button>
              ))}
            </div>
          </div>

          {/* Preview phone */}
          <div className="order-1 flex items-start justify-center lg:order-2">
            <div
              className="relative overflow-hidden"
              style={{
                width: 300,
                aspectRatio: '280 / 580',
                background: '#050705',
                border: '1px solid var(--color-border-hot)',
                borderRadius: 34,
                padding: 8,
                boxShadow: '0 30px 60px -20px rgba(0,0,0,0.6)',
              }}
            >
              <div
                aria-hidden
                className="absolute left-1/2 top-2 z-10 -translate-x-1/2"
                style={{
                  width: 90,
                  height: 18,
                  background: '#050705',
                  borderRadius: 12,
                }}
              />
              <div
                className="relative h-full w-full overflow-hidden"
                style={{
                  background: 'var(--color-bg)',
                  borderRadius: 26,
                }}
              >
                <IOSScreen kind={screen.kind} />
              </div>
            </div>
          </div>
        </div>
      </div>
    </SectionFrame>
  );
}

/**
 * Video surface. The real cinematic video ships into
 * /public/video/demo-hero.mp4 (+ .webm, .en.vtt, poster).
 *
 * Until then, this is a graceful placeholder with a manual
 * "Video coming soon" state.
 */
function VideoSurface() {
  return (
    <div
      className="relative aspect-video w-full overflow-hidden border"
      style={{
        borderColor: 'var(--color-border)',
        background: 'var(--color-surface)',
      }}
    >
      {/* Placeholder composition */}
      <div className="absolute inset-0 flex flex-col items-center justify-center gap-6 p-10 text-center">
        {/* Grid overlay */}
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{
            backgroundImage: `
              linear-gradient(to right,  rgba(184,255,44,0.04) 1px, transparent 1px),
              linear-gradient(to bottom, rgba(184,255,44,0.04) 1px, transparent 1px)
            `,
            backgroundSize: '48px 48px',
          }}
        />
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{
            background:
              'radial-gradient(ellipse at center, rgba(184,255,44,0.1), transparent 60%)',
          }}
        />

        <div className="relative flex flex-col items-center gap-5">
          <span
            className="text-[11px] uppercase tracking-[0.18em]"
            style={{
              color: 'var(--color-text-muted)',
              fontFamily: 'var(--font-mono)',
            }}
          >
            [ Cinematic demo · supplied separately ]
          </span>
          <div
            className="flex items-center justify-center"
            style={{
              width: 84,
              height: 84,
              borderRadius: '50%',
              background: 'var(--color-accent)',
              color: 'var(--color-bg)',
            }}
          >
            <svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
              <path d="M8 5v14l11-7z" />
            </svg>
          </div>
          <div
            className="max-w-md text-[15px] leading-[1.55]"
            style={{ color: 'var(--color-text-muted)' }}
          >
            The cinematic walkthrough drops into{' '}
            <code
              className="text-[12px]"
              style={{
                color: 'var(--color-accent)',
                fontFamily: 'var(--font-mono)',
              }}
            >
              /public/video/demo-hero.mp4
            </code>{' '}
            when the edit is finished. Captions ship alongside as{' '}
            <code
              className="text-[12px]"
              style={{
                color: 'var(--color-accent)',
                fontFamily: 'var(--font-mono)',
              }}
            >
              demo-hero.en.vtt
            </code>
            .
          </div>
          <div className="mt-2 flex gap-3">
            <BracketedButton variant="ghost" href="#architecture" size="sm">
              See Architecture →
            </BracketedButton>
          </div>
        </div>
      </div>

      {/* The real player is commented out until assets land.
          Uncomment and it "just works":

      <video
        className="h-full w-full object-cover"
        controls
        playsInline
        preload="metadata"
        poster="/video/demo-hero-poster.jpg"
      >
        <source src="/video/demo-hero.webm" type="video/webm" />
        <source src="/video/demo-hero.mp4"  type="video/mp4"  />
        <track kind="captions" src="/video/demo-hero.en.vtt" srcLang="en" default />
      </video>
      */}
    </div>
  );
}
