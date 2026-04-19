import CoreGraphics
import Foundation

/// Pure sensor-fusion math for the Recon tab. Deliberately stateless and side-effect-free so
/// every transform can be exercised from `TargetFusionTests` without a simulator.
public enum TargetFusion {

    /// Compute a true-north bearing in degrees for a detection's bounding box.
    ///
    /// - Parameters:
    ///   - box: The Gemma-grid normalized bounding box (0..1000, origin top-left).
    ///   - horizontalFoVDegrees: Horizontal field of view of the capturing camera in degrees
    ///     (typically 60°–75° for the iPhone back wide lens).
    ///   - headingTrueNorth: Current device heading (true north) in degrees, as reported by
    ///     `CLHeading.trueHeading`. Pass `nil` if unavailable.
    /// - Returns: Bearing in `0..<360` degrees, or `nil` when `headingTrueNorth` is `nil`.
    public static func bearingDegrees(
        for box: TargetSighting.NormalizedBox,
        horizontalFoVDegrees: Double,
        headingTrueNorth: Double?
    ) -> Double? {
        guard let heading = headingTrueNorth else { return nil }
        let cxNormalized = (box.xMin + box.xMax) / 2.0 / 1000.0
        let offsetDegrees = (cxNormalized - 0.5) * horizontalFoVDegrees
        return normalizedDegrees(heading + offsetDegrees)
    }

    /// Pinhole range estimate based on expected real-world target height.
    ///
    /// `distance = (H_world * f_px) / h_box_px`
    /// where `f_px = (imageHeightPx / 2) / tan(verticalFoV/2)`.
    ///
    /// Accuracy is roughly ±25–35 % on a typical iPhone back wide lens and is a deliberate
    /// fallback for non-LiDAR devices. Use `RangeProvider` for LiDAR depth sampling when
    /// available.
    public static func pinholeDistanceMeters(
        for box: TargetSighting.NormalizedBox,
        imagePixelSize: CGSize,
        verticalFoVDegrees: Double,
        realWorldHeightMeters: Double
    ) -> Double? {
        guard imagePixelSize.height > 0,
              verticalFoVDegrees > 0,
              realWorldHeightMeters > 0
        else { return nil }

        let boxPixelHeight = box.heightNormalized * Double(imagePixelSize.height)
        guard boxPixelHeight > 1 else { return nil }

        let radians = verticalFoVDegrees * .pi / 180.0
        let focalLengthPx = (Double(imagePixelSize.height) / 2.0) / tan(radians / 2.0)
        let distance = (realWorldHeightMeters * focalLengthPx) / boxPixelHeight
        guard distance.isFinite, distance > 0 else { return nil }
        return distance
    }

    /// Suggested real-world height (metres) for a given Gemma label. Values are conservative
    /// averages and exist purely to power the pinhole fallback — they are not ground truth.
    /// Unknown labels return `nil`, which causes pinhole estimation to be skipped.
    public static func suggestedTargetHeightMeters(for label: String) -> Double? {
        let normalized = label.lowercased()

        if normalized.contains("person")
            || normalized.contains("combatant")
            || normalized.contains("soldier")
            || normalized.contains("dismount")
            || normalized.contains("pedestrian")
            || normalized.contains("man")
            || normalized.contains("woman") {
            return 1.75
        }
        if normalized.contains("child") {
            return 1.20
        }
        if normalized.contains("technical") {
            return 2.20
        }
        if normalized.contains("truck") || normalized.contains("lorry") {
            return 2.50
        }
        if normalized.contains("tank") || normalized.contains("apc") || normalized.contains("ifv") {
            return 2.30
        }
        if normalized.contains("car")
            || normalized.contains("vehicle")
            || normalized.contains("sedan") {
            return 1.50
        }
        if normalized.contains("motorcycle") || normalized.contains("bike") {
            return 1.10
        }
        if normalized.contains("drone") || normalized.contains("uav") {
            return 0.40
        }
        if normalized.contains("helicopter") {
            return 3.50
        }
        if normalized.contains("rifle") || normalized.contains("weapon") {
            return 0.90
        }
        return nil
    }

    /// Fuse one raw detection with the latest heading + range sensors into a `TargetSighting`.
    public static func fuse(
        detection: RawDetection,
        imagePixelSize: CGSize,
        horizontalFoVDegrees: Double,
        verticalFoVDegrees: Double,
        headingTrueNorth: Double?,
        lidarRangeMeters: Double?,
        capturedAt: Date = Date()
    ) -> TargetSighting? {
        guard let box = TargetSighting.NormalizedBox(gemmaArray: detection.box_2d),
              isValid(box: box)
        else { return nil }

        let bearing = bearingDegrees(
            for: box,
            horizontalFoVDegrees: horizontalFoVDegrees,
            headingTrueNorth: headingTrueNorth
        )

        let rangeMeters: Double?
        let rangeSource: TargetSighting.RangeSource
        if let lidarRange = lidarRangeMeters, lidarRange.isFinite, lidarRange > 0 {
            rangeMeters = lidarRange
            rangeSource = .lidar
        } else if
            let worldHeight = suggestedTargetHeightMeters(for: detection.label),
            let pinhole = pinholeDistanceMeters(
                for: box,
                imagePixelSize: imagePixelSize,
                verticalFoVDegrees: verticalFoVDegrees,
                realWorldHeightMeters: worldHeight
            )
        {
            rangeMeters = pinhole
            rangeSource = .pinhole
        } else {
            rangeMeters = nil
            rangeSource = .unknown
        }

        return TargetSighting(
            label: detection.label,
            description: detection.description ?? "",
            confidence: detection.confidence ?? 0,
            boundingBox: box,
            bearingDegreesTrueNorth: bearing,
            rangeMeters: rangeMeters,
            rangeSource: rangeSource,
            capturedAt: capturedAt
        )
    }

    /// Wrap a degree value into `0..<360`.
    public static func normalizedDegrees(_ value: Double) -> Double {
        let mod = value.truncatingRemainder(dividingBy: 360.0)
        return mod < 0 ? mod + 360 : mod
    }

    /// A box is valid iff it fits within the 0..1000 grid and has positive area.
    public static func isValid(box: TargetSighting.NormalizedBox) -> Bool {
        box.xMin >= 0 && box.yMin >= 0 &&
        box.xMax <= 1000 && box.yMax <= 1000 &&
        box.xMax > box.xMin && box.yMax > box.yMin
    }
}
