import SwiftUI

@main
struct MeshNodeApp: App {
    @StateObject private var identity = NodeIdentity()
    @StateObject private var llm = LLMService()
    @StateObject private var stt = STTService()
    @StateObject private var tts = TTSService()
    @StateObject private var audio = AudioRecorder()

    var body: some Scene {
        WindowGroup {
            Group {
                if let nodeID = identity.nodeID {
                    MeshRootView(nodeID: nodeID, llm: llm, stt: stt, tts: tts)
                        .environmentObject(identity)
                        .environmentObject(llm)
                        .environmentObject(stt)
                        .environmentObject(tts)
                        .environmentObject(audio)
                        .id(nodeID)
                } else {
                    NodeSelectionView()
                        .environmentObject(identity)
                }
            }
            .preferredColorScheme(.dark)
            .tint(.tOD)
        }
    }
}

private struct MeshRootView: View {
    let llm: LLMService
    let stt: STTService
    let tts: TTSService
    @StateObject private var mesh: MeshManager
    @StateObject private var summaries: SummaryStore
    @StateObject private var recon: ReconViewModel

    init(nodeID: String, llm: LLMService, stt: STTService, tts: TTSService) {
        self.llm = llm
        self.stt = stt
        self.tts = tts
        _mesh = StateObject(wrappedValue: MeshManager(nodeID: nodeID))
        _summaries = StateObject(wrappedValue: SummaryStore(llm: llm, tts: tts))
        _recon = StateObject(wrappedValue: ReconViewModel(llmService: llm, sttService: stt))
    }

    var body: some View {
        ContentView()
            .environmentObject(mesh)
            .environmentObject(summaries)
            .environmentObject(recon)
            .onAppear {
                mesh.start()
                llm.load()
                stt.load()
            }
    }
}
