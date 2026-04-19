import AVFoundation
import SwiftUI
import os

private let log = Logger(subsystem: "com.cactushack.MeshNode", category: "tts")

@MainActor
final class TTSService: ObservableObject {
    @AppStorage("ttsEnabled") var isEnabled = true
    @Published var isSpeaking = false

    private let synth = AVSpeechSynthesizer()
    private let delegate = SynthDelegate()
    /// FIFO queue so utterances play in the order they were enqueued,
    /// even if summaries complete out of order.
    private var queue: [String] = []
    private var isPlaying = false

    init() {
        synth.delegate = delegate
        delegate.onFinish = { [weak self] in
            Task { @MainActor in self?.utteranceFinished() }
        }
    }

    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
        log.info("TTS enqueue: \(text, privacy: .public)")
        queue.append(text)
        playNext()
    }

    func stop() {
        queue.removeAll()
        synth.stopSpeaking(at: .immediate)
        isPlaying = false
        isSpeaking = false
    }

    private func playNext() {
        guard !isPlaying, let next = queue.first else { return }
        queue.removeFirst()
        log.info("TTS speaking: \(next, privacy: .public)")

        let utterance = AVSpeechUtterance(string: next)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        isPlaying = true
        isSpeaking = true
        synth.speak(utterance)
    }

    private func utteranceFinished() {
        isPlaying = false
        if queue.isEmpty {
            isSpeaking = false
        } else {
            playNext()
        }
    }
}

// AVSpeechSynthesizerDelegate must be an NSObject, so we use a helper.
private final class SynthDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
}
