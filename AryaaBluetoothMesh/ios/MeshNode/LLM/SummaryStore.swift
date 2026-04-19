import Foundation
import os

private let log = Logger(subsystem: "com.cactushack.MeshNode", category: "summary")

@MainActor
final class SummaryStore: ObservableObject {
    enum Status: Equatable {
        case pending
        case done(String)
        case failed
    }

    @Published private var entries: [String: Status] = [:]
    private var inFlight: Set<String> = []

    private let llm: LLMService
    private let tts: TTSService?

    init(llm: LLMService, tts: TTSService? = nil) {
        self.llm = llm
        self.tts = tts
    }

    func status(for messageID: String) -> Status? {
        entries[messageID]
    }

    func requestSummary(messageID: String, text: String) {
        guard entries[messageID] == nil, !inFlight.contains(messageID) else { return }
        guard llm.isReady else {
            log.info("Skipping summary for \(messageID, privacy: .public): LLM not ready")
            return
        }
        inFlight.insert(messageID)
        entries[messageID] = .pending
        log.info("Summarising \(messageID, privacy: .public) (\(text.count) chars): \(text, privacy: .public)")

        Task { [weak self] in
            guard let self else { return }
            let summary = await llm.summarise(text)
            log.info("Summary for \(messageID, privacy: .public): '\(summary, privacy: .public)'")
            if summary.isEmpty {
                entries[messageID] = .failed
            } else {
                entries[messageID] = .done(summary)
                tts?.speak(summary)
            }
            inFlight.remove(messageID)
        }
    }
}
