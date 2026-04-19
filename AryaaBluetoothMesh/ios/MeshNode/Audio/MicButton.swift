import SwiftUI

struct MicButton: View {
    enum Size { case compact, hero }

    @EnvironmentObject var audio: AudioRecorder
    @EnvironmentObject var llm: LLMService
    var size: Size = .hero
    let onTranscribed: (String) -> Void

    @State private var isPressing = false

    var body: some View {
        ZStack {
            if audio.isRecording {
                ForEach(0..<3) { i in
                    Circle()
                        .strokeBorder(Color.tOD.opacity(0.28 - Double(i) * 0.08), lineWidth: 1)
                        .frame(width: outer + CGFloat(i) * 18 * CGFloat(audio.level + 0.2),
                               height: outer + CGFloat(i) * 18 * CGFloat(audio.level + 0.2))
                        .animation(.easeOut(duration: 0.18), value: audio.level)
                }
            }
            Circle()
                .fill(background)
                .overlay(
                    Circle().strokeBorder(strokeColor, lineWidth: 1.5)
                )
                .frame(width: diameter, height: diameter)

            Group {
                if llm.isTranscribing {
                    ProgressView().tint(Color.tInk)
                } else {
                    Image(systemName: audio.isRecording ? "mic.fill" : "mic")
                        .font(iconFont)
                        .foregroundStyle(Color.tInk)
                }
            }
        }
        .frame(width: outer, height: outer)
        .contentShape(Circle())
        .opacity(enabled ? 1.0 : 0.35)
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
        llm.isReady && !llm.isTranscribing
    }

    private var diameter: CGFloat {
        size == .hero ? 80 : 44
    }

    private var outer: CGFloat {
        size == .hero ? 120 : 60
    }

    private var iconFont: Font {
        size == .hero ? .system(size: 32, weight: .semibold) : .title2
    }

    private var background: Color {
        if llm.isTranscribing { return Color.tODDim }
        return audio.isRecording ? Color.tAlert : Color.tOD
    }

    private var strokeColor: Color {
        if llm.isTranscribing { return Color.tKhaki }
        return audio.isRecording ? Color.tAlert.opacity(0.8) : Color.tOD.opacity(0.6)
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
        guard let text = await llm.transcribe(audioPath: url.path),
              !text.isEmpty
        else { return }
        onTranscribed(text)
    }
}
