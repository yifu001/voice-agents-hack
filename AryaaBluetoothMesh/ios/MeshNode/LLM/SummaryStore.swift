import Foundation
import os

private let log = Logger(subsystem: "com.cactushack.MeshNode", category: "summary")

@MainActor
final class SummaryStore: ObservableObject {
    enum Status: Equatable {
        case pending
        case done(String)
        case failed(retries: Int)
    }

    @Published private var entries: [String: Status] = [:]
    private var inFlight: Set<String> = []

    /// Original text for each message, kept so retries don't need the caller to re-supply it.
    private var originalTexts: [String: String] = [:]

    private let llm: LLMService
    private let tts: TTSService?

    private static let maxRetries = 3

    init(llm: LLMService, tts: TTSService? = nil) {
        self.llm = llm
        self.tts = tts
    }

    func status(for messageID: String) -> Status? {
        entries[messageID]
    }

    func requestSummary(messageID: String, text: String) {
        // Store original text for potential retries.
        if originalTexts[messageID] == nil {
            originalTexts[messageID] = text
        }

        // Allow retry if previously failed and under retry cap.
        if case .failed(let retries) = entries[messageID] {
            guard retries < Self.maxRetries else {
                log.info("Max retries reached for \(messageID, privacy: .public)")
                return
            }
        } else {
            // Not a retry — skip if already done, pending, or in-flight.
            guard entries[messageID] == nil else { return }
        }

        guard !inFlight.contains(messageID) else { return }

        guard llm.isReady else {
            log.info("Deferring summary for \(messageID, privacy: .public): LLM not ready")
            return
        }

        inFlight.insert(messageID)
        let retryCount = failedRetryCount(for: messageID)
        entries[messageID] = .pending
        log.info("Summarising \(messageID, privacy: .public) (attempt \(retryCount + 1, privacy: .public), \(text.count) chars): \(text, privacy: .public)")

        Task { [weak self] in
            guard let self else { return }
            let summary = await llm.summarise(text)
            log.info("Summary for \(messageID, privacy: .public): '\(summary, privacy: .public)'")
            if summary.isEmpty {
                let newCount = retryCount + 1
                entries[messageID] = .failed(retries: newCount)
                log.warning("Summary failed for \(messageID, privacy: .public) (attempt \(newCount, privacy: .public)/\(Self.maxRetries, privacy: .public))")
            } else {
                entries[messageID] = .done(summary)
                originalTexts.removeValue(forKey: messageID)
                tts?.speak(summary)
            }
            inFlight.remove(messageID)
        }
    }

    /// Re-attempt all failed or deferred summaries. Called when the LLM becomes
    /// ready or after a burst of messages has settled.
    func retryPending() {
        guard llm.isReady else { return }
        for (messageID, status) in entries {
            switch status {
            case .failed(let retries) where retries < Self.maxRetries:
                guard let text = originalTexts[messageID] else { continue }
                log.info("Retrying summary for \(messageID, privacy: .public)")
                requestSummary(messageID: messageID, text: text)
            default:
                break
            }
        }
    }

    private func failedRetryCount(for messageID: String) -> Int {
        if case .failed(let retries) = entries[messageID] { return retries }
        return 0
    }
}
