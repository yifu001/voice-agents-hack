import CoreGraphics
import Foundation

/// A single reconnaissance detection produced by the Recon (battlefield scan) tab.
///
/// A `TargetSighting` combines three signals:
/// 1. The raw bounding box + label + free-text description produced by Gemma 4 E4B on-device.
/// 2. A compass bearing (true north, 0–360°) computed by fusing the bounding-box centroid with
///    the device's magnetometer heading and horizontal field of view. `nil` when heading is
///    unavailable (permission denied, poor signal, etc.).
/// 3. A range estimate in metres, either from ARKit LiDAR `sceneDepth` (Pro-class devices) or
///    a pinhole-model fallback (`TargetFusion.pinholeDistanceMeters`). `nil` when neither is
///    available (e.g. the bounding box is degenerate or the class is unknown).
///
/// The model is `Codable` and `Sendable` so it can cross the actor boundary from
/// `BattlefieldVisionService` → `ReconViewModel` → (optionally) `BluetoothMeshService` without
/// additional conversion.
public struct TargetSighting: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let description: String
    public let confidence: Double
    public let boundingBox: NormalizedBox

    /// True-north bearing in degrees, `0..<360`. `nil` when heading is unavailable.
    public let bearingDegreesTrueNorth: Double?

    /// Metric range to the target. `nil` when neither LiDAR nor pinhole produced a value.
    public let rangeMeters: Double?
    public let rangeSource: RangeSource
    public let capturedAt: Date

    public init(
        id: UUID = UUID(),
        label: String,
        description: String,
        confidence: Double,
        boundingBox: NormalizedBox,
        bearingDegreesTrueNorth: Double?,
        rangeMeters: Double?,
        rangeSource: RangeSource,
        capturedAt: Date
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.bearingDegreesTrueNorth = bearingDegreesTrueNorth
        self.rangeMeters = rangeMeters
        self.rangeSource = rangeSource
        self.capturedAt = capturedAt
    }

    /// Normalized bounding box matching Gemma 4's convention: a 0..1000 grid where the first
    /// axis is `y` (top → bottom) and the second is `x` (left → right).
    public struct NormalizedBox: Codable, Equatable, Sendable {
        public let yMin: Double
        public let xMin: Double
        public let yMax: Double
        public let xMax: Double

        public init(yMin: Double, xMin: Double, yMax: Double, xMax: Double) {
            self.yMin = yMin
            self.xMin = xMin
            self.yMax = yMax
            self.xMax = xMax
        }

        /// Convenience initializer from the `[y1, x1, y2, x2]` array that Gemma 4 emits.
        public init?(gemmaArray array: [Int]) {
            guard array.count == 4 else { return nil }
            self.init(
                yMin: Double(array[0]),
                xMin: Double(array[1]),
                yMax: Double(array[2]),
                xMax: Double(array[3])
            )
        }

        public var centroid: CGPoint {
            CGPoint(x: (xMin + xMax) / 2.0, y: (yMin + yMax) / 2.0)
        }

        public var widthNormalized: Double { max(0, xMax - xMin) / 1000.0 }
        public var heightNormalized: Double { max(0, yMax - yMin) / 1000.0 }

        /// Converts this normalized box into a pixel rect for a given source image size, using
        /// the top-left origin convention expected by UIKit and Core Graphics.
        public func rect(inImageOfSize imageSize: CGSize) -> CGRect {
            let scaleX = imageSize.width / 1000.0
            let scaleY = imageSize.height / 1000.0
            let originX = xMin * scaleX
            let originY = yMin * scaleY
            let width = max(0, xMax - xMin) * scaleX
            let height = max(0, yMax - yMin) * scaleY
            return CGRect(x: originX, y: originY, width: width, height: height)
        }
    }

    public enum RangeSource: String, Codable, Sendable {
        case lidar
        case pinhole
        case unknown
    }
}

public extension TargetSighting {
    /// Shortest single-line summary suitable for voice readout or mesh relay:
    /// e.g. `"Dismounted combatant · 062° TN · 40 m"`.
    var summaryLine: String {
        var parts: [String] = [label.capitalized]
        if let bearing = bearingDegreesTrueNorth {
            parts.append(String(format: "%03.0f° TN", bearing))
        }
        if let range = rangeMeters, range.isFinite {
            if range >= 1000 {
                parts.append(String(format: "%.1f km", range / 1000.0))
            } else if range >= 100 {
                parts.append(String(format: "%.0f m", range))
            } else {
                parts.append(String(format: "%.1f m", range))
            }
        }
        return parts.joined(separator: " · ")
    }
}

/// The raw JSON payload Gemma 4 emits for each detection, decoded directly from its response.
/// Kept separate from `TargetSighting` so the vision service layer can be unit-tested without
/// any sensor fusion coupling.
public struct RawDetection: Codable, Sendable, Equatable {
    public let box_2d: [Int]
    public let label: String
    public let description: String?
    public let confidence: Double?

    public init(box_2d: [Int], label: String, description: String?, confidence: Double?) {
        self.box_2d = box_2d
        self.label = label
        self.description = description
        self.confidence = confidence
    }
}
