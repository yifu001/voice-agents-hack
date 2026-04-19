import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const size = { width: 64, height: 64 };
export const contentType = 'image/png';

/**
 * Favicon — neutral charcoal square with a 3-node mesh motif.
 * Border + nodes use sand (the new CTA tone), so the favicon reads
 * as "etched plate" rather than the prior neon-lime mark.
 */
export default function Icon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          background: '#0B0B0C',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          position: 'relative',
          border: '2px solid #ECE4CE',
        }}
      >
        <div
          style={{
            width: 8,
            height: 8,
            background: '#ECE4CE',
            borderRadius: 999,
            position: 'absolute',
            top: 16,
            left: 28,
          }}
        />
        <div
          style={{
            width: 8,
            height: 8,
            background: '#ECE4CE',
            borderRadius: 999,
            position: 'absolute',
            bottom: 16,
            left: 14,
          }}
        />
        <div
          style={{
            width: 8,
            height: 8,
            background: '#ECE4CE',
            borderRadius: 999,
            position: 'absolute',
            bottom: 16,
            right: 14,
          }}
        />
      </div>
    ),
    { ...size },
  );
}
