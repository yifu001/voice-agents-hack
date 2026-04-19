interface GridBackgroundProps {
  size?: 16 | 24 | 48 | 64;
  opacity?: number; // 0..1
}

/** Absolute, aria-hidden 1px grid. Default 48px at 3% opacity. */
export function GridBackground({ size = 48, opacity = 0.03 }: GridBackgroundProps) {
  return (
    <div
      aria-hidden
      className="pointer-events-none absolute inset-0"
      style={{
        backgroundImage: `
          linear-gradient(to right,  rgba(236, 234, 228, ${opacity}) 1px, transparent 1px),
          linear-gradient(to bottom, rgba(236, 234, 228, ${opacity}) 1px, transparent 1px)
        `,
        backgroundSize: `${size}px ${size}px`,
      }}
    />
  );
}
