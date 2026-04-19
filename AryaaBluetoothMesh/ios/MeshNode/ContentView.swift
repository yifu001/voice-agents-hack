import SwiftUI

struct DisplayMessage: Identifiable {
    enum Style { case standard, paraphrased, awaiting }
    let message: MeshMessage
    let style: Style
    let displayPayload: String
    var id: String { message.id }
}

struct ContentView: View {
    @EnvironmentObject var mesh: MeshManager
    @EnvironmentObject var identity: NodeIdentity
    @EnvironmentObject var summaries: SummaryStore
    @EnvironmentObject var llm: LLMService
    @EnvironmentObject var tts: TTSService
    @EnvironmentObject var recon: ReconViewModel

    @State private var spokenIDs: Set<String> = []
    @State private var retryTask: Task<Void, Never>?

    var body: some View {
        TabView {
            ChatTab(messages: nodeMessages)
                .tabItem { Label("Node", systemImage: "person.crop.square") }
            if identity.developerMode {
                ChatTab(overrideTitle: "ALL", messages: allMessages)
                    .tabItem { Label("All", systemImage: "bubble.left.and.bubble.right") }
            }
            MapTab()
                .tabItem { Label("Map", systemImage: "map") }
            RetrievalView()
                .tabItem { Label("Retrieval", systemImage: "sparkles.rectangle.stack") }
            ReconView(viewModel: recon)
                .tabItem { Label("Recon", systemImage: "viewfinder") }
        }
        .hideKeyboardOnTap()
        .onChange(of: mesh.messages.count) { _, _ in
            kickOffPendingSummaries()
            speakExactMessages()
            // After a burst settles, retry any that failed during the burst.
            scheduleRetry()
        }
        .onChange(of: llm.state) { _, newValue in
            if newValue == .ready {
                kickOffPendingSummaries()
                summaries.retryPending()
            }
        }
    }

