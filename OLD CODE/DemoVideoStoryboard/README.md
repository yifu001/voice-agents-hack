# TacNet Demo — 10-Shot Storyboard (60 s total)

A 1-minute cinematic demo of TacNet in a 10-man Tier-1 CQB hostage-rescue raid, broken into ten 6-second beats. Each snapshot file describes one hero frame: timecode, camera angle, action in frame, the diegetic HUD overlay that floats on top of the image, audio, and an image-generator prompt.

---

## Visual Style Bible (applied to every snapshot)

Every frame must read as part of the same film. The bible below is authoritative; each snapshot inherits it verbatim.

### Aspect, Format, Grade
- 16:9 frame, composed for a 2.39:1 anamorphic letterbox crop.
- 4K source, subtle 35mm film grain, gate weave off, no chromatic aberration.
- Color: teal-green shadows, warm amber highlights (tungsten muzzle flash, HUD alerts), crushed blacks with a faint green lift, midtones desaturated ~20%.
- Anamorphic horizontal flares on muzzle fire, breach sparks, HUD glyphs, and IR strobes.
- Slight atmospheric haze / volumetric light picking up NVG IR beams.

### Time, Weather, Location (identical in every external shot)
- 0300 hours, moonless overcast sky with thin high clouds. No starlight. Very dark.
- Dry and cold, ~8°C. Hard-packed dirt ground with ankle-height dust drift instead of fog. No rain.
- Remote rural outskirts — isolated high-value target. Evocative of the Abbottabad compound (Operation Neptune Spear): a fortified walled residential compound dropped into farm/scrub country, no neighboring buildings within 200 m.
- ONE specific target used in every external shot — the **Compound** (call-sign `AC-1`):
  - ~1 acre irregular rectangular footprint.
  - **Outer walls:** 14–18 ft weathered concrete perimeter walls topped with rusted razor-wire coils.
  - **Gates:** wide steel vehicle gate on the south face (one bare incandescent bulb above it throwing a weak orange circle on the dirt), a narrow pedestrian gate on the west face.
  - **Main residence (A1):** three-story concrete-and-stucco building set in the north half of the courtyard. Weathered cream paint, small deep-set barred windows, flat roof with waist-high parapet privacy walls, one dim amber bulb behind a curtained 2nd-floor window on the northwest corner. Interior staircase, one rooftop stair-hatch.
  - **Guesthouse / annex (A2):** separate single-story cinderblock structure in the southwest corner of the courtyard, flat roof, one metal door.
  - **Inner courtyard:** packed dirt, a small weathered vegetable patch, a rusted diesel generator shed, a chicken coop, a battered white Toyota Hilux parked askew near A1.
  - **Approach terrain:** a narrow unpaved road bisected by irrigation ditches, adjacent walled crop plots with dry grass, scattered olive and poplar trees in a ragged tree line along the east, a long low dry-stone wall along the west, terraced farm plots sloping away to the south.
  - **Horizon context:** distant terraced farmland, a dusty mountain ridge line in the far background.
  - No streetlights, no street signs, no house number. This is meant to read as a remote, deliberately isolated compound.

### Sniper Kit Exception
- The 10th operator (Sniper, callsign `OVER`) is positioned far outside the compound on elevated terrain (distant rooftop / ridgeline, typically 250–400 m out) and carries a suppressed **Geissele Super Duty MK228 / Mk22 MRAD DMR variant** instead of the 10.3" M4 — all other kit remains sterile and identical to the assault element. All other nine operators carry the standard URG-I M4 loadout from the Style Bible above.

### Team Composition (10 operators, sterile Tier-1 loadout)
- **Element Alpha** (5) stacked on the front door: Squad Leader (SL), Team Lead A (TL-A), two Alpha operators (A1, A2), and the Breacher.
- **Element Bravo** (4) moving around the east side to the rear door: Team Lead B (TL-B), two Bravo operators (B1, B2), and the Medic.
- **Overwatch** (1): Sniper prone on the rooftop of the single-story building directly across the street.

### Operator Kit (identical on all 10, sterile — no patches, no flag)
- Crye Precision G3 combat uniform, multicam-black.
- Ops-Core FAST SF ballistic helmet with IR strobe pulsing on the back plate.
- L3Harris GPNVG-18 four-tube panoramic night vision (flipped up on helmet unless actively clearing a room; flipped down during entry and contact).
- Peltor ComTac headset with rigid boom mic, clear ballistic eye-pro.
- Crye JPC 2.0 plate carrier with dangler pouch, triple M4 mag shingle, admin pouch on the left.
- Safariland drop-leg holster with a Glock 19.
- **Primary weapon (all):** 10.3" URG-I-pattern M4 with a SureFire SOCOM Mini 2 suppressor, Geissele Super Modular Rail, Vortex Razor 1-6x LPVO, Steiner DBAL-I2 IR laser/illuminator, Magpul MS4 padded sling.
- Tan Mechanix M-Pact gloves. Salomon Forces boots.
- **Only tell between operators:** the Squad Leader has a single orange IR chemlight taped to the back of his helmet.

