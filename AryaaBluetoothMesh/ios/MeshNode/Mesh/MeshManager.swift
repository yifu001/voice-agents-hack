import Combine
import CoreBluetooth
import Foundation

/// Orchestrates the mesh: owns Peripheral + Central, routes inbound messages
/// (received either as peripheral-writes or as central-notifications) through
/// the dedup cache, and forwards to connected peers while TTL > 1.
///
/// Outbound messages are broadcast on BOTH paths:
/// - `central.broadcast` writes to every peer we've connected to as central
/// - `peripheral.broadcast` notifies every central subscribed to our outbox
/// Per-pair, exactly one of these paths will have the other phone as recipient;
/// dedup on the receiving side handles the rare case when both paths co-exist.
final class MeshManager: NSObject, ObservableObject {
    @Published private(set) var messages: [MeshMessage] = []
    @Published private(set) var connectedPeerCount: Int = 0
    @Published private(set) var sentCount: Int = 0
    @Published private(set) var receivedCount: Int = 0
    @Published private(set) var forwardedCount: Int = 0
    @Published private(set) var dedupedCount: Int = 0

    let selfId: String
    private var msgCounter: UInt32 = 0
    private let cache = MeshCache()
    private let peripheral = MeshPeripheral()
    private let central = MeshCentral()

    private var centralPeers: Int = 0
    private var peripheralSubscribers: Int = 0

    init(nodeID: String) {
        self.selfId = nodeID
        super.init()
        peripheral.delegate = self
        central.delegate = self
    }

    func start() {
        peripheral.start()
        central.start()
    }

    func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        msgCounter += 1
        let msg = MeshMessage(
            senderId: selfId,
            msgId: msgCounter,
            ttl: MeshConstants.defaultTTL,
            timestamp: MeshMessage.nowMs(),
            payload: trimmed
        )
        cache.insert(sender: msg.senderId, msgId: msg.msgId)
        messages.append(msg)
        sentCount += 1
        guard let data = msg.encode() else { return }
        broadcast(data, excluding: nil)
    }

    private func broadcast(_ data: Data, excluding sourceId: String?) {
        central.broadcast(data, excluding: sourceId)
        peripheral.broadcast(data)
    }

    private func handleIncoming(_ data: Data, from sourceId: String?) {
        guard let msg = MeshMessage.decode(data) else { return }
        if msg.senderId == selfId { return }
        let isNew = cache.insert(sender: msg.senderId, msgId: msg.msgId)
        guard isNew else {
            dedupedCount += 1
            return
        }
        messages.append(msg)
        receivedCount += 1
        guard msg.ttl > 1 else { return }
        var forwarded = msg
        forwarded.ttl -= 1
        guard let fwData = forwarded.encode() else { return }
        broadcast(fwData, excluding: sourceId)
        forwardedCount += 1
    }

    private func recomputeConnectedCount() {
        connectedPeerCount = centralPeers + peripheralSubscribers
    }
}

extension MeshManager: MeshPeripheralDelegate {
    func peripheral(didReceive data: Data, from centralId: String) {
        handleIncoming(data, from: centralId)
    }

    func peripheral(subscribersChanged count: Int) {
        peripheralSubscribers = count
        recomputeConnectedCount()
    }
}

extension MeshManager: MeshCentralDelegate {
    func central(connectedPeersChanged count: Int) {
        centralPeers = count
        recomputeConnectedCount()
    }

    func central(didReceive data: Data, from peerId: String) {
        handleIncoming(data, from: peerId)
    }
}
