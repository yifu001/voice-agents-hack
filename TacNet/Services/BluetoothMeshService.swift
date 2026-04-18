import Foundation
import CoreBluetooth

struct BluetoothMeshUUIDs {
    static let service = CBUUID(string: "7B4D8C10-3A8E-4D1A-9F53-2E28D9C1A001")
    static let broadcastCharacteristic = CBUUID(string: "7B4D8C10-3A8E-4D1A-9F53-2E28D9C1A101")
    static let compactionCharacteristic = CBUUID(string: "7B4D8C10-3A8E-4D1A-9F53-2E28D9C1A102")
    static let treeConfigCharacteristic = CBUUID(string: "7B4D8C10-3A8E-4D1A-9F53-2E28D9C1A103")
}

enum PeerConnectionState: String, Equatable, Sendable {
    case connected
    case disconnected
}

enum BluetoothMeshTransportEvent: Sendable {
    case discoveredPeer(UUID)
    case connectionStateChanged(UUID, PeerConnectionState)
    case receivedData(Data, from: UUID)
}

protocol BluetoothMeshTransporting: AnyObject {
    var eventHandler: ((BluetoothMeshTransportEvent) -> Void)? { get set }

    func start()
    func stop()
    func send(_ data: Data, messageType: Message.MessageType, to peerIDs: Set<UUID>)
}

private enum BluetoothMeshCharacteristicKind: CaseIterable {
    case broadcast
    case compaction
    case treeConfig

    var uuid: CBUUID {
        switch self {
        case .broadcast:
            return BluetoothMeshUUIDs.broadcastCharacteristic
        case .compaction:
            return BluetoothMeshUUIDs.compactionCharacteristic
        case .treeConfig:
            return BluetoothMeshUUIDs.treeConfigCharacteristic
        }
    }
}

final class BluetoothMeshService {
    typealias MessageHandler = (Message) -> Void
    typealias PeerStateHandler = (UUID, PeerConnectionState) -> Void
    typealias PeerDiscoveryHandler = (UUID) -> Void

    var onMessageReceived: MessageHandler?
    var onPeerConnectionStateChanged: PeerStateHandler?
    var onPeerDiscovered: PeerDiscoveryHandler?

    private let transport: BluetoothMeshTransporting
    private let deduplicator: MessageDeduplicator
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var peerStates: [UUID: PeerConnectionState] = [:]

    private struct QueuedRelay {
        let message: Message
        let excludedPeerID: UUID?
    }
    private var relayQueue: [QueuedRelay] = []

    init(
        transport: BluetoothMeshTransporting = CoreBluetoothMeshTransport(),
        deduplicator: MessageDeduplicator = MessageDeduplicator()
    ) {
        self.transport = transport
        self.deduplicator = deduplicator
        self.transport.eventHandler = { [weak self] event in
            self?.handleTransportEvent(event)
        }
    }

    func start() {
        transport.start()
    }

    func stop() {
        transport.stop()
    }

    func publish(_ message: Message) {
        guard message.ttl > 0 else {
            return
        }

        guard !deduplicator.isDuplicate(messageId: message.id) else {
            return
        }

        flood(message, excluding: nil)
    }

    func connectionState(for peerID: UUID) -> PeerConnectionState {
        peerStates[peerID] ?? .disconnected
    }

    var connectedPeerIDs: Set<UUID> {
        Set(
            peerStates.compactMap { peerID, state in
                state == .connected ? peerID : nil
            }
        )
    }

    var pendingRelayCount: Int {
        relayQueue.count
    }

    private func handleTransportEvent(_ event: BluetoothMeshTransportEvent) {
        switch event {
        case .discoveredPeer(let peerID):
            onPeerDiscovered?(peerID)

        case .connectionStateChanged(let peerID, let state):
            peerStates[peerID] = state
            onPeerConnectionStateChanged?(peerID, state)

            if state == .connected {
                flushRelayQueue(to: peerID)
            }

        case .receivedData(let data, let sourcePeerID):
            handleIncomingData(data, from: sourcePeerID)
        }
    }

