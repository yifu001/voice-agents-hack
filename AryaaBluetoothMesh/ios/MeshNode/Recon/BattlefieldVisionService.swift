import Foundation
import UIKit

enum BattlefieldVisionServiceError: Error, Equatable {
    case failedToEncodeImage
    case failedToWriteTempImage(String)
    case invalidModelResponse(String)
}

enum ReconScanMode: String, CaseIterable, Sendable, Codable {
    case quick
    case standard
    case detail

    var tokenBudget: Int {
        switch self {
        case .quick: return 128
        case .standard: return 192
        case .detail: return 256
        }
    }

    var maxResponseTokens: Int {
        switch self {
        case .quick: return 256
        case .standard: return 512
        case .detail: return 768
        }
    }

    var title: String {
        switch self {
        case .quick: return "Quick"
        case .standard: return "Standard"
        case .detail: return "Detail"
        }
    }
}

@MainActor
final class BattlefieldVisionService {
    struct ScanResult {
        let detections: [RawDetection]
        let previewImage: UIImage
    }

    private struct PreparedScanInput {
        let previewImage: UIImage
        let imageURL: URL
    }

    private let llmService: LLMService
    private let tempDirectory: URL
    private let jpegQuality: CGFloat
    private let maxModelImageDimension: CGFloat

    init(
        llmService: LLMService,
        tempDirectory: URL = FileManager.default.temporaryDirectory,
        jpegQuality: CGFloat = 0.8,
        maxModelImageDimension: CGFloat = 768
    ) {
        self.llmService = llmService
        self.tempDirectory = tempDirectory
        self.jpegQuality = jpegQuality
        self.maxModelImageDimension = maxModelImageDimension
    }

    func scan(
        image: UIImage,
        intent: String,
        mode: ReconScanMode = .quick
    ) async throws -> ScanResult {
        let prepared = try autoreleasepool {
            let modelImage = Self.downscaledForModel(image, maxDimension: maxModelImageDimension)
            let imageURL = try Self.writeTempJPEG(modelImage, into: tempDirectory, quality: jpegQuality)
            return PreparedScanInput(previewImage: modelImage, imageURL: imageURL)
        }
        defer { try? FileManager.default.removeItem(at: prepared.imageURL) }

        try await llmService.waitUntilReady()
        let rawResponse = try await llmService.complete(
            messages: try Self.buildMessages(intent: intent, imageURL: prepared.imageURL),
            options: Self.buildOptions(mode: mode)
        )
        return ScanResult(
            detections: try Self.parseDetections(from: rawResponse),
            previewImage: prepared.previewImage
        )
    }

    static let systemPrompt: String = """
    You are a military reconnaissance vision model embedded on a soldier's phone.
    For every request:
      1. Look at the provided image.
      2. Identify ONLY the categories the user requests.
      3. For each detection, emit a JSON object with fields:
           box_2d:      [y_min, x_min, y_max, x_max]  (integers 0-1000, top-left origin)
           label:       short class name (e.g. "dismounted combatant")
           description: <= 20 words, uniform / weapon silhouette / posture / count
           confidence:  0.0 - 1.0
      4. Output ONLY a JSON array. No prose, no markdown fence. Begin with "[" and end with "]".
    Never fabricate items that are not clearly visible. If nothing matches, return [].
    """

    private static func buildMessages(intent: String, imageURL: URL) throws -> [[String: Any]] {
        let imagePath = imageURL.path
        return [
            [
                "role": "system",
                "content": systemPrompt
            ],
            [
                "role": "user",
                "content": intent,
                "images": [imagePath]
            ]
        ]
    }

    private static func buildOptions(mode: ReconScanMode) -> [String: Any] {
        [
            "max_tokens": mode.maxResponseTokens,
            "temperature": 0.0,
            "image_token_budget": mode.tokenBudget
        ]
    }

    private static func parseDetections(from response: String) throws -> [RawDetection] {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let jsonString = stripMarkdownFence(from: trimmed)
        guard let start = jsonString.firstIndex(of: "["),
              let end = jsonString.lastIndex(of: "]") else {
            return []
        }
        let slice = String(jsonString[start...end])

        guard let data = slice.data(using: .utf8) else {
            throw BattlefieldVisionServiceError.invalidModelResponse("non-utf8 response body")
        }

        do {
            let detections = try JSONDecoder().decode([RawDetection].self, from: data)
            return detections.filter { $0.box_2d.count == 4 }
        } catch {
            throw BattlefieldVisionServiceError.invalidModelResponse(
                "decode failed: \(error.localizedDescription)"
            )
        }
    }

    private static func stripMarkdownFence(from text: String) -> String {
        var trimmed = text
        if trimmed.hasPrefix("```") {
            if let newline = trimmed.firstIndex(of: "\n") {
                trimmed = String(trimmed[trimmed.index(after: newline)...])
            }
            if trimmed.hasSuffix("```") {
                trimmed = String(trimmed.dropLast(3))
            }
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func writeTempJPEG(
        _ image: UIImage,
        into directory: URL,
        quality: CGFloat
    ) throws -> URL {
        guard let jpegData = image.jpegData(compressionQuality: quality) else {
            throw BattlefieldVisionServiceError.failedToEncodeImage
        }

        let filename = "meshnode-recon-\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        do {
            try jpegData.write(to: url, options: .atomic)
            return url
        } catch {
            throw BattlefieldVisionServiceError.failedToWriteTempImage(error.localizedDescription)
        }
    }

    // Keep the multimodal prefill closer to Gemma's native vision size so the
    // older Cactus build doesn't explode into many image crops on device.
    private static func downscaledForModel(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longestEdge = max(pixelWidth, pixelHeight)

        guard longestEdge > maxDimension, pixelWidth > 0, pixelHeight > 0 else {
            return image
        }

        let scale = maxDimension / longestEdge
        let targetSize = CGSize(
            width: max(1, floor(pixelWidth * scale)),
            height: max(1, floor(pixelHeight * scale))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
