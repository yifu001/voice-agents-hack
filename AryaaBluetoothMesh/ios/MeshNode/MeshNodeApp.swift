import SwiftUI

@main
struct MeshNodeApp: App {
    @StateObject private var identity = NodeIdentity()
    @StateObject private var llm = LLMService()
    @StateObject private var stt = STTService()
    @StateObject private var audio = AudioRecorder()

    var body: some Scene {
        WindowGroup {
            if let nodeID = identity.nodeID {
                MeshRootView(nodeID: nodeID, llm: llm, stt: stt)
                    .environmentObject(identity)
                    .environmentObject(llm)
                    .environmentObject(stt)
                    .environmentObject(audio)
                    .id(nodeID)
            } else {
                NodeSelectionView()
                    .environmentObject(identity)
            }
        }
    }
}

private struct MeshRootView: View {
    let llm: LLMService
    let stt: STTService
    @StateObject private var mesh: MeshManager
    @StateObject private var summaries: SummaryStore

    init(nodeID: String, llm: LLMService, stt: STTService) {
        self.llm = llm
        self.stt = stt
        _mesh = StateObject(wrappedValue: MeshManager(nodeID: nodeID))
        _summaries = StateObject(wrappedValue: SummaryStore(llm: llm))
    }

    var body: some View {
        ContentView()
            .environmentObject(mesh)
            .environmentObject(summaries)
            .onAppear {
                mesh.start()
                llm.load()
                stt.load()
            }
    }
}
