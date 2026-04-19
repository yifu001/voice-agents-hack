import ARKit
import Foundation

@MainActor
final class RangeProvider: NSObject {
    enum Mode {
        case lidar
        case unavailable
    }

    @Published private(set) var mode: Mode = .unavailable

    private let session: ARSession
    private var isRunning = false
    private var latestDepthFrame: ARFrame?

    init(session: ARSession = ARSession()) {
        self.session = session
        super.init()
        self.session.delegate = self
    }

    static func lidarSupported() -> Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    func start() {
        guard Self.lidarSupported() else {
            mode = .unavailable
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics.insert(.sceneDepth)
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
        mode = .lidar
    }

    func stop() {
        guard isRunning else { return }
        session.pause()
        isRunning = false
        mode = .unavailable
        latestDepthFrame = nil
    }

    func suspendForInference() {
        guard isRunning else { return }
        session.pause()
        isRunning = false
    }

    func resumeAfterInference() {
        guard !isRunning, Self.lidarSupported() else { return }
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics.insert(.sceneDepth)
        session.run(config, options: [])
        isRunning = true
        mode = .lidar
    }

    func sampleDepthMeters(atNormalizedPoint point: CGPoint) -> Double? {
        guard mode == .lidar,
              let frame = latestDepthFrame,
              let sceneDepth = frame.sceneDepth else {
            return nil
        }

        let depthMap = sceneDepth.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return nil }

        let px = Int((point.x.clamped(0, 1)) * Double(width - 1))
        let py = Int((point.y.clamped(0, 1)) * Double(height - 1))

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let row = base.advanced(by: py * bytesPerRow)
        let pointer = row.assumingMemoryBound(to: Float32.self)
        let value = pointer[px]
        guard value.isFinite, value > 0 else { return nil }
        return Double(value)
    }
}

extension RangeProvider: ARSessionDelegate {
    nonisolated func session(_: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            self.latestDepthFrame = frame
        }
    }

    nonisolated func session(_: ARSession, didFailWithError _: Error) {
        Task { @MainActor in
            self.isRunning = false
            self.mode = .unavailable
        }
    }

    nonisolated func sessionWasInterrupted(_: ARSession) {
        Task { @MainActor in
            self.mode = .unavailable
        }
    }

    nonisolated func sessionInterruptionEnded(_: ARSession) {
        Task { @MainActor in
            if Self.lidarSupported() {
                self.mode = .lidar
            }
        }
    }
}

private extension Double {
    func clamped(_ lower: Double, _ upper: Double) -> Double {
        min(max(self, lower), upper)
    }
}

private extension CGFloat {
    func clamped(_ lower: Double, _ upper: Double) -> Double {
        Double(self).clamped(lower, upper)
    }
}
