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

    func load() {
        guard case .notLoaded = state else { return }
        state = .loading

        loadQueue.async { [weak self] in
            guard let self else { return }
            let modelPath: String
            do {
                modelPath = try Self.resolveModelPath()
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
                let msg = "parakeet init failed: \(error.localizedDescription)"
                log.error("\(msg, privacy: .public)")
                Task { @MainActor in self.state = .error(msg) }
            }
        }
    }

    func transcribe(audioPath: String) async -> String? {
        guard isReady, let model else { return nil }
        let size = (try? FileManager.default.attributesOfItem(atPath: audioPath)[.size] as? Int) ?? 0
        log.info("Transcribing \(audioPath, privacy: .public) (\(size) bytes)")

        isTranscribing = true
        lastError = nil
        defer { isTranscribing = false }

        let result: Result<String, Error> = await withCheckedContinuation { cont in
            inferenceQueue.async {
                do {
                    let raw = try cactusTranscribe(model, audioPath, nil, nil, nil, nil)
                    cont.resume(returning: .success(raw))
                } catch {
                    cont.resume(returning: .failure(error))
                }
            }
        }

        switch result {
        case .failure(let err):
            let msg = "transcribe failed: \(err.localizedDescription)"
            log.error("\(msg, privacy: .public)")
            lastError = msg
            return nil
        case .success(let raw):
            log.info("Transcribe raw: \(raw, privacy: .public)")
            let text = Self.extractText(from: raw)
            return text.isEmpty ? nil : text
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

    private static func resolveModelPath() throws -> String {
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

        if !fm.fileExists(atPath: writable.path) {
            log.info("First-run: copying \(modelName, privacy: .public) to Application Support…")
            try fm.copyItem(at: bundleURL, to: writable)
        }
        return writable.path
    }
}
