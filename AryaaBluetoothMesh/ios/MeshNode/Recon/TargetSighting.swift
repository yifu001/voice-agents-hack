import CoreGraphics
import Foundation

struct TargetSighting: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let label: String
    let description: String
    let confidence: Double
    let boundingBox: NormalizedBox
    let bearingDegreesTrueNorth: Double?
    let rangeMeters: Double?
    let rangeSource: RangeSource
    let capturedAt: Date

    init(
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

    struct NormalizedBox: Codable, Equatable, Sendable {
        let yMin: Double
        let xMin: Double
        let yMax: Double
        let xMax: Double

        init(yMin: Double, xMin: Double, yMax: Double, xMax: Double) {
            self.yMin = yMin
            self.xMin = xMin
            self.yMax = yMax
            self.xMax = xMax
        }

        init?(gemmaArray array: [Int]) {
            guard array.count == 4 else { return nil }
            self.init(
                yMin: Double(array[0]),
                xMin: Double(array[1]),
                yMax: Double(array[2]),
                xMax: Double(array[3])
            )
        }

        var centroid: CGPoint {
            CGPoint(x: (xMin + xMax) / 2.0, y: (yMin + yMax) / 2.0)
        }

        var widthNormalized: Double { max(0, xMax - xMin) / 1000.0 }
        var heightNormalized: Double { max(0, yMax - yMin) / 1000.0 }

        func rect(inImageOfSize imageSize: CGSize) -> CGRect {
            let scaleX = imageSize.width / 1000.0
            let scaleY = imageSize.height / 1000.0
            let originX = xMin * scaleX
            let originY = yMin * scaleY
            let width = max(0, xMax - xMin) * scaleX
            let height = max(0, yMax - yMin) * scaleY
            return CGRect(x: originX, y: originY, width: width, height: height)
        }
    }

    enum RangeSource: String, Codable, Sendable {
        case lidar
        case pinhole
        case unknown
    }
}

extension TargetSighting {
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

struct RawDetection: Codable, Sendable, Equatable {
    let box_2d: [Int]
    let label: String
    let description: String?
    let confidence: Double?
}
