import SwiftUI

struct RetrievalView: View {
    @EnvironmentObject var mesh: MeshManager
    @EnvironmentObject var identity: NodeIdentity
    @EnvironmentObject var llm: LLMService

    @State private var question: String = ""
    @State private var composedPrompt: String?
    @State private var answer: String = ""
    @State private var isStreaming: Bool = false
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                composer
                Divider()
                output
            }
            .navigationTitle("Retrieval")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper(value: $identity.contextRadius, in: 0...10) {
                HStack {
                    Text("Context radius").font(.subheadline)
                    Spacer()
                    Text("\(identity.contextRadius)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ask a question")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    llmStatus
                }
                HStack(spacing: 8) {
                    TextField("Your question…", text: $question, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                    MicButton { text in
                        question = text
                    }
                }
                STTStatusBar()
                HStack {
                    if let selfID = identity.nodeID {
                        Text("Node \(selfID) · radius \(identity.contextRadius)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isStreaming {
                        Button("Stop", role: .destructive) { cancel() }
                    } else {
                        Button("Answer", action: start)
                            .buttonStyle(.borderedProminent)
                            .disabled(!canAsk)
                    }
                }
            }
        }
        .padding()
    }

    private var llmStatus: some View {
        Group {
            switch llm.state {
            case .notLoaded:
                Label("LLM idle", systemImage: "circle")
            case .loading:
                Label("Loading model…", systemImage: "hourglass")
            case .ready:
                Label("LLM ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .error(let msg):
                Label(msg, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption2)
    }

    private var canAsk: Bool {
        !question.trimmingCharacters(in: .whitespaces).isEmpty
            && identity.nodeID != nil
            && llm.isReady
    }

    private var output: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !answer.isEmpty {
                    section(title: "Answer", body: answer, mono: false)
                }
                if let composedPrompt {
                    section(title: "Prompt", body: composedPrompt, mono: true)
                }
                if answer.isEmpty && composedPrompt == nil {
                    Text("Ask a question to generate a prompt and stream an answer.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
    }

    private func section(title: String, body: String, mono: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(body)
                .font(mono ? .system(.footnote, design: .monospaced) : .body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func start() {
        guard let selfID = identity.nodeID else { return }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let reachable = identity.nodesWithinRadius(identity.contextRadius, from: selfID)
        let relevant = mesh.messages
            .filter { reachable.contains($0.senderId) }
            .sorted { $0.timestamp < $1.timestamp }

        let contextBlock = relevant.isEmpty
            ? "(no messages in context)"
            : relevant.map { "[\($0.timestamp)] Node \($0.senderId): \($0.payload)" }
                .joined(separator: "\n")

        let reachableList = reachable.sorted().joined(separator: ", ")

        let prompt = """
        Reachable nodes within radius \(identity.contextRadius): \(reachableList)

        --- Chat context ---
        \(contextBlock)

        --- Question ---
        \(trimmed)

        --- Instructions ---
        Answer the user's question after understanding the full context of the situation above. Be concise and factual; if the context is insufficient, say so explicitly.
        """

        composedPrompt = prompt
        answer = ""
        isStreaming = true

        streamTask = Task {
            let messages: [[String: String]] = [
                ["role": "user", "content": prompt],
            ]
            for await token in llm.completeStream(messages: messages, maxTokens: 512) {
                if Task.isCancelled { break }
                answer += token
            }
            isStreaming = false
        }
    }

    private func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }
}

#Preview {
    RetrievalView()
        .environmentObject(MeshManager(nodeID: "A"))
        .environmentObject(NodeIdentity())
        .environmentObject(LLMService())
}
