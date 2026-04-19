import Foundation
import UIKit
import os

private let log = Logger(subsystem: "com.cactushack.MeshNode", category: "recon.vision")

enum BattlefieldVisionServiceError: Error, Equatable {
    case failedToEncodeImage
    case failedToWriteTempImage(String)
    case invalidModelResponse(String)
    case modelReturnedNoVisionOutput(String)
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
    private struct CactusCompletionEnvelope: Decodable {
        let success: Bool
        let error: String?
        let response: String?
    }

    private struct DetectionWrapper: Decodable {
        let detections: [RawDetection]
    }

    struct ScanResult {
        let detections: [RawDetection]
        let analysisText: String?
        let previewImage: UIImage
    }

    private struct ParsedVisionOutput {
        let detections: [RawDetection]
        let analysisText: String?
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
        jpegQuality: CGFloat = 0.65,
        maxModelImageDimension: CGFloat = 640
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
        log.info("Vision scan starting: mode=\(mode.rawValue, privacy: .public) maxTokens=\(mode.maxResponseTokens, privacy: .public) imageBudget=\(mode.tokenBudget, privacy: .public)")

        let maxDim = self.maxModelImageDimension
        let tempDir = self.tempDirectory
        let quality = self.jpegQuality
        let prepared = try autoreleasepool {
            let modelImage = Self.downscaledForModel(image, maxDimension: maxDim)
            log.info("Image downscaled: \(Int(modelImage.size.width * modelImage.scale))x\(Int(modelImage.size.height * modelImage.scale))")
            let imageURL = try Self.writeTempJPEG(modelImage, into: tempDir, quality: quality)
            return PreparedScanInput(previewImage: modelImage, imageURL: imageURL)
        }
        defer { try? FileManager.default.removeItem(at: prepared.imageURL) }

        log.info("Waiting for LLM to be ready (state=\(String(describing: self.llmService.state), privacy: .public))")
        try await self.llmService.waitUntilReady()

        let imageExists = FileManager.default.fileExists(atPath: prepared.imageURL.path)
        let imageSize = (try? FileManager.default.attributesOfItem(atPath: prepared.imageURL.path)[.size] as? Int) ?? 0
        log.info("Vision scan: image=\(prepared.imageURL.lastPathComponent, privacy: .public) exists=\(imageExists, privacy: .public) size=\(imageSize, privacy: .public) bytes")

        log.info("Calling llmService.complete() with vision message…")
        let rawResponse = try await self.llmService.complete(
            messages: try Self.buildMessages(intent: intent, imageURL: prepared.imageURL),
            options: Self.buildOptions(mode: mode)
        )

        log.info("Vision raw response (\(rawResponse.count) chars): \(rawResponse.prefix(800), privacy: .public)")

        let output = try Self.parseOutput(from: rawResponse)
        log.info("Parsed output: \(output.detections.count) detections, hasAnalysis=\(output.analysisText != nil, privacy: .public)")
        return ScanResult(
            detections: output.detections,
            analysisText: output.analysisText,
            previewImage: prepared.previewImage
        )
    }

    static let systemPrompt: String = """
    Analyze the attached image for battlefield reconnaissance.
    Identify only the categories requested below.
    Return only a JSON array.
    Each object must use this exact schema:
    {
      "box_2d": [y_min, x_min, y_max, x_max],
      "label": "short class name",
      "description": "20 words or fewer",
      "confidence": 0.0
    }
    Use integer coordinates from 0 to 1000 with top-left origin.
    Do not output markdown, prose, or explanations.
    If nothing matches, return [].
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
                "content": "Requested categories:\n\(intent)",
                "images": [imagePath]
            ]
        ]
    }

    private static func buildOptions(mode: ReconScanMode) -> [String: Any] {
        // Stop tokens are Gemma-specific. The previous ChatML tokens
        // (<|im_end|>, <end_of_turn>) never fire on Gemma 4 output, which let
        // the model trail past the JSON array and ruin the parse.
        [
            "max_tokens": mode.maxResponseTokens,
            "temperature": 0.0,
            "top_p": 0.95,
            "top_k": 40,
            "stop_sequences": ["<turn|>", "<eos>", "</s>", "```\n\n"],
        ]
    }

    private static func parseOutput(from response: String) throws -> ParsedVisionOutput {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            log.warning("Vision model returned empty response")
            throw BattlefieldVisionServiceError.modelReturnedNoVisionOutput(
                "Model returned empty response — vision may not be reaching the model."
            )
        }

        let responseBody = try extractPayload(from: trimmed)
        guard let responseBody,
              !responseBody.isEmpty else {
            log.warning("Vision response had no response body")
            throw BattlefieldVisionServiceError.modelReturnedNoVisionOutput(
                "Model did not return detections."
            )
        }

        if let detections = decodeDetectionsPayload(from: responseBody) {
            return ParsedVisionOutput(
                detections: detections.filter { $0.box_2d.count == 4 },
                analysisText: nil
            )
        }

        let analysisText = stripMarkdownFence(from: responseBody).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !analysisText.isEmpty else {
            log.warning("Vision response body was not structured detections: \(responseBody.prefix(200), privacy: .public)")
            throw BattlefieldVisionServiceError.modelReturnedNoVisionOutput(
                "Model answered the image request, but not in detection format."
            )
        }

        log.info("Vision returned prose analysis instead of detections")
        return ParsedVisionOutput(
            detections: [],
            analysisText: analysisText
        )
    }

    private static func extractPayload(from raw: String) throws -> String? {
        guard let data = raw.data(using: .utf8) else {
            throw BattlefieldVisionServiceError.invalidModelResponse("non-utf8 response body")
        }

        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(CactusCompletionEnvelope.self, from: data) {
            if !envelope.success {
                throw BattlefieldVisionServiceError.invalidModelResponse(
                    envelope.error ?? "model reported failure"
                )
            }
            return envelope.response
        }

        return raw
    }

    private static func decodeDetectionsPayload(from responseBody: String) -> [RawDetection]? {
        let normalized = stripMarkdownFence(from: responseBody.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !normalized.isEmpty else { return nil }

        if let detections = decodeDetectionsArray(from: normalized) {
            return detections
        }

        if let extracted = extractJSONArray(from: normalized),
           let detections = decodeDetectionsArray(from: extracted) {
            return detections
        }

        if let wrapper = decodeDetectionWrapper(from: normalized) {
            return wrapper
        }

        return nil
    }

    private static func decodeDetectionsArray(from text: String) -> [RawDetection]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([RawDetection].self, from: data)
    }

    private static func decodeDetectionWrapper(from text: String) -> [RawDetection]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return (try? JSONDecoder().decode(DetectionWrapper.self, from: data))?.detections
    }

    private static func extractJSONArray(from text: String) -> String? {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"),
              start <= end else { return nil }
        return String(text[start...end])
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
