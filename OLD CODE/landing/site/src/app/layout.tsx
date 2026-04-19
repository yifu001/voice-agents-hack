import type { Metadata } from 'next';
import { Funnel_Sans, Funnel_Display, IBM_Plex_Mono } from 'next/font/google';
import './globals.css';

/**
 * Type chain — chosen to escape the DM Sans / JetBrains Mono "every YC site"
 * stack. Funnel (Pangram-Pangram, 2024 release) has a distinctive squared
 * geometry that reads as engineered/instrumented rather than generic
 * neo-grotesque. IBM Plex Mono brings a slabby, "engineered" feel that
 * pairs well with Funnel and reads more like instrumentation than the
 * generic JetBrains/Geist mono stack everyone else uses.
 */
const funnelSans = Funnel_Sans({
  subsets: ['latin'],
  variable: '--font-funnel-sans',
  display: 'swap',
  weight: ['300', '400', '500', '600', '700'],
});

const funnelDisplay = Funnel_Display({
  subsets: ['latin'],
  variable: '--font-funnel-display',
  display: 'swap',
  weight: ['400', '500', '600', '700', '800'],
});

const plexMono = IBM_Plex_Mono({
  subsets: ['latin'],
  variable: '--font-plex-mono',
  display: 'swap',
  weight: ['400', '600', '700'],
});

export const metadata: Metadata = {
  title: 'TacNet — Voice. Mesh. Offline.',
  description:
    'A decentralised, offline-first tactical communication network that runs Gemma 4 on-device and compacts transmissions up a command tree. Zero servers. Zero cloud.',
  metadataBase: new URL('https://tacnet.example'),
  openGraph: {
    title: 'TacNet — Voice. Mesh. Offline.',
    description:
      'A decentralised, offline-first tactical communication network that runs Gemma 4 on-device and compacts transmissions up a command tree.',
    type: 'website',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="en"
      className={`${funnelSans.variable} ${funnelDisplay.variable} ${plexMono.variable}`}
    >
      <body className="relative min-h-screen antialiased">
        {/* Grain overlay — pinned, non-interactive */}
        <div
          aria-hidden
          className="bg-noise pointer-events-none fixed inset-0 z-50"
        />
        {children}
      </body>
    </html>
  );
}
