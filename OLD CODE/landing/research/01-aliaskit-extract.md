# AliasKit — visual & aesthetic extract

Reference: `/Users/nalinatmakur/Documents/Projects/aliaskit/implementation/`

## Stack in use
- **Next.js 16.2.1** (App Router, `'use client'` islands)
- **React 19.2.4**
- **Tailwind CSS v4** + `@tailwindcss/postcss`
- **Three.js 0.170** + `@react-three/fiber` 9.5 + `@react-three/postprocessing` 3.0 — for the dither/ASCII hero effects
- **next-mdx-remote 6.0** (docs/blog)
- **shiki 4.0** (code syntax)
- No shadcn / no Radix — components are hand-rolled
- Icons: inline SVG (no icon library)

## Tokens — `app/globals.css`

```
--color-bg-app:          #0C0C0C
--color-bg-surface:      #161616
--color-bg-elevated:     #1E1E1E
--color-accent:          #6366F1     /* indigo */
--color-text-primary:    #EDEDED
--color-text-secondary:  #888888
--color-text-tertiary:   #555555
--color-border-subtle:   #232323
--color-border-default:  #2E2E2E
--color-status-active:   #22C55E
--color-status-error:    #EF4444
--radius-panel:          2px
--radius-button:         2px
```

Fonts: **Space Grotesk** (display), **Outfit** (body), **JetBrains Mono** (code).

## Landing structure — `app/page.tsx`
1. Navigation (fixed, inset, contracts on scroll)
2. DitherBackground (Three.js shader — subtle noise)
3. Hero (headline + code window with tabs + twin CTAs)
4. WorksWithStrip (partner logos)
5. StatsBand (big mono numerals — "12 / <1s / 60+")
6. FeatureCards (6 tabbed feature columns)
7. Agent Payments, How It Works, Use Cases, Security Strip, Standards, Trust Band
8. Pricing (4-col grid)
9. Integrations, FAQ, CTA, Footer + ASCII footer

Each section wrapped in `SectionFrame.tsx` with optional dot/grid backgrounds.

## Distinctive details to borrow
- **Inset page border** on desktop: `sm:border` + `rgba(255,255,255,0.06)` on the whole `<main>` — frames the content like a document.
- **Vertical grid rails** 1px at `rgba(255,255,255,0.06)`, hidden on mobile.
- **Code window stacked-depth effect**: 3 overlapping divs with `translate-x-3/y-2` → `translate-x-1.5/y-1` → full content, each with progressively darker borders `#1a1a1a → #141414 → #232323`, plus a top glow line `gradient-to-r from-transparent via-[#333] to-transparent`.
- **Nav contracts on scroll**: width transitions from `min(1200px, 100% - 2rem)` to `min(720px, 100% - 2rem)` on 500ms cubic-bezier.
- **Dot background**: `radial-gradient(rgba(255,255,255,0.05) 1px, transparent 0)` @ 16px.
- **Grid background**: horizontal + vertical linear-gradients, `rgba(255,255,255,0.03)` @ 48px.
- **Section corner dots**: 3px circles at top-left/top-right at `rgba(255,255,255,0.2)`.
- **Fade-in-up stagger**: `.landing-stagger-1/2/3` with 40/120/200ms delays. `prefers-reduced-motion: reduce` kills it all.

## Code-window syntax palette (worth mimicking)
- Strings `#98C379` green
- Keywords `#C678DD` purple
- Numbers `#D19A66` orange
- Comments `#555555`
- Default identifiers `#E2E8F0`
- Red `#E06C75` for `MUST` / `DO NOT` etc.
