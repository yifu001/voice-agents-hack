import Foundation
import os

private let log = Logger(subsystem: "com.cactushack.MeshNode", category: "llm")

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
    private let postProcessor = OutputPostProcessor()

    /// The TacNet soul persona loaded from the bundled soul.md resource.
    static let soulPrompt: String = {
        guard let url = Bundle.main.url(forResource: "soul", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            log.warning("soul.md not found in bundle — using fallback persona")
            return "You are TacNet Personal AI. You are a terse signal relay and compactor. Output is TTS-destined. Be brief. No emoji, no markdown. Maximum 20 words per relay sentence."
        }
        return text
    }()

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

            log.info("LLM complete (maxTokens=\(maxTokens, privacy: .public), temp=\(temperature, privacy: .public)) prompt: \(messagesJSON, privacy: .public)")

            inferenceQueue.async {
                // Clear any prior conversation state so each call is independent.
                cactusReset(model)
                _ = try? cactusComplete(model, messagesJSON, optionsJSON, nil as String?) { token, _ in
                    continuation.yield(token)
                }
                continuation.finish()
            }
        }
    }

    func summarise(_ text: String, role: OutputPostProcessor.EarpieceRole = .summary) async -> String {
        // Merge soul into the user turn so it works even if the model's chat
        // template ignores the system role (Gemma has no native system turn).
        let userPrompt = """
        \(Self.soulPrompt)

        --- TASK ---
        Compact the following operator message into a terse third-person relay. \
        Max \(role.wordCap) words. No preamble, no quotes, no commentary. \
        Output only the compacted relay.

        Message:
        \(text)

        Relay:
        """
        let messages: [[String: String]] = [
            ["role": "user", "content": userPrompt],
        ]
        var out = ""
        for await token in completeStream(messages: messages, maxTokens: 60, temperature: 0.2) {
            out += token
        }
        let raw = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return postProcessor.process(raw, role: role)
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
