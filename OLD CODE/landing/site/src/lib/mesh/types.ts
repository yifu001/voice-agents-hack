export type NodeId = string;

export type NodeRole = 'commander' | 'l1' | 'l2';

export interface MeshNode {
  id: NodeId;
  label: string;
  callsign: string;          // displayed above label, mono
  role: NodeRole;
  parent: NodeId | null;
  /** Pixel coords inside a 1000x560 viewBox. */
  x: number;
  y: number;
  /** Fake but plausible for the inspector. */
  lat: string;
  lon: string;
}

export interface MeshEdge {
  from: NodeId;
  to: NodeId;
}

export type PacketKind = 'broadcast' | 'compaction';

export interface Packet {
  id: string;
  kind: PacketKind;
  /** Origin → target edge traversal. */
  from: NodeId;
  to: NodeId;
  /** Seconds since sim start when this packet fires. */
  fireAt: number;
  /** Content that will land at the target if it's the inspector's target. */
  text: string;
  /** Scripted vignette id. */
  vignette: string;
}

export interface Vignette {
  id: string;
  label: string;
  description: string;
  transcripts: Array<{
    node: NodeId;
    text: string;
  }>;
  /** One summary that a parent emits after collecting the transcripts. */
  compaction: {
    by: NodeId;
    text: string;
  };
}
