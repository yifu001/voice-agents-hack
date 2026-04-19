import SwiftUI

struct RetrievalView: View {
    @EnvironmentObject var mesh: MeshManager
    @EnvironmentObject var identity: NodeIdentity
    @EnvironmentObject var llm: LLMService
    @EnvironmentObject var audio: AudioRecorder

    @State private var question: String = ""
    @State private var composedPrompt: String?
    @State private var answer: String = ""
    @State private var isStreaming: Bool = false
    @State private var streamTask: Task<Void, Never>?

    private let postProcessor = OutputPostProcessor()

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
        VStack(spacing: 14) {
            HStack {
                Stepper(value: $identity.contextRadius, in: 0...10) {
                    HStack(spacing: 6) {
                        Text("CONTEXT RADIUS")
                            .font(.caption2.monospaced()).tracking(2)
                            .foregroundStyle(Color.tMuted)
                        Text("\(identity.contextRadius)")
                            .font(.callout.monospacedDigit().bold())
                            .foregroundStyle(Color.tKhaki)
                    }
                }
                Spacer(minLength: 0)
                llmStatus
            }
            .padding(.horizontal)

            WaveformView().padding(.horizontal, 20)

            MicButton(size: .hero) { text in
                question = text
            }

            Text(audio.isRecording ? "RELEASE TO TRANSCRIBE" : "HOLD TO SPEAK")
                .font(.caption2.monospaced()).tracking(2)
                .foregroundStyle(Color.tMuted)

            STTStatusBar()

            HStack(spacing: 8) {
                TextField("type instead…", text: $question, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.tSurface2)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.tODDim, lineWidth: 1))
                    .font(.callout)
                    .lineLimit(1...4)
                if isStreaming {
                    Button(action: cancel) {
                        Text("STOP")
                            .font(.caption.monospaced()).bold().tracking(2)
                            .frame(width: 70, height: 40)
                            .background(Color.tAlert)
                            .foregroundStyle(Color.tInk)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                } else {
                    Button(action: start) {
                        Text("ANSWER")
                            .font(.caption.monospaced()).bold().tracking(2)
                            .frame(width: 70, height: 40)
                            .background(canAsk ? Color.tOD : Color.tODDim)
                            .foregroundStyle(Color.tInk)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .disabled(!canAsk)
                }
            }
            .padding(.horizontal)

            if let selfID = identity.nodeID {
                Text("NODE \(selfID) · RADIUS \(identity.contextRadius)")
                    .font(.caption2.monospaced()).tracking(1.5)
                    .foregroundStyle(Color.tMuted)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.tSurface)
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
                if identity.developerMode, let composedPrompt {
                    section(title: "Prompt", body: composedPrompt, mono: true)
                }
                if answer.isEmpty && composedPrompt == nil {
                    Text("Hold the mic or type a question, then tap ANSWER.")
                        .font(.callout)
                        .foregroundStyle(Color.tMuted)
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

    /// Max number of recent messages to include in the LLM context.
    /// Gemma 2B has a small context window (~2-4K tokens); keeping this
    /// low prevents the prompt from being silently truncated.
    private static let maxContextMessages = 20
    /// Hard character cap for the chat-context block (~4 chars ≈ 1 token).
    private static let maxContextChars = 1500

    private func start() {
        guard let selfID = identity.nodeID else { return }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let reachable = identity.nodesWithinRadius(identity.contextRadius, from: selfID)
        // Take only the most recent messages that fit the budget.
        let relevant = mesh.messages
            .filter { reachable.contains($0.senderId) }
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(Self.maxContextMessages)

        let contextBlock: String
        if relevant.isEmpty {
            contextBlock = "(no messages in context)"
        } else {
            var lines: [String] = []
            var charBudget = Self.maxContextChars
            // Build from most-recent backwards, then reverse so oldest is first.
            for msg in relevant.reversed() {
                let short = String(msg.senderId.prefix(6))
                let ago = Self.relativeTime(msg.timestamp)
                let line = "\(short) (\(ago)): \(msg.payload)"
                if charBudget - line.count < 0 { break }
                charBudget -= line.count
                lines.append(line)
            }
            contextBlock = lines.reversed().joined(separator: "\n")
        }

        let reachableList = reachable.map { String($0.prefix(6)) }
            .sorted().joined(separator: ", ")

        let userPrompt = """
        Nodes: \(reachableList)
        --- Chat context (recent) ---
        \(contextBlock)
        --- Question ---
        \(trimmed)
        Answer concisely in Ranger-net register. Max 20 words.
        """

        composedPrompt = userPrompt
        answer = ""
        isStreaming = true

        streamTask = Task {
            // Merge soul into user turn — Gemma has no native system role.
            let fullPrompt = LLMService.soulPrompt + "\n\n--- TASK ---\n" + userPrompt
            let messages: [[String: String]] = [
                ["role": "user", "content": fullPrompt],
            ]
            var raw = ""
            for await token in llm.completeStream(messages: messages, maxTokens: 256) {
                if Task.isCancelled { break }
                raw += token
            }
            answer = postProcessor.process(raw, role: .leader)
            isStreaming = false
        }
    }

    private static func relativeTime(_ epochMs: Int64) -> String {
        let seconds = Int(Date().timeIntervalSince1970) - Int(epochMs / 1000)
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
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