    private func handleIncomingData(_ data: Data, from sourcePeerID: UUID) {
        guard var inboundMessage = try? decoder.decode(Message.self, from: data) else {
            return
        }

        guard inboundMessage.ttl > 0 else {
            return
        }

        guard !deduplicator.isDuplicate(messageId: inboundMessage.id) else {
            return
        }

        inboundMessage.ttl -= 1
        onMessageReceived?(inboundMessage)

        guard inboundMessage.ttl > 0 else {
            return
        }

        flood(inboundMessage, excluding: sourcePeerID)
    }

    private func flood(_ message: Message, excluding excludedPeerID: UUID?) {
        var targetPeerIDs = connectedPeerIDs
        if let excludedPeerID {
            targetPeerIDs.remove(excludedPeerID)
        }

        guard !targetPeerIDs.isEmpty else {
            relayQueue.append(QueuedRelay(message: message, excludedPeerID: excludedPeerID))
            return
        }

        send(message, to: targetPeerIDs)
    }

    private func flushRelayQueue(to peerID: UUID) {
        guard connectionState(for: peerID) == .connected else {
            return
        }

        var remaining: [QueuedRelay] = []

        for item in relayQueue {
            if item.excludedPeerID == peerID {
                remaining.append(item)
                continue
            }

            send(item.message, to: [peerID])
        }

        relayQueue = remaining
    }

    private func send(_ message: Message, to peerIDs: Set<UUID>) {
        guard let data = try? encoder.encode(message) else {
            return
        }
        transport.send(data, messageType: message.type, to: peerIDs)
    }
}

