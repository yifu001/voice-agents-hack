import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mesh: MeshManager
    @EnvironmentObject var identity: NodeIdentity
    @EnvironmentObject var summaries: SummaryStore
    @EnvironmentObject var llm: LLMService
    @EnvironmentObject var tts: TTSService

    var body: some View {
        TabView {
            ChatTab(title: "All", messages: mesh.messages)
                .tabItem { Label("All", systemImage: "bubble.left.and.bubble.right") }
            ChatTab(title: "Node", messages: nodeMessages)
                .tabItem { Label("Node", systemImage: "person.crop.circle") }
            RetrievalView()
                .tabItem { Label("Retrieval", systemImage: "sparkles.rectangle.stack") }
        }
        .hideKeyboardOnTap()
        .onChange(of: mesh.messages.count) { _, _ in kickOffPendingSummaries() }
        .onChange(of: llm.state) { _, newValue in
            if newValue == .ready { kickOffPendingSummaries() }
        }
    }

    private func kickOffPendingSummaries() {
        guard llm.isReady else { return }
        for msg in mesh.messages where msg.senderId != mesh.selfId {
            if identity.incomingEdgeType(fromSenderID: msg.senderId) == .summary {
                summaries.requestSummary(messageID: msg.id, text: msg.payload)
            }
        }
    }

    private var nodeMessages: [MeshMessage] {
        mesh.messages.compactMap { msg in
            if msg.senderId == mesh.selfId { return msg }
            guard let edgeType = identity.incomingEdgeType(fromSenderID: msg.senderId) else {
                return nil
            }
            switch edgeType {
            case .exact:
                return msg
            case .summary:
                let summaryPayload: String
                switch summaries.status(for: msg.id) {
                case .done(let s):
                    summaryPayload = "SUMMARY: " + s
                case .pending:
                    summaryPayload = "Summarising…"
                case .failed:
                    summaryPayload = "SUMMARY: " + msg.payload
                case .none:
                    summaryPayload = llm.isReady ? "Summarising…" : "(awaiting model) " + msg.payload
                }
                return MeshMessage(
                    senderId: msg.senderId,
                    msgId: msg.msgId,
                    ttl: msg.ttl,
                    timestamp: msg.timestamp,
                    payload: summaryPayload
                )
            }
        }
    }
}

private struct ChatTab: View {
    @EnvironmentObject var mesh: MeshManager
    @EnvironmentObject var identity: NodeIdentity
    let title: String
    let messages: [MeshMessage]
    @State private var draft: String = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                debugBar
                Divider()
                messageList
                Divider()
                composer
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                        .environmentObject(identity)
                        .environmentObject(tts)
            }
        }
    }

    private var navTitle: String {
        let node = identity.currentNode.map { " · \($0.id)" } ?? ""
        return "\(title)\(node)"
    }

    private var debugBar: some View {
        HStack(spacing: 8) {
            stat("Peers", mesh.connectedPeerCount)
            stat("Sent",  mesh.sentCount)
            stat("Recv",  mesh.receivedCount)
            stat("Fwd",   mesh.forwardedCount)
            stat("Dedup", mesh.dedupedCount)
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label).foregroundStyle(.secondary)
            Text("\(value)").bold()
        }
        .frame(maxWidth: .infinity)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { msg in
                        messageRow(msg).id(msg.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func messageRow(_ msg: MeshMessage) -> some View {
        let isSelf = msg.senderId == mesh.selfId
        return HStack {
            if isSelf { Spacer() }
            VStack(alignment: isSelf ? .trailing : .leading, spacing: 2) {
                Text(msg.payload)
                    .padding(8)
                    .background(isSelf ? Color.accentColor.opacity(0.2)
                                       : Color(uiColor: .systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text("\(shortId(msg.senderId)) · TTL \(msg.ttl)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !isSelf { Spacer() }
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            STTStatusBar()
            HStack(spacing: 8) {
                TextField("Message", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .submitLabel(.send)
                    .onSubmit(sendDraft)
                MicButton { text in
                    mesh.send(text: text)
                }
                Button("Send", action: sendDraft)
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
    }

    private func sendDraft() {
        mesh.send(text: draft)
        draft = ""
    }

    private func shortId(_ id: String) -> String {
        String(id.prefix(8))
    }
}

#Preview {
    ContentView()
        .environmentObject(MeshManager(nodeID: "PREVIEW"))
        .environmentObject(NodeIdentity())
}
