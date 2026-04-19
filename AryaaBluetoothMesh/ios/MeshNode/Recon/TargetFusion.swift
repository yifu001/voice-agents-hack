import CoreGraphics
import Foundation

enum TargetFusion {
    static func bearingDegrees(
        for box: TargetSighting.NormalizedBox,
        horizontalFoVDegrees: Double,
        headingTrueNorth: Double?
    ) -> Double? {
        guard let heading = headingTrueNorth else { return nil }
        let cxNormalized = (box.xMin + box.xMax) / 2.0 / 1000.0
        let offsetDegrees = (cxNormalized - 0.5) * horizontalFoVDegrees
        return normalizedDegrees(heading + offsetDegrees)
    }

    static func pinholeDistanceMeters(
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

    static func suggestedTargetHeightMeters(for label: String) -> Double? {
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

    static func fuse(
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

    static func normalizedDegrees(_ value: Double) -> Double {
        let mod = value.truncatingRemainder(dividingBy: 360.0)
        return mod < 0 ? mod + 360 : mod
    }

    static func isValid(box: TargetSighting.NormalizedBox) -> Bool {
        box.xMin >= 0 && box.yMin >= 0 &&
        box.xMax <= 1000 && box.yMax <= 1000 &&
        box.xMax > box.xMin && box.yMax > box.yMin
    }
}
