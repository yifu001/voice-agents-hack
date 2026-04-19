# tacnet-site

Next.js 15 App Router project for the TacNet landing page.

Do not edit in isolation — the visual and content spec lives one directory up at [`../PLAN.md`](../PLAN.md).

## Run

```bash
cd landing/site
npm install      # pre-flight: `df -h /` should show ≥ 5 GB free
npm run dev      # http://localhost:3000
```

## Build

```bash
npm run build
npm run start
```

## Structure

```
src/
├── app/
│   ├── layout.tsx       fonts (DM Sans + JetBrains Mono) + grain overlay
│   ├── page.tsx         single-page composition
│   └── globals.css      tokens + utilities (Tailwind v4)
├── components/
│   └── primitives/      reusable low-level pieces
├── lib/                 mesh simulation + motion helpers
└── content/             copy drafts, FAQ, specs
```

## Tokens

Palette: Tactical lime (`--color-accent: #B8FF2C`).
Fonts: DM Sans + JetBrains Mono via `next/font/google`.
See `../PLAN.md` §2 and §8.4 for the full token table.
