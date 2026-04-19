import SwiftUI

struct WaveformView: View {
    @EnvironmentObject var audio: AudioRecorder

    private let barCount = 48
    @State private var history: [Float] = Array(repeating: 0, count: 48)

    var body: some View {
        GeometryReader { geo in
            let barWidth: CGFloat = 2
            let spacing: CGFloat = (geo.size.width - CGFloat(barCount) * barWidth) / CGFloat(barCount - 1)
            HStack(alignment: .center, spacing: max(1, spacing)) {
                ForEach(history.indices, id: \.self) { i in
                    let h = max(2, CGFloat(history[i]) * geo.size.height)
                    Capsule()
                        .fill(audio.isRecording ? Color.tOD : Color.tMuted)
                        .frame(width: barWidth, height: h)
                        .opacity(audio.isRecording ? 1.0 : 0.35)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .animation(.easeOut(duration: 0.08), value: history)
        }
        .frame(height: 44)
        .onChange(of: audio.level) { _, newLevel in
            history.removeFirst()
            history.append(newLevel)
        }
        .onChange(of: audio.isRecording) { _, recording in
            if !recording {
                history = Array(repeating: 0, count: barCount)
            }
        }
    }
}
