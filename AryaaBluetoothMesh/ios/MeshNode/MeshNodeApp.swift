import SwiftUI

@main
struct MeshNodeApp: App {
    // ⚠️  ROTATE-ME: hackathon-only inline key. This was pasted in chat so it is
    // already compromised — rotate at cactuscompute.com/dashboard after the demo
    // and move the replacement into an xcconfig/Info.plist + .gitignore pattern.
    // Cactus reads this via std::getenv in resolve_cloud_api_key (cactus_cloud.cpp:42).
    private static let cactusCloudKey = "cactus_live_a77e42902cf8cf5b054c38bb6be6f35d"

    @StateObject private var identity = NodeIdentity()
    @StateObject private var llm: LLMService
    @StateObject private var tts = TTSService()
    @StateObject private var audio = AudioRecorder()

    init() {
        // Publish the Cactus cloud key to the environment BEFORE LLMService loads,
        // so auto_handoff has a key to send on the first completion.
        setenv("CACTUS_CLOUD_KEY", Self.cactusCloudKey, 1)
        _llm = StateObject(wrappedValue: LLMService())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let nodeID = identity.nodeID {
                    MeshRootView(nodeID: nodeID, llm: llm, tts: tts)
                        .environmentObject(identity)
                        .environmentObject(llm)
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
    let tts: TTSService
    @StateObject private var mesh: MeshManager
    @StateObject private var summaries: SummaryStore
    @StateObject private var recon: ReconViewModel

    init(nodeID: String, llm: LLMService, tts: TTSService) {
        self.llm = llm
        self.tts = tts
        _mesh = StateObject(wrappedValue: MeshManager(nodeID: nodeID))
        _summaries = StateObject(wrappedValue: SummaryStore(llm: llm, tts: tts))
        // Recon still takes an optional STTService for its scan-time memory
        // juggling. We no longer load STT at all, so pass nil — Recon handles it.
        _recon = StateObject(wrappedValue: ReconViewModel(llmService: llm, sttService: nil))
    }

    var body: some View {
        ContentView()
            .environmentObject(mesh)
            .environmentObject(summaries)
            .environmentObject(recon)
            .onAppear {
                mesh.start()
                llm.load()
                // STT deliberately not loaded — Gemma handles transcription now.
            }
    }
}
