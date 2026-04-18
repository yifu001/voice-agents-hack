import type { Vignette } from './types';

/**
 * Three scripted vignettes. They cycle in the simulation —
 * "Contact" → "Clear" → "Casualty" → loop.
 */
export const VIGNETTES: Vignette[] = [
  {
    id: 'contact',
    label: 'CONTACT',
    description: 'Squad Alpha reports armed contact in sector 7.',
    transcripts: [
      { node: 'a1', text: "Movement sector 7, three o'clock." },
      { node: 'a2', text: 'Confirmed, four individuals, armed.' },
      { node: 'a3', text: 'Rear clear, holding position.' },
    ],
    compaction: {
      by: 'alpha',
      text: 'Squad Alpha: 4 armed contacts sector 7 (2× confirmed). Rear clear, holding.',
    },
  },
  {
    id: 'clear',
    label: 'PERIMETER CLEAR',
    description: 'Squad Bravo reports perimeter secure across all positions.',
    transcripts: [
      { node: 'b1', text: 'North perimeter, no contact.' },
      { node: 'b2', text: 'South perimeter, no contact.' },
      { node: 'b3', text: 'Rear secure, holding.' },
    ],
    compaction: {
      by: 'bravo',
      text: 'Squad Bravo: perimeter clear across all positions, holding.',
    },
  },
  {
    id: 'casualty',
    label: 'CASUALTY',
    description: 'Squad Alpha reports casualty; medic en route.',
    transcripts: [
      { node: 'a2', text: 'Man down, need medic grid 482.' },
      { node: 'a1', text: 'Moving to 482, ETA 90 seconds.' },
      { node: 'a3', text: 'Rear secured, no contact.' },
    ],
    compaction: {
      by: 'alpha',
      text: 'Squad Alpha: casualty at grid 482, medic inbound 90s. Rear secure.',
    },
  },
];
