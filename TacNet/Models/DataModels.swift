import Foundation

struct TreeNode: Codable, Equatable, Sendable {
    var id: String
    var label: String
    var claimedBy: String?
    var children: [TreeNode]

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case claimedBy = "claimed_by"
        case children
    }
}

struct NetworkConfig: Codable, Equatable, Sendable {
    var networkName: String
    var networkID: UUID
    var createdBy: String
    var pinHash: String?
    var version: Int
    var tree: TreeNode

    enum CodingKeys: String, CodingKey {
        case networkName = "network_name"
        case networkID = "network_id"
        case createdBy = "created_by"
        case pinHash = "pin_hash"
        case version
        case tree
    }

    mutating func applyMutation(_ mutateTree: (inout TreeNode) -> Void) {
        mutateTree(&tree)
        version += 1
    }

    @discardableResult
    mutating func mergeIfNewer(_ incoming: NetworkConfig) -> Bool {
        guard incoming.networkID == networkID else {
            return false
        }
        guard incoming.version > version else {
            return false
        }
        self = incoming
        return true
    }
}

struct Message: Codable, Equatable, Sendable {
    enum MessageType: String, Codable, CaseIterable, Sendable {
        case broadcast = "BROADCAST"
        case compaction = "COMPACTION"
        case claim = "CLAIM"
        case release = "RELEASE"
        case treeUpdate = "TREE_UPDATE"
        case promote = "PROMOTE"
        case claimRejected = "CLAIM_REJECTED"

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            guard let value = MessageType(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unsupported message type: \(rawValue)"
                )
            }
            self = value
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    struct Payload: Codable, Equatable, Sendable {
        struct Location: Codable, Equatable, Sendable {
            var lat: Double
            var lon: Double
            var accuracy: Double
            var isFallback: Bool

            enum CodingKeys: String, CodingKey {
                case lat
                case lon
                case accuracy
                case isFallback = "is_fallback"
            }

            static func fromCoordinates(latitude: Double?, longitude: Double?, accuracy: Double?) -> Location {
                guard let latitude, let longitude, let accuracy else {
                    return Location(lat: 0, lon: 0, accuracy: -1, isFallback: true)
                }
                return Location(lat: latitude, lon: longitude, accuracy: accuracy, isFallback: false)
            }
        }

        var location: Location
        var encrypted: Bool
        var transcript: String?
        var summary: String?
        var claimedNodeID: String?
        var targetNodeID: String?
        var rejectionReason: String?
        var tree: TreeNode?

        enum CodingKeys: String, CodingKey {
            case location
            case encrypted
            case transcript
            case summary
            case claimedNodeID = "claimed_node_id"
            case targetNodeID = "target_node_id"
            case rejectionReason = "rejection_reason"
            case tree
        }
    }

    var id: UUID
    var type: MessageType
    var senderID: String
    var senderRole: String
    var parentID: String?
    var treeLevel: Int
    var timestamp: Date
    var ttl: Int
    var payload: Payload

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case senderID = "sender_id"
        case senderRole = "sender_role"
        case parentID = "parent_id"
        case treeLevel = "tree_level"
        case timestamp
        case ttl
        case payload
    }

    static func make(
        id: UUID = UUID(),
        type: MessageType,
        senderID: String,
        senderRole: String,
        parentID: String?,
        treeLevel: Int,
        ttl: Int,
        encrypted: Bool,
        latitude: Double?,
        longitude: Double?,
        accuracy: Double?,
        transcript: String? = nil,
        summary: String? = nil,
        claimedNodeID: String? = nil,
        targetNodeID: String? = nil,
        rejectionReason: String? = nil,
        tree: TreeNode? = nil,
        timestamp: Date = Date()
    ) -> Message {
        Message(
            id: id,
            type: type,
            senderID: senderID,
            senderRole: senderRole,
            parentID: parentID,
            treeLevel: treeLevel,
            timestamp: timestamp,
            ttl: ttl,
            payload: Payload(
                location: .fromCoordinates(latitude: latitude, longitude: longitude, accuracy: accuracy),
                encrypted: encrypted,
                transcript: transcript,
                summary: summary,
                claimedNodeID: claimedNodeID,
                targetNodeID: targetNodeID,
                rejectionReason: rejectionReason,
                tree: tree
            )
        )
    }
}

struct NodeIdentity: Codable, Equatable, Sendable {
    var deviceID: String
    var claimedNodeID: String?
    var networkID: UUID

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case claimedNodeID = "claimed_node_id"
        case networkID = "network_id"
    }
}

struct NodeIdentityStore {
    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "TacNet.NodeIdentity") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func save(_ identity: NodeIdentity) throws {
        let data = try JSONEncoder().encode(identity)
        defaults.set(data, forKey: storageKey)
    }

    func load() -> NodeIdentity? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(NodeIdentity.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}

enum TreeHelpers {
    static func parent(of nodeID: String, in tree: TreeNode) -> TreeNode? {
        guard let path = path(to: nodeID, in: tree), path.count > 1 else {
            return nil
        }
        return path[path.count - 2]
    }

    static func siblings(of nodeID: String, in tree: TreeNode) -> [TreeNode] {
        guard let parentNode = parent(of: nodeID, in: tree) else {
            return []
        }
        return parentNode.children.filter { $0.id != nodeID }
    }

    static func children(of nodeID: String, in tree: TreeNode) -> [TreeNode] {
        findNode(withID: nodeID, in: tree)?.children ?? []
    }

    static func level(of nodeID: String, in tree: TreeNode) -> Int? {
        guard let path = path(to: nodeID, in: tree) else {
            return nil
        }
        return path.count - 1
    }

    private static func path(to nodeID: String, in tree: TreeNode) -> [TreeNode]? {
        if tree.id == nodeID {
            return [tree]
        }

        for child in tree.children {
            if let childPath = path(to: nodeID, in: child) {
                return [tree] + childPath
            }
        }

        return nil
    }

    private static func findNode(withID nodeID: String, in tree: TreeNode) -> TreeNode? {
        if tree.id == nodeID {
            return tree
        }

        for child in tree.children {
            if let found = findNode(withID: nodeID, in: child) {
                return found
            }
        }

        return nil
    }
}

final class MessageDeduplicator: @unchecked Sendable {
    private let capacity: Int
    private var seenSet: Set<UUID>
    private var ringBuffer: [UUID]
    private var nextEvictionIndex: Int
    private let lock = NSLock()

    init(capacity: Int = 50_000) {
        self.capacity = max(1, capacity)
        self.seenSet = Set(minimumCapacity: self.capacity)
        self.ringBuffer = []
        self.ringBuffer.reserveCapacity(self.capacity)
        self.nextEvictionIndex = 0
    }

    func isDuplicate(messageId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if seenSet.contains(messageId) {
            return true
        }

        if ringBuffer.count < capacity {
            ringBuffer.append(messageId)
        } else {
            let evicted = ringBuffer[nextEvictionIndex]
            seenSet.remove(evicted)
            ringBuffer[nextEvictionIndex] = messageId
            nextEvictionIndex = (nextEvictionIndex + 1) % capacity
        }

        seenSet.insert(messageId)
        return false
    }

    var trackedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return seenSet.count
    }
}
