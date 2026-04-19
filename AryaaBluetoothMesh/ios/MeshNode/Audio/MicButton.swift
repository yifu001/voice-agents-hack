import SwiftUI

struct MicButton: View {
    @EnvironmentObject var audio: AudioRecorder
    @EnvironmentObject var stt: STTService
    let onTranscribed: (String) -> Void

    @State private var isPressing = false

    var body: some View {
        Group {
            if stt.isTranscribing {
                ProgressView().tint(.white)
            } else {
                Image(systemName: audio.isRecording ? "mic.fill" : "mic")
                    .font(.title2)
            }
        }
        .frame(width: 44, height: 44)
        .background(background)
        .foregroundStyle(.white)
        .clipShape(Circle())
        .scaleEffect(audio.isRecording ? 1.0 + CGFloat(audio.level) * 0.25 : 1.0)
        .animation(.easeOut(duration: 0.08), value: audio.level)
        .opacity(enabled ? 1.0 : 0.4)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard enabled, !isPressing else { return }
                    isPressing = true
                    Task { await begin() }
                }
                .onEnded { _ in
                    guard isPressing else { return }
                    isPressing = false
                    Task { await end() }
                }
        )
    }

    private var enabled: Bool {
        stt.isReady && !stt.isTranscribing
    }

    private var background: Color {
        if stt.isTranscribing { return .blue }
        return audio.isRecording ? .red : .accentColor
    }

    private func begin() async {
        do {
            try await audio.start()
        } catch {
            isPressing = false
        }
    }

    private func end() async {
        guard let url = audio.stop() else { return }
        defer { try? FileManager.default.removeItem(at: url) }
        guard let text = await stt.transcribe(audioPath: url.path),
              !text.isEmpty
        else { return }
        onTranscribed(text)
    }
}
