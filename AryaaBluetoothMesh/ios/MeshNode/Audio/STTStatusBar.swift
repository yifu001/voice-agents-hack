import SwiftUI

struct STTStatusBar: View {
    @EnvironmentObject var llm: LLMService
    @EnvironmentObject var audio: AudioRecorder

    var body: some View {
        Group {
            if audio.isRecording {
                recordingRow
            } else if llm.isTranscribing {
                simpleRow(text: "Transcribing…", tint: .secondary, showProgress: true)
            } else if case .loading = llm.state {
                simpleRow(text: "Loading model…", tint: .secondary, showProgress: true)
            } else if case .error(let msg) = llm.state {
                simpleRow(text: msg, tint: .orange, icon: "exclamationmark.triangle.fill")
            } else if let err = audio.lastError ?? llm.lastTranscribeError {
                simpleRow(text: err, tint: .orange, icon: "exclamationmark.triangle.fill")
            } else {
                EmptyView()
            }
        }
    }

    private var recordingRow: some View {
        HStack(spacing: 8) {
            Circle().fill(.red).frame(width: 8, height: 8)
                .opacity(audio.level > 0.2 ? 1.0 : 0.4)
            Text(String(format: "Recording  %.1fs", audio.elapsed))
                .foregroundStyle(.red)
                .monospacedDigit()
            levelMeter
            Spacer(minLength: 0)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private var levelMeter: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(Color.red)
                    .frame(width: geo.size.width * CGFloat(audio.level))
            }
        }
        .frame(maxWidth: 80, maxHeight: 6)
    }

    private func simpleRow(text: String, tint: Color, icon: String? = nil, showProgress: Bool = false) -> some View {
        HStack(spacing: 6) {
            if showProgress {
                ProgressView().scaleEffect(0.7)
            } else if let icon {
                Image(systemName: icon).foregroundStyle(tint)
            }
            Text(text).foregroundStyle(tint)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}
