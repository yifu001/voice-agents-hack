# Defense-tech visual research — synthesis

Sites reviewed: Palantir, Anduril, Helsing, Shield AI, Saronic, AliasKit.

## Shared visual language (the consensus)
1. **Dark base + ONE acid-green accent.** Anduril `#DFF140`, Shield AI `#9DFF20`, Saronic `#ACFF24`. No second bright color.
2. **Huge confident geometric sans.** Helvetica Now, DM Sans, custom cuts. Weight used structurally — Hairline → Black.
3. **Typography-first heroes.** Either just text on black, or text over full-bleed silent video. Nobody uses illustrated characters.
4. **Numbered capability sections** (Saronic 001–007). Feels like a dossier, not a marketing page.
5. **`clamp()` fluid type scales** tied to viewport.
6. **Mono fonts as metadata garnish** — labels, coordinates, timestamps, stats — never body copy.
7. **Minimal CTAs with arrow SVGs.** No gradients, no glows.
8. **Austere monochrome.** No glassmorphism, no dark→purple fades.
9. **Grain/noise overlays** at 3–5% opacity + **1px grid backgrounds** for texture without decoration.

## Font-stack per site

| Site | Display | Body | Mono |
|---|---|---|---|
| Anduril | Helvetica Now Display (Hairline → Black), Elios serif accents | Helvetica Now | — |
| Palantir | Inter-adjacent geometric sans | same | — |
| Helsing | Custom geometric with condensed display cut | custom | sparingly |
| Shield AI | **DM Sans** | DM Sans | **IBM Plex Mono** |
| Saronic | Helvetica Neue-adjacent | same | — |
| AliasKit | Space Grotesk | Outfit | **JetBrains Mono** |

Defense-tech free-license pick that's proven in-category: **DM Sans** (Shield AI). Paid fonts (Helvetica Now, custom Helsing cuts) are off-limits for a hackathon project.

## Per-site signals worth lifting

| Site | Lift |
|---|---|
| **Saronic** | Numbered sections 001–007. Inline-SVG geometric grid in hero. Concentric-circle HUD. Sticky horizontal dark nav with text-only links. Sonar-green CTA with midnight text + right-arrow SVG. |
| **Anduril** | Full-bleed silent video hero. Grain + Perlin noise overlay. Lime progress bar rotated 3° (but we probably skip — too brand-owned). |
| **Helsing** | Editorial layout. Heavy negative space. Mono metadata labels. CTA is a text link with arrow, not a filled button. |
| **Shield AI** | `clamp()` fluid scaling. DM Sans + IBM Plex Mono. Lime-fill-on-hover-inverts-to-black pattern. |
| **AliasKit** | Stacked-depth code window. Section frame with corner dots. Fade-in-up stagger with `prefers-reduced-motion`. Dither background as ambient texture. |
| **Palantir** | Numbered progressive sections. Award/credibility pills. (Least useful — it's more enterprise-SaaS than defense-austere.) |

## Traps to avoid (kitsch checklist)
- Camo patterns, dog tags, crosshairs, stencil fonts → GI Joe.
- Red-on-black "alert" bars with no real signal → edgy startup.
- Chrome / brushed-steel gradients → 2008 trade-show booth.
- Faux-Cyrillic or binary in headings.
- Purple/blue cyberpunk gradients → belongs to crypto.
- "MILSPEC / TIER 1 / WARFIGHTER" tags → reads like merch.
- Neon glow/bloom on type → aged out by 2022.
- Lottie animations of soldiers/drones → always bad.
- Typewriter effects replaying on every scroll → fine once, nowhere else.
- "CLASSIFIED" strikethrough redaction gag → extremely overdone.
- Low-contrast dark-gray-on-black body copy failing WCAG → the actual kitsch.

## Winning formula for TacNet
Saronic's restraint + AliasKit's data-readout confidence + Anduril's cinematic grain, **minus any literal military iconography**. Weapons, uniforms, flags, and crosshairs are banned; evidence (code, mono data, diagrams) does the heavy lifting.
