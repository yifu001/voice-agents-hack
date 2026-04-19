import Foundation
import UIKit

/// Errors that can be thrown by `BattlefieldVisionService`.
public enum BattlefieldVisionServiceError: Error, Equatable {
    case failedToEncodeImage
    case failedToWriteTempImage(String)
    case invalidModelResponse(String)
}

/// Scan presets exposed to the UI. Maps to the Gemma 4 `image_token_budget` option which
/// controls the number of visual tokens: larger ⇒ finer detection at higher latency.
public enum ReconScanMode: String, CaseIterable, Sendable, Codable {
    case quick
    case standard
    case detail

    public var tokenBudget: Int {
        switch self {
        case .quick: return 280
        case .standard: return 560
        case .detail: return 1120
        }
    }

    public var maxResponseTokens: Int {
        switch self {
        case .quick: return 256
        case .standard: return 512
        case .detail: return 768
        }
    }

    public var title: String {
        switch self {
        case .quick: return "Quick"
        case .standard: return "Standard"
        case .detail: return "Detail"
        }
    }
}

/// Wraps Gemma 4 E4B (loaded via `CactusModelInitializationService.shared`) to perform
/// on-device battlefield object detection. Completely local — no network, no cloud fallback.
///
/// The service writes the scanned JPEG to `tempDirectory` under a unique filename, invokes
/// `cactus_complete` with an OpenAI-style chat-messages JSON (including a Cactus-native
/// `images` field per message), then parses the JSON array of detections. The temp file is
/// deleted in `defer` after each call so no sighting imagery lingers on disk.
public actor BattlefieldVisionService {

    public typealias CompleteFunction = @Sendable (
        CactusModelT,
        String,   // messagesJson
        String?,  // optionsJson
        String?,  // toolsJson
        ((String, UInt32) -> Void)?,
        Data?
    ) throws -> String

    private let modelInitializationService: CactusModelInitializationService
    private let completeFunction: CompleteFunction
    private let tempDirectory: URL
    private let jpegQuality: CGFloat

    public init(
        modelInitializationService: CactusModelInitializationService = .shared,
        completeFunction: @escaping CompleteFunction = { model, messages, options, tools, onToken, pcm in
            try cactusComplete(model, messages, options, tools, onToken, pcm)
        },
        tempDirectory: URL = FileManager.default.temporaryDirectory,
        jpegQuality: CGFloat = 0.85
    ) {
        self.modelInitializationService = modelInitializationService
        self.completeFunction = completeFunction
        self.tempDirectory = tempDirectory
        self.jpegQuality = jpegQuality
    }

    /// Scan a still image with Gemma 4 for the requested target categories. Returns an array of
    /// raw detections in Gemma's 0..1000 grid — sensor fusion is performed downstream by
    /// `TargetFusion.fuse`.
    public func scan(
        image: UIImage,
        intent: String,
        mode: ReconScanMode = .standard
    ) async throws -> [RawDetection] {
        let imageURL = try Self.writeTempJPEG(image, into: tempDirectory, quality: jpegQuality)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let handle = try await modelInitializationService.initializeModelAfterEnsuringDownload()

        let messagesJSON = try Self.buildMessagesJSON(intent: intent, imageURL: imageURL)
        let optionsJSON = Self.buildOptionsJSON(mode: mode)

        let rawResponse = try completeFunction(handle, messagesJSON, optionsJSON, nil, nil, nil)
        return try Self.parseDetections(from: rawResponse)
    }

    // MARK: - System + user prompts

    /// System prompt. Force JSON-only output and explicitly forbid fabrication.
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

    // MARK: - JSON builders (internal for testability)

    /// Build the messages JSON expected by Cactus's `cactus_complete`. Uses both an OpenAI-style
    /// content array AND Cactus's native per-message `images` field to maximize compatibility
    /// across Cactus builds that parse either convention (see
    /// `Frameworks/cactus-ios.xcframework/.../engine.h` — `struct ChatMessage { std::vector<std::string> images; }`).
    static func buildMessagesJSON(intent: String, imageURL: URL) throws -> String {
        let imagePath = imageURL.path
        // The Cactus engine's ChatMessage uses plain file-system paths, not `file://` URLs.
        let userContent: [[String: Any]] = [
            ["type": "image", "url": imagePath],
            ["type": "text", "text": intent]
        ]

        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": systemPrompt
            ],
            [
                "role": "user",
                "content": userContent,
                "images": [imagePath]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: messages, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            throw BattlefieldVisionServiceError.invalidModelResponse("non-utf8 messages json")
        }
        return string
    }

    static func buildOptionsJSON(mode: ReconScanMode) -> String {
        // Temperature 0 for deterministic JSON; image_token_budget drives Gemma 4's visual
        // resolution (70/140/280/560/1120 are the supported values).
        """
        {"max_tokens":\(mode.maxResponseTokens),"temperature":0.0,"image_token_budget":\(mode.tokenBudget)}
        """
    }

    // MARK: - Response parsing

    /// Strip any accidental markdown fence, then decode a JSON array of detections. Be liberal
    /// about what we accept — Gemma occasionally wraps the array in ```json ... ```.
    static func parseDetections(from response: String) throws -> [RawDetection] {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let jsonString = stripMarkdownFence(from: trimmed)
        // Locate the outermost JSON array even if the model emitted a prose preamble.
        guard let start = jsonString.firstIndex(of: "["),
              let end = jsonString.lastIndex(of: "]") else {
            // An empty or malformed array also acts as "no detections".
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

    // MARK: - Temp image lifecycle

    static func writeTempJPEG(
        _ image: UIImage,
        into directory: URL,
        quality: CGFloat
    ) throws -> URL {
        guard let jpegData = image.jpegData(compressionQuality: quality) else {
            throw BattlefieldVisionServiceError.failedToEncodeImage
        }

        let filename = "tacnet-recon-\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        do {
            try jpegData.write(to: url, options: .atomic)
            return url
        } catch {
            throw BattlefieldVisionServiceError.failedToWriteTempImage(error.localizedDescription)
        }
    }
}
