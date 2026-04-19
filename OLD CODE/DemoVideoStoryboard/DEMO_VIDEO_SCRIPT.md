# TacNet — 1-Minute Demo Video Script

**Concept:** US Army Ranger / Special Forces 10-person CQB hostage-rescue raid on a target house. TacNet's on-device SLM filters, routes, and summarizes team comms so the squad leader in the rear stack gets a clean, prioritized picture instead of chaotic radio chatter.

**Runtime:** 60 seconds
**Style:** Cinematic, multi-angle. Bird's-eye drone + GoPro helmet-cam + over-the-shoulder + HUD inserts. Half-screen text overlay on the left side showing the TacNet AI layer in action while the raid plays out on the right (or vice versa).
**Tone:** Tense, tactical, quiet. Suppressed M4 fire. No music until final beat.
**Color:** Desaturated night-ops teal/green with warm muzzle flashes.

---

## On-Screen Legend (for the overlay half of the frame)

All overlay text appears as a clean terminal-style HUD. Three lanes:

- `[SOLDIER → AI]` — raw voice into mic (what the operator actually says)
- `[AI ROUTING]` — what TacNet does with it (filter / compact / route)
- `[LEADER EARPIECE]` — the summarized line the squad leader actually hears

---

## Shot Breakdown

### 0:00 – 0:05 — Cold Open
- **Visual (right half):** Bird's-eye drone shot. Pitch-black suburban street at 0300. A 10-man stack flows silently along a wall toward a two-story target house. Night vision green tint.
- **Visual (left half / overlay):** TacNet logo resolves, then a tree topology graphic lights up — 1 squad leader, 2 team leads, 6 operators, 1 breacher, 1 sniper overwatch. Each node pulses as an AI agent spins up.
- **Overlay text:** `TACNET // 10 NODES ONLINE — OFFLINE BLE MESH`
- **Audio:** Wind. Distant dog. Boots on gravel.

### 0:05 – 0:12 — Stack Up / Overwatch Check-In
- **Visual:** Cut to sniper GoPro on a rooftop across the street, thermal scope on the front door. Then cut back to the stack pressed against the breach point.
- **Sniper whispers into mic.**
- **Overlay:**
  - `[SNIPER → AI]` "I've got two heat sigs front room, one upstairs northwest corner, no movement rear."
  - `[AI ROUTING]` compact → priority: tactical intel → route: squad lead
  - `[LEADER EARPIECE]` "Overwatch: 2 tangos front, 1 upstairs NW, rear clear."
- **Audio:** Low whisper, then the clean synthesized leader earpiece line.

### 0:12 – 0:20 — Breach
- **Visual:** Tight helmet-cam on the #1 man. Breacher sets charge on the door. Squad leader in the back of the stack taps #2's shoulder. Cut to bird's-eye: the stack compresses on the door.
- **Squad leader (calm) to his own AI:** "Tell breacher green light, entry team flashbang on my go."
- **Overlay:**
  - `[LEADER → AI]` "Breacher green light. Entry team flashbang on my go."
  - `[AI ROUTING]` intent parsed → fan-out: breacher, entry team (4 nodes)
  - `[BREACHER EARPIECE]` "Green light."
  - `[ENTRY TEAM EARPIECE]` "Flashbang on leader's go."
- **Audio:** Whisper count. Three. Two. One.
- **SFX:** Muffled thump of the breaching charge. Door blows inward.

### 0:20 – 0:32 — Dynamic Entry / Multi-Channel Chaos (the money shot)
- **Visual:** RAPID multi-angle cut — this is where the product value lands.
  - Helmet-cam #1 sweeps the foyer, suppressed M4 double-tap, tango down.
  - Helmet-cam #3 clears left, room corner.
  - Helmet-cam #5 pushes up the stairs.
  - Cut to squad leader holding rear security in the doorway, calm face, eyes closed for half a second listening to the earpiece.
- **Four operators talk into their mics simultaneously — messy, overlapping.** The overlay shows the raw traffic on the left column and the AI collapsing it.
- **Overlay (stacking fast):**
  - `[OP1 → AI]` "Foyer clear one down"
  - `[OP3 → AI]` "Living room clear"
  - `[OP5 → AI]` "Moving up stairs contact contact—"
  - `[OP2 → AI]` "Kitchen clear no hostage"
  - `[AI ROUTING]` 4 raw reports → 1 compacted SITREP
  - `[LEADER EARPIECE]` "First floor 90% clear, 1 EKIA. Team 2 in contact upstairs."
- **Audio design:** Four overlapping whispered voices fade under — then ONE clean synthesized line rises in the leader's earpiece. This is the core emotional beat. Show the leader react to the single clean line.

