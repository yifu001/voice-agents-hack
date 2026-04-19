# landing/

Public landing site for TacNet.

- **Plan** → [`PLAN.md`](./PLAN.md) — full build spec, section-by-section.
- **Research** → [`research/`](./research/) — aesthetic extracts from aliaskit and defense-tech sites (Anduril, Saronic, Helsing, Shield AI, Palantir).

## Status

**Planning.** Locked: Palette A (tactical lime) + DM Sans / JetBrains Mono + subtle YC footer framing.

**Next.js scaffold is NOT yet in place.** A first attempt with `create-next-app` failed during `npm install` (disk-space induced `TAR_ENTRY_ERROR`) and the tool's abort cleanup removed the entire worktree's working tree. Files were recovered from git; landing/ docs were rewritten. Phase 1 should proceed with **manual scaffolding**, not `create-next-app`, and only once disk pressure is resolved (free ≥ 5 GB before `npm install`).

**Stack** (planned): Next.js 15 (App Router) · React 19 · Tailwind v4 · Three.js for ambient effects · SVG for the interactive mesh simulation.

**Not** a web version of the iOS app. The demo is a cinematic video + a scripted mesh simulation.

## Layout

```
landing/
├── PLAN.md            ← read first
├── README.md          this file
├── research/          aesthetic research notes
└── site/              ← Next.js project will live here (not yet scaffolded)
```
