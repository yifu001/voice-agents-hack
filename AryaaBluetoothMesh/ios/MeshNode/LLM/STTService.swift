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

    private var model: CactusModelT?
    private let loadQueue = DispatchQueue(label: "cactus.stt.load", qos: .userInitiated)
    private let inferenceQueue = DispatchQueue(label: "cactus.stt.infer", qos: .userInitiated)

    var isReady: Bool { state == .ready }

    func unload() async {
        guard let handle = model else {
            state = .notLoaded
            lastError = nil
            return
        }

        log.info("Parakeet unloading to free memory")
        model = nil
        state = .notLoaded
        lastError = nil

        await withCheckedContinuation { continuation in
            inferenceQueue.async {
                cactusStop(handle)
                cactusDestroy(handle)
                continuation.resume()
            }
        }
    }

    func load() {
        guard case .notLoaded = state else { return }
        state = .loading

        loadQueue.async { [weak self] in
            guard let self else { return }
            self.loadModel(forceRefresh: false)
        }
    }

    func transcribe(audioPath: String) async -> String? {
        guard isReady, let model else { return nil }
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

            // Some recordings get filtered out as "all silence" by the default
            // Parakeet CTC VAD pass. Retry once without VAD before giving up.
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

    deinit {
        if let model { cactusDestroy(model) }
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

    private func loadModel(forceRefresh: Bool) {
        let modelPath: String
        do {
            modelPath = try Self.resolveModelPath(forceRefresh: forceRefresh)
        } catch {
            let msg = "Parakeet path: \(error.localizedDescription)"
            log.error("\(msg, privacy: .public)")
            Task { @MainActor in self.state = .error(msg) }
            return
        }

        log.info("Parakeet loading from \(modelPath, privacy: .public)")
        do {
            let handle = try cactusInit(modelPath, nil, false)
            Task { @MainActor in
                self.model = handle
                self.state = .ready
                log.info("Parakeet ready")
            }
        } catch {
            let description = error.localizedDescription
            if !forceRefresh, description.contains("Cannot map file") {
                log.warning("Parakeet mmap failed, recopying model bundle and retrying once")
                loadModel(forceRefresh: true)
                return
            }

            let msg = "parakeet init failed: \(description)"
            log.error("\(msg, privacy: .public)")
            Task { @MainActor in self.state = .error(msg) }
        }
    }

    private static func resolveModelPath(forceRefresh: Bool = false) throws -> String {
        let fm = FileManager.default
        let modelName = "parakeet-ctc-0.6b"

        guard let bundleURL = Bundle.main.resourceURL?
            .appendingPathComponent("Models")
            .appendingPathComponent(modelName),
              fm.fileExists(atPath: bundleURL.path)
        else {
            throw NSError(domain: "STT", code: 1, userInfo: [NSLocalizedDescriptionKey: "model not in bundle"])
        }

        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
        let writable = appSupport.appendingPathComponent(modelName)

        if forceRefresh, fm.fileExists(atPath: writable.path) {
            try? fm.removeItem(at: writable)
        } else if fm.fileExists(atPath: writable.path) {
            // Verify the copy is intact — check a known weight file exists.
            let probe = writable.appendingPathComponent("layer_0_conv_pointwise1.weights")
            if !fm.fileExists(atPath: probe.path) {
                log.warning("Parakeet copy is incomplete — deleting and re-copying")
                try? fm.removeItem(at: writable)
            }
        }

        if !fm.fileExists(atPath: writable.path) {
            log.info("Copying \(modelName, privacy: .public) to Application Support…")
            try fm.copyItem(at: bundleURL, to: writable)
        }
        return writable.path
    }
}