### 0:32 – 0:42 — Plan Change / Push Orders Down
- **Visual:** Squad leader opens eyes, decisive. Cut to his POV — the HUD shows upstairs contact flagged red.
- **Squad leader (to his AI):** "Reroute team 1 up the stairs to reinforce. Team 2 hold the landing. Medic stage at the base."
- **Overlay:**
  - `[LEADER → AI]` "Team 1 upstairs, Team 2 hold landing, medic stage base."
  - `[AI ROUTING]` intent parsed → targeted routing, no broadcast spam
  - `[TEAM 1 EARPIECE]` "Reinforce upstairs, now."
  - `[TEAM 2 EARPIECE]` "Hold landing."
  - `[MEDIC EARPIECE]` "Stage base of stairs."
- **Visual:** Cut hard — three operators from Team 1 peel off and flow up the stairs. Bird's-eye shows the formation reconfigure in real time.
- **Audio:** Suppressed M4 bursts upstairs. `Pfft-pfft.`

### 0:42 – 0:52 — Contact / Save the Hostage
- **Visual:** Helmet-cam pushes into the upstairs NW bedroom. Door kicks open. Tango with a weapon over a kneeling, bound, hooded hostage. Clean double-tap to the tango's chest. Tango drops.
- **Operator (breathless):** "Jackpot secure. Precious cargo safe. One EKIA upstairs."
- **Overlay:**
  - `[OP5 → AI]` "Jackpot secure, PC safe, 1 EKIA upstairs."
  - `[AI ROUTING]` priority: MISSION COMPLETE → escalate immediately
  - `[LEADER EARPIECE]` "Jackpot. Hostage alive. House clear."
- **Visual:** Operator cuts the zip ties. Hostage's hood comes off. Wide, terrified eyes, then relief.

### 0:52 – 0:58 — Exfil
- **Visual:** Bird's-eye. The stack flows out of the house with the hostage in the middle, wrapped in a coat. The tree topology graphic lights green across every node — all check-ins green.
- **Overlay:**
  - `[AI ROUTING]` full SITREP compiled → ready for higher command
  - `[LEADER EARPIECE]` "All callsigns up. Exfil now."

### 0:58 – 1:00 — Tag
- **Visual:** Cut to black. White text, centered.
- **Text:**
  - **TacNet**
  - One AI per operator. One clear picture for the commander.
  - Offline. On-device. Built for the edge.

---

## Production Notes

- **Split-screen rule:** Keep the TacNet overlay on the LEFT HALF of the frame for the entire video so the viewer's eye learns where to look for the "what the AI is doing" layer. Action always plays on the RIGHT HALF.
- **Overlay typography:** Mono font, all caps, two colors only — dim green for raw input, bright white for the summarized leader line. This visual contrast sells the whole pitch.
- **Audio mix:** The defining moment is 0:26–0:30 — four overlapping whispers must duck hard under one clean synthesized earpiece line. That single audio edit is the entire product value proposition.
- **Weapons:** Suppressed M4s only. No yelling. The quietness is the point — TacNet lets the team whisper.
- **Safety/realism callouts:** Use airsoft or dressed prop rifles. Consult a mil-advisor for stack discipline and room-clearing flow so it reads as real Tier-1, not Call of Duty.
- **Lower thirds:** None. The overlay is the only text.
- **End card CTA (optional):** `tacnet.ai` or QR to pitch deck.

---

## Voice Casting

- **Squad Leader:** Low, calm, measured. Never raises voice.
- **Operators (4 distinct voices):** Clipped, professional, slightly out of breath during contact.
- **Sniper:** Whisper, flat affect.
- **AI earpiece voice:** Neutral, clean, slightly synthetic — NOT robotic. Think modern TTS, warm but precise. One consistent voice for every leader earpiece line.

---

## Shot List Summary (for the DP)

1. Drone bird's-eye — stack approach (0:00)
2. Drone bird's-eye — stack compress on door (0:12)
3. Drone bird's-eye — formation reconfigure mid-raid (0:38)
4. Drone bird's-eye — exfil with hostage (0:52)
5. GoPro helmet-cam — #1 man foyer entry
6. GoPro helmet-cam — #3 clearing living room
7. GoPro helmet-cam — #5 pushing stairs
8. GoPro helmet-cam — hostage room breach & rescue
9. Sniper thermal scope POV
10. Over-the-shoulder — squad leader in doorway, listening
11. Close-up — squad leader's face reacting to the clean earpiece line (hero shot)
12. Close-up — hostage's face, hood off

Twelve setups, one night, one location. Shootable.
