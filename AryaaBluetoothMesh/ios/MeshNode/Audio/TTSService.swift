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

    init() {
        synth.delegate = delegate
        delegate.onFinish = { [weak self] in
            Task { @MainActor in self?.isSpeaking = false }
        }
    }

    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
        log.info("TTS speaking: \(text, privacy: .public)")

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        isSpeaking = true
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
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
