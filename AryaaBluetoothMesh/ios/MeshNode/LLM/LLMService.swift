import Foundation

@MainActor
final class LLMService: ObservableObject {
    enum LoadState: Equatable {
        case notLoaded
        case loading
        case ready
        case error(String)
    }

    @Published private(set) var state: LoadState = .notLoaded

    private var model: CactusModelT?
    private let loadQueue = DispatchQueue(label: "cactus.load", qos: .userInitiated)
    private let inferenceQueue = DispatchQueue(label: "cactus.infer", qos: .userInitiated)

    var isReady: Bool { state == .ready }

    func load() {
        guard case .notLoaded = state else { return }
        state = .loading

        loadQueue.async { [weak self] in
            guard let self else { return }
            guard let modelPath = Self.findModelPath() else {
                Task { @MainActor in
                    self.state = .error("Model not found in bundle Models/")
                }
                return
            }
            do {
                let handle = try cactusInit(modelPath, nil, false)
                Task { @MainActor in
                    self.model = handle
                    self.state = .ready
                }
            } catch {
                Task { @MainActor in
                    self.state = .error("cactusInit failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func completeStream(
        messages: [[String: String]],
        maxTokens: Int = 256,
        temperature: Double = 0.7
    ) -> AsyncStream<String> {
        AsyncStream { continuation in
            guard isReady, let model else {
                continuation.finish()
                return
            }
            guard let messagesJSON = Self.encodeJSON(messages) else {
                continuation.finish()
                return
            }
            let optionsJSON = Self.encodeJSON([
                "max_tokens": maxTokens,
                "temperature": temperature,
            ] as [String: Any])

            inferenceQueue.async {
                _ = try? cactusComplete(model, messagesJSON, optionsJSON, nil as String?) { token, _ in
                    continuation.yield(token)
                }
                continuation.finish()
            }
        }
    }

    func summarise(_ text: String) async -> String {
        let prompt = """
        You are a terse paraphraser. Rewrite the following chat message as a very short third-person summary — at most 12 words. Never quote or repeat the message verbatim. No preamble, no quotes, no commentary. Output only the paraphrased summary.

        Message:
        \(text)

        Summary:
        """
        let messages: [[String: String]] = [
            ["role": "user", "content": prompt],
        ]
        var out = ""
        for await token in completeStream(messages: messages, maxTokens: 60, temperature: 0.2) {
            out += token
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        if let model { cactusDestroy(model) }
    }

    private static func encodeJSON(_ object: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func findModelPath() -> String? {
        guard let url = Bundle.main.resourceURL?
            .appendingPathComponent("Models")
            .appendingPathComponent("gemma-4-e2b-it")
        else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
    }
}
