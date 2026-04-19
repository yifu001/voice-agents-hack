import Combine
import Foundation
import os

private let log = Logger(subsystem: "com.cactushack.MeshNode", category: "stt")

@MainActor
final class STTService: ObservableObject {
    enum LoadState: Equatable {
        case notLoaded
        case loading
        case ready
        case error(String)
    }

    @Published private(set) var state: LoadState = .notLoaded
    @Published private(set) var isTranscribing: Bool = false
    @Published private(set) var lastError: String?

    private weak var llm: LLMService?
    private var llmObserver: AnyCancellable?
    private let inferenceQueue = DispatchQueue(label: "cactus.stt.infer", qos: .userInitiated)

    var isReady: Bool { state == .ready }

    /// Bind to the LLMService whose Gemma model will be used for transcription.
    func bind(to llmService: LLMService) {
        self.llm = llmService

        // Stay in sync: if Gemma's state changes (e.g. bad_alloc recovery),
        // mirror that into our own state so the UI reflects reality.
        llmObserver = llmService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] llmState in
                guard let self else { return }
                switch llmState {
                case .ready:
                    if self.state != .ready { self.state = .ready }
                case .notLoaded:
                    if self.state == .ready { self.state = .notLoaded }
                case .loading:
                    if self.state == .ready { self.state = .loading }
                case .error(let msg):
                    self.state = .error(msg)
                }
            }
    }

    func unload() async {
        // Nothing to unload — we don't own the model. Just reset state.
        state = .notLoaded
        lastError = nil
    }

    func load() {
        guard case .notLoaded = state else { return }
        guard let llm else {
            state = .error("STTService not bound to LLMService")
            return
        }

        // If Gemma is already ready, we're ready too.
        if llm.isReady, llm.model != nil {
            state = .ready
            log.info("Gemma STT ready (model already loaded)")
            return
        }

        // Otherwise wait for Gemma to finish loading.
        state = .loading
        log.info("Waiting for Gemma model to load for STT…")
        Task { [weak self] in
            guard let self, let llm = self.llm else { return }
            do {
                try await llm.waitUntilReady()
                self.state = .ready
                log.info("Gemma STT ready")
            } catch {
                let msg = "Gemma load failed: \(error.localizedDescription)"
                log.error("\(msg, privacy: .public)")
                self.state = .error(msg)
            }
        }
    }

    func transcribe(audioPath: String) async -> String? {
        guard isReady, let model = llm?.model else { return nil }
        let size = (try? FileManager.default.attributesOfItem(atPath: audioPath)[.size] as? Int) ?? 0
        log.info("Transcribing \(audioPath, privacy: .public) (\(size) bytes)")

        isTranscribing = true
        lastError = nil
        defer { isTranscribing = false }

        let result = await transcribeRaw(audioPath: audioPath, model: model, optionsJSON: nil)

        switch result {
        case .failure(let err):
            let msg = "transcribe failed: \(err.localizedDescription)"
            log.error("\(msg, privacy: .public)")
            lastError = msg
            return nil
        case .success(let raw):
            log.info("Transcribe raw: \(raw, privacy: .public)")
            let text = Self.extractText(from: raw)
            if !text.isEmpty {
                return text
            }

            // Retry without VAD in case the audio was filtered as silence.
            let fallbackOptions = #"{"use_vad":false}"#
            let fallbackResult = await transcribeRaw(
                audioPath: audioPath,
                model: model,
                optionsJSON: fallbackOptions
            )

            switch fallbackResult {
            case .failure(let err):
                let msg = "transcribe fallback failed: \(err.localizedDescription)"
                log.error("\(msg, privacy: .public)")
                lastError = msg
                return nil
            case .success(let fallbackRaw):
                log.info("Transcribe raw (use_vad=false): \(fallbackRaw, privacy: .public)")
                let fallbackText = Self.extractText(from: fallbackRaw)
                return fallbackText.isEmpty ? nil : fallbackText
            }
        }
    }

    private static func extractText(from raw: String) -> String {
        if let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["response", "text", "transcription"] {
                if let s = json[key] as? String, !s.isEmpty {
                    return s.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            if let segments = json["segments"] as? [[String: Any]] {
                let joined = segments.compactMap { $0["text"] as? String }.joined(separator: " ")
                return joined.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func transcribeRaw(
        audioPath: String,
        model: CactusModelT,
        optionsJSON: String?
    ) async -> Result<String, Error> {
        await withCheckedContinuation { cont in
            inferenceQueue.async {
                do {
                    let raw = try cactusTranscribe(model, audioPath, nil, optionsJSON, nil, nil)
                    cont.resume(returning: .success(raw))
                } catch {
                    cont.resume(returning: .failure(error))
                }
            }
        }
    }
}
