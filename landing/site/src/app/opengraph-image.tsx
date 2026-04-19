import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const alt = 'TacNet — Voice. Mesh. Offline.';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

/** Dynamically generated Open Graph image. 1200×630. */
export default function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          background: '#0B0B0C',
          color: '#ECEAE4',
          fontFamily: 'sans-serif',
          padding: 72,
          position: 'relative',
        }}
      >
        {/* Inset border */}
        <div
          style={{
            position: 'absolute',
            inset: 24,
            border: '1px solid rgba(236,234,228,0.12)',
          }}
        />

        {/* Grid overlay */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            backgroundImage:
              'linear-gradient(to right, rgba(236,234,228,0.04) 1px, transparent 1px), linear-gradient(to bottom, rgba(236,234,228,0.04) 1px, transparent 1px)',
            backgroundSize: '48px 48px',
          }}
        />

        {/* Top row */}
        <div
          style={{
            position: 'relative',
            display: 'flex',
            alignItems: 'center',
            gap: 16,
          }}
        >
          <div
            style={{
              width: 14,
              height: 14,
              borderRadius: 999,
              background: '#E8C547',
            }}
          />
          <div
            style={{
              color: '#8A8A85',
              fontSize: 22,
              letterSpacing: '0.2em',
              textTransform: 'uppercase',
            }}
          >
            Operational
          </div>
          <div
            style={{
              marginLeft: 'auto',
              color: '#8A8A85',
              fontSize: 22,
              letterSpacing: '0.12em',
              textTransform: 'uppercase',
            }}
          >
            TacNet · v0.4
          </div>
        </div>

        {/* Tag */}
        <div
          style={{
            position: 'relative',
            marginTop: 64,
            color: '#8A8A85',
            fontSize: 24,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
          }}
        >
          [ Offline-First Tactical Comms ]
        </div>

        {/* H1 */}
        <div
          style={{
            position: 'relative',
            marginTop: 28,
            fontSize: 140,
            fontWeight: 700,
            letterSpacing: '-0.04em',
            lineHeight: 0.98,
            display: 'flex',
          }}
        >
          Voice. Mesh. Offline.
        </div>

        {/* Subhead */}
        <div
          style={{
            position: 'relative',
            marginTop: 32,
            fontSize: 26,
            color: '#8A8A85',
            lineHeight: 1.3,
            maxWidth: 900,
          }}
        >
          Every phone runs Gemma 4 on-device and compacts its children&rsquo;s transmissions as summaries that climb the command tree.
        </div>

        {/* Footer row */}
        <div
          style={{
            position: 'relative',
            marginTop: 'auto',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            color: '#5A5A57',
            fontSize: 20,
            letterSpacing: '0.1em',
            textTransform: 'uppercase',
          }}
        >
          <div>YC × Cactus × Gemma 4 · 2025</div>
          <div>github.com/Nalin-Atmakur/YC-hack</div>
        </div>
      </div>
    ),
    { ...size },
  );
}
