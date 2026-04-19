import Combine
import CoreBluetooth
import CoreLocation
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

    /// Last known position for each peer (keyed by senderId), updated from incoming messages.
    @Published private(set) var peerLocations: [String: PeerLocation] = [:]

    struct PeerLocation: Equatable {
        let coordinate: CLLocationCoordinate2D
        let accuracy: Double?
        let timestamp: Date

        static func == (lhs: PeerLocation, rhs: PeerLocation) -> Bool {
            lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude &&
            lhs.accuracy == rhs.accuracy &&
            lhs.timestamp == rhs.timestamp
        }
    }

    let selfId: String
    let locationManager = LocationManager()
    private var msgCounter: UInt32 = 0
    private let cache = MeshCache()
    private let peripheral = MeshPeripheral()
    private let central = MeshCentral()
    private var heartbeatTimer: Timer?

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
        locationManager.start()
        startHeartbeat()
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
            payload: trimmed,
            latitude: locationManager.latitude,
            longitude: locationManager.longitude,
            locationAccuracy: locationManager.accuracy
        )
        cache.insert(sender: msg.senderId, msgId: msg.msgId)
        messages.append(msg)
        sentCount += 1
        updatePeerLocation(from: msg)
        guard let data = msg.encode() else { return }
        broadcast(data, excluding: nil)
    }

    private func broadcast(_ data: Data, excluding sourceId: String?) {
        central.broadcast(data, excluding: sourceId)
        peripheral.broadcast(data)
    }

    // MARK: - Location heartbeat

    /// Broadcasts a lightweight location-only message every 5 seconds so
    /// the map stays current even without chat messages.
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.sendLocationHeartbeat()
        }
    }

    private func sendLocationHeartbeat() {
        guard locationManager.hasLocation else { return }
        guard connectedPeerCount > 0 else { return }
        msgCounter += 1
        let msg = MeshMessage(
            senderId: selfId,
            msgId: msgCounter,
            ttl: MeshConstants.defaultTTL,
            timestamp: MeshMessage.nowMs(),
            payload: "📍",
            latitude: locationManager.latitude,
            longitude: locationManager.longitude,
            locationAccuracy: locationManager.accuracy
        )
        cache.insert(sender: msg.senderId, msgId: msg.msgId)
        updatePeerLocation(from: msg)
        sentCount += 1
        guard let data = msg.encode() else { return }
        broadcast(data, excluding: nil)
    }

    // MARK: - Incoming

    private func handleIncoming(_ data: Data, from sourceId: String?) {
        guard let msg = MeshMessage.decode(data) else { return }
        if msg.senderId == selfId { return }
        let isNew = cache.insert(sender: msg.senderId, msgId: msg.msgId)
        guard isNew else {
            dedupedCount += 1
            return
        }
        updatePeerLocation(from: msg)
        // Don't show heartbeat-only messages in the chat feed
        if msg.payload != "📍" {
            messages.append(msg)
        }
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

    private func updatePeerLocation(from msg: MeshMessage) {
        guard let coord = msg.coordinate else { return }
        peerLocations[msg.senderId] = PeerLocation(
            coordinate: coord,
            accuracy: msg.locationAccuracy,
            timestamp: Date(timeIntervalSince1970: Double(msg.timestamp) / 1000)
        )
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