### Diegetic HUD — Holographic Overlay (CRITICAL: new rule)
- HUD is NOT a split-screen panel. It is a **transparent holographic AR layer projected onto the image**, as if rendered by the viewer's optic or drone sensor.
- Typography: thin monospace (Berkeley Mono / Input Mono), ALL CAPS, +20 tracking, subtle CRT scanlines, micro glitch every ~2 s, Gaussian bloom, 3–5% darkened background only behind glyph footprints for legibility.
- Color key:
  - `[SOLDIER → AI]` raw voice input — luminous pale green `#7FFFA9`
  - `[AI ROUTING]` process / metadata — dim amber `#FFB347`
  - `[LEADER EARPIECE]` compacted summary — bright cyan-white `#EAFBFF` with heavier bloom and a thin rule above and below
- Layout rules (apply in every shot):
  - HUD never covers a face, muzzle, or the hostage.
  - Text floats along the upper or lower thirds, respecting a 5% safe margin.
  - A small command-tree micrographic (10 nodes) sits in the **top-right corner** of every shot as a constant reference; nodes pulse color per that shot's event.
  - A thin timestamp `03:0X:XX` sits **bottom-left**, incrementing shot to shot.
  - TacNet wordmark lockup discreet **bottom-right**, 40% opacity.

### Camera Language
- **Drone bird's-eye:** gimbal-stabilized, 24mm-equivalent, 2-stop ND, very slow downward dolly or orbit; no jerk. Used for 01, 04 (wide), 07, 10.
- **GoPro helmet-cam:** handheld, 16mm-equivalent, 1–2° shake, mild fisheye, rolling-shutter smear on muzzle flash, visible helmet-rim vignette. Used for 03, 05 (cut-ins), 08.
- **Thermal scope POV:** white-hot palette, reticle, circular scope vignette. Used for 02.
- **Reaction close-up:** 85mm, T1.5, shallow DOF, soft skin roll-off. Used for 06, 09.

### SFX / Mix Language (for live production, not image gen)
- Suppressed M4 fire: `pfft-pfft` with dry tail.
- Clean neutral synthesized TTS for every earpiece line, one consistent voice, slightly warm — not robotic.
- **Defining audio cut at 0:26–0:30:** four overlapping whispered operator voices duck hard under one bright AI summary line. That edit is the entire product pitch.
- No musical score until the final tag at 0:58.

### Prohibitions
- No emoji, no unit patches, no national flags, no visible logos except the TacNet wordmark in the bottom-right lockup.
- No gore, no blood sprays. Hits are implied via muzzle flash, body fall, and micro-reaction.
- No radio static bursts — TacNet is supposed to feel clean and composed.

---

## Shot Index

| # | Timecode | Beat | Lens / Angle |
|---|----------|------|--------------|
| 01 | 0:00 – 0:06 | Cold open + tree topology | Drone bird's-eye |
| 02 | 0:06 – 0:12 | Sniper overwatch check-in | Thermal scope POV |
| 03 | 0:12 – 0:18 | Stack on breach point | GoPro helmet-cam #1 |
| 04 | 0:18 – 0:24 | Breach / door blows | Wide low-angle at door |
| 05 | 0:24 – 0:30 | 4 voices → 1 clean line (money shot) | OTS squad leader + HUD |
| 06 | 0:30 – 0:36 | Leader decides, reroutes | Close-up squad leader face |
| 07 | 0:36 – 0:42 | Formation reconfigures | Drone bird's-eye |
| 08 | 0:42 – 0:48 | Upstairs contact, tango down | GoPro helmet-cam #5 |
| 09 | 0:48 – 0:54 | Hostage secure, hood off | Medium on hostage |
| 10 | 0:54 – 1:00 | Exfil + end tag | Drone bird's-eye → black |

## Files in this folder

- `README.md` (this file)
- `DEMO_VIDEO_SCRIPT.md` — full 60-second shooting script (master document)
- `01_cold_open.md`
- `02_sniper_overwatch.md`
- `03_stack_breach_prep.md`
- `04_breach.md`
- `05_ai_compact_moneyshot.md`
- `06_leader_decides.md`
- `07_orders_pushdown.md`
- `08_upstairs_contact.md`
- `09_hostage_rescue.md`
- `10_exfil_endtag.md`

Total: 12 files.
