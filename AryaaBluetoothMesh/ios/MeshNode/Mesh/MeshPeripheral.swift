import CoreBluetooth
import Foundation
import os

private let log = Logger(subsystem: "com.cactushack.MeshNode", category: "mesh.peripheral")

protocol MeshPeripheralDelegate: AnyObject {
    /// A central wrote to our inbox — we just received a message.
    func peripheral(didReceive data: Data, from centralId: String)
    /// Number of centrals subscribed to our outbox changed.
    func peripheral(subscribersChanged count: Int)
}

/// Runs the Peripheral role:
/// - advertises the mesh service UUID
/// - hosts a writable "inbox" characteristic (centrals write incoming messages here)
/// - hosts a notifiable "outbox" characteristic (we push outgoing messages to subscribed centrals)
///
/// The outbox lets us push data back to centrals that connected to us WITHOUT
/// needing our own central to discover them first — which matters because iOS
/// often fails to scan for a peer that already has an active connection.
final class MeshPeripheral: NSObject {
    weak var delegate: MeshPeripheralDelegate?

    private var manager: CBPeripheralManager!
    private var inbox: CBMutableCharacteristic!
    private var outbox: CBMutableCharacteristic!
    private var serviceReady = false
    private var advertiseTimer: DispatchSourceTimer?

    /// Centrals currently subscribed to our outbox notifications.
    private var subscribers: Set<CBCentral> = []
    /// Messages queued waiting for the notify queue to become ready.
    private var pendingBroadcasts: [Data] = []

    var subscriberCount: Int { subscribers.count }

    func start() {
        manager = CBPeripheralManager(delegate: self, queue: nil)
        startHeartbeat()
    }

    /// Push a message to every subscribed central.
    /// Handles backpressure via peripheralManagerIsReady(toUpdateSubscribers:).
    func broadcast(_ data: Data) {
        pendingBroadcasts.append(data)
        flushBroadcasts()
    }

    // MARK: - Setup

    private func setupService() {
        manager.removeAllServices()
        serviceReady = false

        inbox = CBMutableCharacteristic(
            type: MeshConstants.inboxUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        outbox = CBMutableCharacteristic(
            type: MeshConstants.outboxUUID,
            properties: [.notify],
            value: nil,
            permissions: [.readable]
        )
        let service = CBMutableService(type: MeshConstants.serviceUUID, primary: true)
        service.characteristics = [inbox, outbox]
        manager.add(service)
    }

    private func startAdvertising() {
        guard serviceReady else { return }
        if manager.isAdvertising { return }
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [MeshConstants.serviceUUID],
            CBAdvertisementDataLocalNameKey: "MeshNode"
        ])
        log.info("Advertising started")
    }

    private func startHeartbeat() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        // Bounce advertising every ~9s so iOS re-emits fresh packets.
        timer.schedule(deadline: .now() + 9, repeating: 9)
        timer.setEventHandler { [weak self] in
            guard let self, self.manager?.state == .poweredOn, self.serviceReady else { return }
            if self.manager.isAdvertising {
                self.manager.stopAdvertising()
            }
            self.manager.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [MeshConstants.serviceUUID],
                CBAdvertisementDataLocalNameKey: "MeshNode"
            ])
            log.info("Advertising bounced")
        }
        timer.resume()
        advertiseTimer = timer
    }

    private func flushBroadcasts() {
        guard let outbox, !subscribers.isEmpty else {
            if !subscribers.isEmpty { return }
            // No one is listening — drop the queue rather than growing forever.
            pendingBroadcasts.removeAll()
            return
        }
        while let data = pendingBroadcasts.first {
            let ok = manager.updateValue(data, for: outbox, onSubscribedCentrals: nil)
            if ok {
                pendingBroadcasts.removeFirst()
            } else {
                // Queue full; iOS will call peripheralManagerIsReady(toUpdateSubscribers:) when ready.
                log.info("Notify queue full; \(self.pendingBroadcasts.count, privacy: .public) pending")
                return
            }
        }
    }
}

extension MeshPeripheral: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        log.info("Peripheral state → \(peripheral.state.rawValue, privacy: .public)")
        if peripheral.state == .poweredOn {
            setupService()
        } else {
            serviceReady = false
            subscribers.removeAll()
            pendingBroadcasts.removeAll()
            delegate?.peripheral(subscribersChanged: 0)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didAdd service: CBService,
                           error: Error?) {
        if let error {
            log.error("didAdd service error: \(error.localizedDescription, privacy: .public)")
            return
        }
        serviceReady = true
        startAdvertising()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager,
                                              error: Error?) {
        if let error {
            log.error("startAdvertising error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveWrite requests: [CBATTRequest]) {
        for req in requests {
            guard req.characteristic.uuid == MeshConstants.inboxUUID,
                  let data = req.value else { continue }
            delegate?.peripheral(didReceive: data, from: req.central.identifier.uuidString)
            peripheral.respond(to: req, withResult: .success)
        }
    }

    // MARK: - Subscriptions

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        guard characteristic.uuid == MeshConstants.outboxUUID else { return }
        subscribers.insert(central)
        log.info("Subscribed: \(central.identifier.uuidString, privacy: .public), total=\(self.subscribers.count, privacy: .public)")
        delegate?.peripheral(subscribersChanged: subscribers.count)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard characteristic.uuid == MeshConstants.outboxUUID else { return }
        subscribers.remove(central)
        log.info("Unsubscribed: \(central.identifier.uuidString, privacy: .public), total=\(self.subscribers.count, privacy: .public)")
        delegate?.peripheral(subscribersChanged: subscribers.count)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        flushBroadcasts()
    }
}
