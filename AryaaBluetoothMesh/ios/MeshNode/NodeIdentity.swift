import Foundation

struct GraphNode: Codable, Identifiable, Hashable {
    let id: String
}

enum EdgeType: String, Codable {
    case exact
    case summary
}

struct GraphEdge: Codable, Hashable {
    let from: String
    let to: String
    let type: EdgeType
}

struct UndirectedEdge: Codable, Hashable {
    let from: String
    let to: String
}

private struct DirectedGraphFile: Codable {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
}

private struct UndirectedGraphFile: Codable {
    let nodes: [GraphNode]
    let edges: [UndirectedEdge]
}

@MainActor
final class NodeIdentity: ObservableObject {
    private static let nodeKey = "NODE_ID"
    private static let radiusKey = "CONTEXT_RADIUS"
    private static let defaultRadius = 2

    @Published private(set) var nodeID: String?
    @Published var contextRadius: Int {
        didSet { UserDefaults.standard.set(contextRadius, forKey: Self.radiusKey) }
    }

    let availableNodes: [GraphNode]
    let edges: [GraphEdge]
    private let adjacency: [String: Set<String>]

    init() {
        let directed = Self.loadDirected()
        let undirected = Self.loadUndirected()
        self.availableNodes = directed.nodes
        self.edges = directed.edges
        self.adjacency = Self.buildAdjacency(edges: undirected.edges)
        self.nodeID = UserDefaults.standard.string(forKey: Self.nodeKey)
        let storedRadius = UserDefaults.standard.object(forKey: Self.radiusKey) as? Int
        self.contextRadius = storedRadius ?? Self.defaultRadius
    }

    var isSelected: Bool { nodeID != nil }

    var currentNode: GraphNode? {
        guard let nodeID else { return nil }
        return availableNodes.first { $0.id == nodeID }
    }

    func select(_ id: String) {
        nodeID = id
        UserDefaults.standard.set(id, forKey: Self.nodeKey)
    }

    func incomingEdgeType(fromSenderID senderID: String) -> EdgeType? {
        guard let selfID = nodeID else { return nil }
        return edges.first { $0.from == senderID && $0.to == selfID }?.type
    }

    func nodesWithinRadius(_ radius: Int, from start: String) -> Set<String> {
        guard radius >= 0 else { return [] }
        var visited: Set<String> = [start]
        var frontier: [String] = [start]
        for _ in 0..<radius {
            var next: [String] = []
            for node in frontier {
                for neighbor in adjacency[node] ?? [] where !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    next.append(neighbor)
                }
            }
            if next.isEmpty { break }
            frontier = next
        }
        return visited
    }

    private static func buildAdjacency(edges: [UndirectedEdge]) -> [String: Set<String>] {
        var map: [String: Set<String>] = [:]
        for edge in edges {
            map[edge.from, default: []].insert(edge.to)
            map[edge.to, default: []].insert(edge.from)
        }
        return map
    }

    private static func loadDirected() -> DirectedGraphFile {
        guard let url = Bundle.main.url(forResource: "graph", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let graph = try? JSONDecoder().decode(DirectedGraphFile.self, from: data)
        else { return DirectedGraphFile(nodes: [], edges: []) }
        return graph
    }

    private static func loadUndirected() -> UndirectedGraphFile {
        guard let url = Bundle.main.url(forResource: "graph_undirected", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let graph = try? JSONDecoder().decode(UndirectedGraphFile.self, from: data)
        else { return UndirectedGraphFile(nodes: [], edges: []) }
        return graph
    }
}
