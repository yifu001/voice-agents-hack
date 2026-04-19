import ARKit
import Foundation

/// Produces an optional metric range for a normalized point in the camera image.
///
/// On Pro-class devices with a LiDAR sensor, `RangeProvider` runs a lightweight `ARSession`
/// with `sceneDepth` enabled and samples the depth map at shutter time. On non-LiDAR devices
/// the `.pinhole` path is preferred instead (handled upstream in `TargetFusion.fuse`), so this
/// provider will simply return `nil` and the pinhole fallback kicks in.
///
/// Deliberately isolated from `CameraCaptureService` so Recon can still capture a still via
/// AVFoundation while ARKit runs in parallel for depth.
@MainActor
public final class RangeProvider: NSObject {

    public enum Mode {
        /// LiDAR is available and the session is running.
        case lidar
        /// Either LiDAR isn't supported or the session isn't running.
        case unavailable
    }

    @Published public private(set) var mode: Mode = .unavailable

    private let session: ARSession
    private var isRunning = false
    private var latestDepthFrame: ARFrame?

    public init(session: ARSession = ARSession()) {
        self.session = session
        super.init()
        self.session.delegate = self
    }

    /// Returns `true` if the current device supports `ARFrame.sceneDepth`.
    public static func lidarSupported() -> Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    public func start() {
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

    public func stop() {
        guard isRunning else { return }
        session.pause()
        isRunning = false
        mode = .unavailable
    }

    /// Sample depth at a normalized `(x, y)` point in the image (0...1 each).
    /// Returns the depth in metres or `nil` when unavailable.
    public func sampleDepthMeters(atNormalizedPoint point: CGPoint) -> Double? {
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
    nonisolated public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Persist the most recent frame; read back synchronously on the main actor at shutter.
        Task { @MainActor in
            self.latestDepthFrame = frame
        }
    }

    nonisolated public func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.isRunning = false
            self.mode = .unavailable
        }
    }

    nonisolated public func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            self.mode = .unavailable
        }
    }

    nonisolated public func sessionInterruptionEnded(_ session: ARSession) {
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
