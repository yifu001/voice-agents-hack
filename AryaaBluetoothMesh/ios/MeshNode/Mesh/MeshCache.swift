import Foundation

final class MeshCache {
    private let capacity: Int
    private var set = Set<String>()
    private var order = [String]()
    private let lock = NSLock()

    init(capacity: Int = MeshConstants.cacheSize) {
        self.capacity = capacity
    }

    private static func key(_ sender: String, _ msgId: UInt32) -> String {
        "\(sender):\(msgId)"
    }

    func contains(sender: String, msgId: UInt32) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return set.contains(Self.key(sender, msgId))
    }

    @discardableResult
    func insert(sender: String, msgId: UInt32) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let k = Self.key(sender, msgId)
        if set.contains(k) { return false }
        set.insert(k)
        order.append(k)
        if order.count > capacity {
            let evict = order.removeFirst()
            set.remove(evict)
        }
        return true
    }
}