final class CoreBluetoothMeshTransport: NSObject, BluetoothMeshTransporting {
    var eventHandler: ((BluetoothMeshTransportEvent) -> Void)?

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?

    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]
    private var connectingPeripheralIDs: Set<UUID> = []
    private var discoveredCharacteristicsByPeer: [UUID: [BluetoothMeshCharacteristicKind: CBCharacteristic]] = [:]
    private var subscribedCentrals: [UUID: CBCentral] = [:]

    private var hasPublishedService = false
    private var treeConfigPayload: Data = Data()

    private lazy var broadcastCharacteristic: CBMutableCharacteristic = {
        CBMutableCharacteristic(
            type: BluetoothMeshUUIDs.broadcastCharacteristic,
            properties: [.read, .write, .writeWithoutResponse, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
    }()

    private lazy var compactionCharacteristic: CBMutableCharacteristic = {
        CBMutableCharacteristic(
            type: BluetoothMeshUUIDs.compactionCharacteristic,
            properties: [.read, .write, .writeWithoutResponse, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
    }()

    private lazy var treeConfigCharacteristic: CBMutableCharacteristic = {
        CBMutableCharacteristic(
            type: BluetoothMeshUUIDs.treeConfigCharacteristic,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
    }()

    func start() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }

        if centralManager?.state == .poweredOn {
            startScanning()
        }
        if peripheralManager?.state == .poweredOn {
            publishServiceIfNeeded()
            startAdvertising()
        }
    }

    func stop() {
        centralManager?.stopScan()
        for peripheral in connectedPeripherals.values {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        peripheralManager?.stopAdvertising()

        connectingPeripheralIDs.removeAll()
        connectedPeripherals.removeAll()
        discoveredCharacteristicsByPeer.removeAll()
        subscribedCentrals.removeAll()
    }

    func send(_ data: Data, messageType: Message.MessageType, to peerIDs: Set<UUID>) {
        let characteristicKind = characteristicKind(for: messageType)

        for peerID in peerIDs {
            if let peripheral = connectedPeripherals[peerID],
               let characteristic = discoveredCharacteristicsByPeer[peerID]?[characteristicKind] {
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
                continue
            }

            if let central = subscribedCentrals[peerID],
               let peripheralManager {
                let localCharacteristic = localCharacteristic(for: characteristicKind)
                _ = peripheralManager.updateValue(data, for: localCharacteristic, onSubscribedCentrals: [central])
            }
        }
    }

    private func startScanning() {
        centralManager?.scanForPeripherals(
            withServices: [BluetoothMeshUUIDs.service],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func startAdvertising() {
        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BluetoothMeshUUIDs.service]
        ])
    }

    private func publishServiceIfNeeded() {
        guard !hasPublishedService else {
            return
        }

        let service = CBMutableService(type: BluetoothMeshUUIDs.service, primary: true)
        service.characteristics = [
            broadcastCharacteristic,
            compactionCharacteristic,
            treeConfigCharacteristic
        ]

        peripheralManager?.add(service)
        hasPublishedService = true
    }

    private func characteristicKind(for messageType: Message.MessageType) -> BluetoothMeshCharacteristicKind {
        switch messageType {
        case .compaction:
            return .compaction
        default:
            return .broadcast
        }
    }

    private func localCharacteristic(for kind: BluetoothMeshCharacteristicKind) -> CBMutableCharacteristic {
        switch kind {
        case .broadcast:
            return broadcastCharacteristic
        case .compaction:
            return compactionCharacteristic
        case .treeConfig:
            return treeConfigCharacteristic
        }
    }
}

extension CoreBluetoothMeshTransport: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            return
        }
        startScanning()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        discoveredPeripherals[peripheral.identifier] = peripheral
        eventHandler?(.discoveredPeer(peripheral.identifier))

        if connectedPeripherals[peripheral.identifier] == nil,
           !connectingPeripheralIDs.contains(peripheral.identifier) {
            connectingPeripheralIDs.insert(peripheral.identifier)
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectingPeripheralIDs.remove(peripheral.identifier)
        connectedPeripherals[peripheral.identifier] = peripheral
        eventHandler?(.connectionStateChanged(peripheral.identifier, .connected))

        peripheral.delegate = self
        peripheral.discoverServices([BluetoothMeshUUIDs.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectingPeripheralIDs.remove(peripheral.identifier)
        eventHandler?(.connectionStateChanged(peripheral.identifier, .disconnected))
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connectingPeripheralIDs.remove(peripheral.identifier)
        connectedPeripherals.removeValue(forKey: peripheral.identifier)
        discoveredCharacteristicsByPeer.removeValue(forKey: peripheral.identifier)
        eventHandler?(.connectionStateChanged(peripheral.identifier, .disconnected))
    }
}

extension CoreBluetoothMeshTransport: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            return
        }

        peripheral.services?
            .filter { $0.uuid == BluetoothMeshUUIDs.service }
            .forEach { service in
                peripheral.discoverCharacteristics(BluetoothMeshCharacteristicKind.allCases.map(\.uuid), for: service)
            }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else {
            return
        }

        var map: [BluetoothMeshCharacteristicKind: CBCharacteristic] = [:]

        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case BluetoothMeshUUIDs.broadcastCharacteristic:
                map[.broadcast] = characteristic
            case BluetoothMeshUUIDs.compactionCharacteristic:
                map[.compaction] = characteristic
            case BluetoothMeshUUIDs.treeConfigCharacteristic:
                map[.treeConfig] = characteristic
            default:
                break
            }

            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        discoveredCharacteristicsByPeer[peripheral.identifier] = map
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let value = characteristic.value else {
            return
        }
        eventHandler?(.receivedData(value, from: peripheral.identifier))
    }
}

extension CoreBluetoothMeshTransport: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            return
        }

        publishServiceIfNeeded()
        startAdvertising()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            return
        }
        startAdvertising()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == BluetoothMeshUUIDs.treeConfigCharacteristic else {
            peripheral.respond(to: request, withResult: .requestNotSupported)
            return
        }

        guard request.offset <= treeConfigPayload.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }

        request.value = treeConfigPayload.subdata(in: request.offset..<treeConfigPayload.count)
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let value = request.value else {
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
                continue
            }

            if request.characteristic.uuid == BluetoothMeshUUIDs.treeConfigCharacteristic {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }

            eventHandler?(.receivedData(value, from: request.central.identifier))
            peripheral.respond(to: request, withResult: .success)
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        subscribedCentrals[central.identifier] = central
        eventHandler?(.connectionStateChanged(central.identifier, .connected))
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        subscribedCentrals.removeValue(forKey: central.identifier)
        eventHandler?(.connectionStateChanged(central.identifier, .disconnected))
    }
}
