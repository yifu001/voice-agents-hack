import type { MeshNode, MeshEdge } from './types';

/** The demo tree used by the architecture section. */
export const NODES: MeshNode[] = [
  {
    id: 'cmd',
    label: 'Commander',
    callsign: 'CMD-0',
    role: 'commander',
    parent: null,
    x: 500, y: 70,
    lat: '37.7749°', lon: '-122.4194°',
  },
  {
    id: 'alpha',
    label: 'Alpha Lead',
    callsign: 'ALPHA',
    role: 'l1',
    parent: 'cmd',
    x: 220, y: 260,
    lat: '37.7752°', lon: '-122.4201°',
  },
  {
    id: 'bravo',
    label: 'Bravo Lead',
    callsign: 'BRAVO',
    role: 'l1',
    parent: 'cmd',
    x: 780, y: 260,
    lat: '37.7743°', lon: '-122.4183°',
  },
  {
    id: 'a1',
    label: 'Alpha-1',
    callsign: 'A-1',
    role: 'l2',
    parent: 'alpha',
    x: 90,  y: 450,
    lat: '37.7754°', lon: '-122.4209°',
  },
  {
    id: 'a2',
    label: 'Alpha-2',
    callsign: 'A-2',
    role: 'l2',
    parent: 'alpha',
    x: 220, y: 450,
    lat: '37.7748°', lon: '-122.4196°',
  },
  {
    id: 'a3',
    label: 'Alpha-3',
    callsign: 'A-3',
    role: 'l2',
    parent: 'alpha',
    x: 350, y: 450,
    lat: '37.7751°', lon: '-122.4190°',
  },
  {
    id: 'b1',
    label: 'Bravo-1',
    callsign: 'B-1',
    role: 'l2',
    parent: 'bravo',
    x: 650, y: 450,
    lat: '37.7740°', lon: '-122.4180°',
  },
  {
    id: 'b2',
    label: 'Bravo-2',
    callsign: 'B-2',
    role: 'l2',
    parent: 'bravo',
    x: 780, y: 450,
    lat: '37.7738°', lon: '-122.4175°',
  },
  {
    id: 'b3',
    label: 'Bravo-3',
    callsign: 'B-3',
    role: 'l2',
    parent: 'bravo',
    x: 910, y: 450,
    lat: '37.7735°', lon: '-122.4171°',
  },
];

export const EDGES: MeshEdge[] = (() => {
  const e: MeshEdge[] = [];
  for (const n of NODES) {
    if (n.parent) e.push({ from: n.parent, to: n.id });
  }
  return e;
})();

export function nodeById(id: string): MeshNode | undefined {
  return NODES.find((n) => n.id === id);
}

export function childrenOf(id: string): MeshNode[] {
  return NODES.filter((n) => n.parent === id);
}

export function siblingsOf(id: string): MeshNode[] {
  const me = nodeById(id);
  if (!me || me.parent === null) return [];
  return NODES.filter((n) => n.parent === me.parent && n.id !== me.id);
}
