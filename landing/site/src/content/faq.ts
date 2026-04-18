export const faq = {
  eyebrow: '10 / FAQ',
  title: 'Questions we expect.',
  items: [
    {
      q: 'Why not just use radios?',
      a: 'Radios scale with human attention. TacNet scales with model context. Both co-exist — TacNet is the summariser layer on top of a voice-first experience, not a replacement for the warfighter knowing how to work a handset.',
    },
    {
      q: 'Why on-device AI?',
      a: "Because the cloud isn't there. Gemma 4 E4B runs entirely on iPhone 15+ with no internet. The worst failure mode for comms is a failure mode that depends on a backend you no longer have.",
    },
    {
      q: 'Why BLE and not LoRa or mesh Wi-Fi?',
      a: 'BLE 5.0 is ubiquitous, low-power, and already on every phone. Range per hop is 30–100 m; we rely on multi-hop flooding. LoRa would require additional hardware for every operator; mesh Wi-Fi is too power-hungry for a field operation.',
    },
    {
      q: "What happens if the commander's phone dies?",
      a: 'Any claimed node can be promoted to organiser via PROMOTE. Children auto-reparent on a 60 s parent disconnect timeout. Command continuity survives any single-device loss.',
    },
    {
      q: 'How private is this?',
      a: 'All messages are AES-256 end-to-end with a PIN-derived session key. Audio never leaves the device. Transcript text crosses the mesh encrypted. The relays can route ciphertext but cannot read it.',
    },
    {
      q: 'Is this a real product?',
      a: "TacNet is a hackathon project built for the Cactus × Gemma 4 YC event. The architecture, protocol, and code are real; the brand is not a shipping product. The plan is to open-source and let defense-adjacent operators evaluate fitness.",
    },
    {
      q: "Where's the code?",
      a: "GitHub link below. See Orchestrator.md for the full system spec and DECISIONS.md for the 21 design decisions that shaped it.",
    },
  ],
};
