import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const size = { width: 64, height: 64 };
export const contentType = 'image/png';

/** Favicon: lime square with a tiny mesh motif. */
export default function Icon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          background: '#0A0D0B',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          position: 'relative',
          border: '2px solid #B8FF2C',
        }}
      >
        <div
          style={{
            width: 8,
            height: 8,
            background: '#B8FF2C',
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
            background: '#B8FF2C',
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
            background: '#B8FF2C',
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
