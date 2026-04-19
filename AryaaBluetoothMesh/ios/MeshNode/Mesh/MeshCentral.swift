import CoreBluetooth
import Foundation
import os

private let log = Logger(subsystem: "com.cactushack.MeshNode", category: "mesh.central")

protocol MeshCentralDelegate: AnyObject {
    func central(connectedPeersChanged count: Int)
    /// A peer's peripheral notified us via outbox — incoming message.
    func central(didReceive data: Data, from peerId: String)
}

/// Runs the Central role: scans for the mesh service UUID, connects to
/// discovered peers (up to maxOutbound), discovers each peer's inbox+outbox
/// characteristics, subscribes to the outbox for incoming pushes, and writes
/// outgoing messages to the inbox.
///
/// Reconnection strategy:
/// - Scans with `AllowDuplicatesKey: true`.
/// - Never removes a known peer on disconnect — marks disconnected and
///   re-issues `connect(...)`. Heartbeat bounces the scan every ~9s so iOS
///   doesn't throttle it.
/// - `CBConnectPeripheralOptionNotifyOnDisconnectionKey: true` for prompt
///   disconnect callbacks.
final class MeshCentral: NSObject {
    weak var delegate: MeshCentralDelegate?

    private var manager: CBCentralManager!
    private var peers = [UUID: Peer]()
    private var heartbeatTimer: DispatchSourceTimer?
    private var ticks: Int = 0

    final class Peer {
        enum State { case connecting, connected, disconnected }
        let peripheral: CBPeripheral
        var state: State = .connecting
        var inbox: CBCharacteristic?
        var outbox: CBCharacteristic?
        var lastSeen: Date = Date()
        init(peripheral: CBPeripheral) { self.peripheral = peripheral }
    }

    func start() {
        manager = CBCentralManager(delegate: self, queue: nil)
        startHeartbeat()
    }

    var connectedCount: Int {
        peers.values.filter { $0.state == .connected && $0.inbox != nil }.count
    }

    /// Write `data` to every connected peer's inbox (best-effort; no flow control).
    func broadcast(_ data: Data, excluding: String? = nil) {
        for (id, peer) in peers {
            guard peer.state == .connected, let inbox = peer.inbox else { continue }
            if id.uuidString == excluding { continue }
            peer.peripheral.writeValue(data, for: inbox, type: .withoutResponse)
        }
    }

    // MARK: - Scan / connect

    private func startScanning() {
        guard manager.state == .poweredOn else { return }
        guard !manager.isScanning else { return }
        manager.scanForPeripherals(
            withServices: [MeshConstants.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        log.info("Scanning for mesh peers…")
    }

    private func connectIfPossible(_ peripheral: CBPeripheral) {
        guard connectedCount < MeshConstants.maxOutbound else { return }
        let options: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
        ]
        manager.connect(peripheral, options: options)
    }

    private func startHeartbeat() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 3, repeating: 3)
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
        heartbeatTimer = timer
    }

    private func tick() {
        guard manager?.state == .poweredOn else { return }
        for peer in peers.values where peer.state == .disconnected {
            peer.state = .connecting
            log.info("Re-attempting connect to \(peer.peripheral.identifier.uuidString, privacy: .public)")
            connectIfPossible(peer.peripheral)
        }
        if !manager.isScanning { startScanning() }

        ticks += 1
        // Every ~9s, bounce the scan so iOS re-opens a fresh scan window.
        if ticks % 3 == 0, manager.isScanning {
            manager.stopScan()
            startScanning()
            log.info("Scan bounced")
        }
    }

    private func notifyCountChange() {
        delegate?.central(connectedPeersChanged: connectedCount)
    }
}

// MARK: - CBCentralManagerDelegate

extension MeshCentral: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log.info("Central state → \(central.state.rawValue, privacy: .public)")
        if central.state == .poweredOn {
            startScanning()
            for peer in peers.values where peer.state != .connected {
                connectIfPossible(peer.peripheral)
            }
        } else {
            for peer in peers.values {
                peer.state = .disconnected
                peer.inbox = nil
                peer.outbox = nil
            }
            notifyCountChange()
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        let id = peripheral.identifier
        if let peer = peers[id] {
            peer.lastSeen = Date()
            if peer.state == .disconnected {
                peer.state = .connecting
                log.info("Rediscovered \(id.uuidString, privacy: .public); reconnecting")
                connectIfPossible(peripheral)
            }
            return
        }
        let peer = Peer(peripheral: peripheral)
        peers[id] = peer
        log.info("Discovered \(id.uuidString, privacy: .public) rssi=\(RSSI.intValue)")
        connectIfPossible(peripheral)
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        if let peer = peers[peripheral.identifier] {
            peer.state = .connected
            peer.lastSeen = Date()
        }
        log.info("Connected \(peripheral.identifier.uuidString, privacy: .public)")
        peripheral.discoverServices([MeshConstants.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        if let peer = peers[peripheral.identifier] {
            peer.state = .disconnected
            peer.inbox = nil
            peer.outbox = nil
        }
        if let error {
            log.info("Disconnected \(peripheral.identifier.uuidString, privacy: .public) — \(error.localizedDescription, privacy: .public)")
        } else {
            log.info("Disconnected \(peripheral.identifier.uuidString, privacy: .public)")
        }
        notifyCountChange()
        connectIfPossible(peripheral)
        startScanning()
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        if let peer = peers[peripheral.identifier] {
            peer.state = .disconnected
            peer.inbox = nil
            peer.outbox = nil
        }
        log.info("Failed to connect \(peripheral.identifier.uuidString, privacy: .public) — \(error?.localizedDescription ?? "unknown", privacy: .public)")
        notifyCountChange()
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == MeshConstants.serviceUUID {
            peripheral.discoverCharacteristics(
                [MeshConstants.inboxUUID, MeshConstants.outboxUUID],
                for: service
            )
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let chars = service.characteristics else { return }
        guard let peer = peers[peripheral.identifier] else { return }
        for c in chars {
            if c.uuid == MeshConstants.inboxUUID {
                peer.inbox = c
                log.info("Inbox ready on \(peripheral.identifier.uuidString, privacy: .public)")
            } else if c.uuid == MeshConstants.outboxUUID {
                peer.outbox = c
                peripheral.setNotifyValue(true, for: c)
                log.info("Subscribing to outbox on \(peripheral.identifier.uuidString, privacy: .public)")
            }
        }
        notifyCountChange()
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            log.error("notify-state error: \(error.localizedDescription, privacy: .public)")
            return
        }
        log.info("Notify state on \(peripheral.identifier.uuidString, privacy: .public) = \(characteristic.isNotifying, privacy: .public)")
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.uuid == MeshConstants.outboxUUID,
              let data = characteristic.value
        else { return }
        delegate?.central(didReceive: data, from: peripheral.identifier.uuidString)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didModifyServices invalidatedServices: [CBService]) {
        let ours = invalidatedServices.contains { $0.uuid == MeshConstants.serviceUUID }
        guard ours else { return }
        log.info("Services invalidated on \(peripheral.identifier.uuidString, privacy: .public); rediscovering")
        if let peer = peers[peripheral.identifier] {
            peer.inbox = nil
            peer.outbox = nil
            peripheral.discoverServices([MeshConstants.serviceUUID])
            notifyCountChange()
        }
    }
}