    private var allMessages: [DisplayMessage] {
        mesh.messages.map { msg in
            DisplayMessage(message: msg, style: .standard, displayPayload: msg.payload)
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

    /// Debounced retry: waits 2 seconds after the last message burst, then
    /// retries any failed summaries. Cancels the previous timer if a new
    /// message arrives before it fires, so we don't hammer the LLM mid-burst.
    private func scheduleRetry() {
        retryTask?.cancel()
        retryTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            summaries.retryPending()
        }
    }

    private func speakExactMessages() {
        for msg in mesh.messages where msg.senderId != mesh.selfId {
            guard !spokenIDs.contains(msg.id) else { continue }
            if identity.incomingEdgeType(fromSenderID: msg.senderId) == .exact {
                spokenIDs.insert(msg.id)
                tts.speak(msg.payload)
            }
        }
    }

    private var nodeMessages: [DisplayMessage] {
        mesh.messages.compactMap { msg in
            if msg.senderId == mesh.selfId {
                return DisplayMessage(message: msg, style: .standard, displayPayload: msg.payload)
            }
            guard let edgeType = identity.incomingEdgeType(fromSenderID: msg.senderId) else {
                return nil
            }
            switch edgeType {
            case .exact:
                return DisplayMessage(message: msg, style: .standard, displayPayload: msg.payload)
            case .summary:
                switch summaries.status(for: msg.id) {
                case .done(let s):
                    return DisplayMessage(message: msg, style: .paraphrased, displayPayload: s)
                case .failed:
                    // Show original text as fallback while retries may still be pending.
                    return DisplayMessage(message: msg, style: .paraphrased, displayPayload: msg.payload)
                case .pending:
                    return DisplayMessage(message: msg, style: .awaiting, displayPayload: "…")
                case .none:
                    if llm.isReady {
                        return DisplayMessage(message: msg, style: .awaiting, displayPayload: "…")
                    } else {
                        return DisplayMessage(message: msg, style: .awaiting, displayPayload: "awaiting model — " + msg.payload)
                    }
                }
            }
        }
    }
}

private struct ChatTab: View {
    @EnvironmentObject var mesh: MeshManager
    @EnvironmentObject var identity: NodeIdentity
    var overrideTitle: String? = nil
    let messages: [DisplayMessage]
    @State private var draft: String = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if identity.developerMode {
                    debugBar
                    Divider()
                }
                messageList
                Divider()
                composer
            }
            .background(Color.tBG)
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
            }
        }
    }

    private var navTitle: String {
        if let overrideTitle { return overrideTitle }
        return identity.currentNode.map { "NODE \($0.id)" } ?? "NODE"
    }

    private var debugBar: some View {
        HStack(spacing: 8) {
            stat("PEERS", mesh.connectedPeerCount)
            stat("SENT",  mesh.sentCount)
            stat("RECV",  mesh.receivedCount)
            stat("FWD",   mesh.forwardedCount)
            stat("DEDUP", mesh.dedupedCount)
        }
        .font(.caption2.monospacedDigit())
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.tSurface)
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label).foregroundStyle(Color.tMuted)
            Text("\(value)").foregroundStyle(Color.tKhaki).bold()
        }
        .frame(maxWidth: .infinity)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(messages) { row in
                        messageRow(row).id(row.id)
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

    @ViewBuilder
    private func messageRow(_ row: DisplayMessage) -> some View {
        let isSelf = row.message.senderId == mesh.selfId
        HStack(alignment: .top) {
            if isSelf { Spacer(minLength: 40) }
            if !isSelf && row.style == .paraphrased {
                Rectangle()
                    .fill(Color.tKhaki)
                    .frame(width: 2)
            }
            VStack(alignment: isSelf ? .trailing : .leading, spacing: 4) {
                if !isSelf && row.style == .paraphrased {
                    Text("PARAPHRASED")
                        .font(.caption2.monospaced())
                        .tracking(1.5)
                        .foregroundStyle(Color.tKhaki)
                }
                Text(row.displayPayload)
                    .italic(row.style == .paraphrased || row.style == .awaiting)
                    .foregroundStyle(row.style == .awaiting ? Color.tMuted : Color.tInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(bubbleBackground(isSelf: isSelf, style: row.style))
                    .overlay(bubbleBorder(isSelf: isSelf, style: row.style))
                Text(meta(for: row.message))
                    .font(.caption2.monospaced())
                    .tracking(0.5)
                    .foregroundStyle(Color.tMuted)
            }
            if !isSelf && row.style != .paraphrased {
                Spacer(minLength: 40)
            }
        }
    }

    private func bubbleBackground(isSelf: Bool, style: DisplayMessage.Style) -> some View {
        if isSelf {
            return Color.tOD.opacity(0.28)
        } else if style == .paraphrased {
            return Color.tSurface2
        } else {
            return Color.tSurface
        }
    }

    @ViewBuilder
    private func bubbleBorder(isSelf: Bool, style: DisplayMessage.Style) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        if isSelf {
            shape.strokeBorder(Color.tOD.opacity(0.45), lineWidth: 1)
        } else if style == .paraphrased {
            shape.strokeBorder(Color.tKhaki.opacity(0.4), lineWidth: 1)
        } else {
            shape.strokeBorder(Color.tODDim.opacity(0.6), lineWidth: 1)
        }
    }

    private func meta(for msg: MeshMessage) -> String {
        "\(shortId(msg.senderId)) · TTL \(msg.ttl)"
    }

    private var composer: some View {
        VStack(spacing: 10) {
            STTStatusBar()
            WaveformView()
                .padding(.horizontal, 20)
            MicButton(size: .hero) { text in
                mesh.send(text: text)
            }
            Text("HOLD TO SPEAK")
                .font(.caption2.monospaced())
                .tracking(2)
                .foregroundStyle(Color.tMuted)
            HStack(spacing: 8) {
                TextField("type instead…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.tSurface2)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.tODDim, lineWidth: 1))
                    .font(.callout)
                    .lineLimit(1...3)
                    .submitLabel(.send)
                    .onSubmit(sendDraft)
                Button(action: sendDraft) {
                    Image(systemName: "arrow.up")
                        .font(.body.bold())
                        .frame(width: 40, height: 40)
                        .background(draft.trimmingCharacters(in: .whitespaces).isEmpty ? Color.tODDim : Color.tOD)
                        .foregroundStyle(Color.tInk)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.tSurface)
    }

    private func sendDraft() {
        mesh.send(text: draft)
        draft = ""
    }

    private func shortId(_ id: String) -> String {
        String(id.prefix(8))
    }
}

private extension Text {
    func italic(_ on: Bool) -> Text {
        on ? self.italic() : self
    }
}

#Preview {
    ContentView()
        .environmentObject(MeshManager(nodeID: "PREVIEW"))
        .environmentObject(NodeIdentity())
        .environmentObject(LLMService())
}
