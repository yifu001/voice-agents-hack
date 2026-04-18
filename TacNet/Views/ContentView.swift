import SwiftUI

struct ContentView: View {
    @StateObject private var bootstrapViewModel = AppBootstrapViewModel()
    @StateObject private var treeBuilderViewModel = TreeBuilderViewModel(
        createdBy: ProcessInfo.processInfo.hostName
    )
    @State private var onboardingRoute: OnboardingRoute = .welcome

    private enum OnboardingRoute {
        case welcome
        case createNetwork
        case joinNetwork
    }

    var body: some View {
        Group {
            if bootstrapViewModel.isDownloadComplete {
                mainAppShell
            } else {
                downloadGate
            }
        }
        .task {
            bootstrapViewModel.startIfNeeded()
        }
    }

    private var mainAppShell: some View {
        NavigationStack {
            switch onboardingRoute {
            case .welcome:
                WelcomeView {
                    onboardingRoute = .createNetwork
                } onJoinNetwork: {
                    onboardingRoute = .joinNetwork
                }

            case .createNetwork:
                TreeBuilderView(viewModel: treeBuilderViewModel) {
                    onboardingRoute = .welcome
                }

            case .joinNetwork:
                JoinNetworkPlaceholderView {
                    onboardingRoute = .welcome
                }
            }
        }
    }

    private var downloadGate: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Preparing On-Device AI Model")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Gemma 4 E4B INT4 (~6.7 GB)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: bootstrapViewModel.downloadProgress, total: 1)
                .progressViewStyle(.linear)
                .frame(maxWidth: 260)

            Text(bootstrapViewModel.progressLabel)
                .font(.headline.monospacedDigit())

            if let errorMessage = bootstrapViewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Retry Download") {
                    bootstrapViewModel.retry()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("TacNet features are locked until model download completes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

struct WelcomeView: View {
    let onCreateNetwork: () -> Void
    let onJoinNetwork: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to TacNet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Set up a command tree as organiser or join an existing network.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button("Create Network", action: onCreateNetwork)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                Button("Join Network", action: onJoinNetwork)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Onboarding")
    }
}

struct TreeBuilderView: View {
    @ObservedObject var viewModel: TreeBuilderViewModel
    let onBack: (() -> Void)?

    @State private var networkNameDraft: String
    @State private var pinDraft: String
    @State private var selectedNodeID: String?
    @State private var renameDraft: String
    @State private var newChildLabelDraft: String = ""

    init(viewModel: TreeBuilderViewModel, onBack: (() -> Void)? = nil) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.onBack = onBack
        _networkNameDraft = State(initialValue: viewModel.networkConfig.networkName)
        _pinDraft = State(initialValue: "")
        _selectedNodeID = State(initialValue: viewModel.networkConfig.tree.id)
        _renameDraft = State(initialValue: viewModel.networkConfig.tree.label)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Network Settings") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Network name", text: $networkNameDraft)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Optional PIN", text: $pinDraft)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Apply Settings") {
                                _ = viewModel.updateNetworkName(networkNameDraft)
                                _ = viewModel.updatePin(pinDraft)
                            }
                            .buttonStyle(.borderedProminent)

                            Text("Version \(viewModel.currentVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                GroupBox("Tree") {
                    VStack(alignment: .leading, spacing: 10) {
                        if viewModel.isTreeEmpty {
                            Text("Tree is empty. Add a child node to start building the hierarchy.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        TreeNodeTreeView(
                            node: viewModel.networkConfig.tree,
                            depth: 0,
                            selectedNodeID: selectedNodeID
                        ) { node in
                            selectedNodeID = node.id
                            renameDraft = node.label
                        }
                    }
                }

                GroupBox("Edit Selected Node") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(selectedNodeSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        TextField("Rename selected node", text: $renameDraft)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Rename") {
                                guard let selectedNodeID else { return }
                                _ = viewModel.renameNode(nodeID: selectedNodeID, newLabel: renameDraft)
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedNodeID == nil)

                            Button("Remove", role: .destructive) {
                                guard let selectedNodeID else { return }
                                if viewModel.removeNode(nodeID: selectedNodeID) {
                                    let root = viewModel.networkConfig.tree
                                    self.selectedNodeID = root.id
                                    renameDraft = root.label
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedNodeID == nil)
                        }

                        TextField("New child label", text: $newChildLabelDraft)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Add Child") {
                                let parentID = selectedNodeID ?? viewModel.networkConfig.tree.id
                                guard let created = viewModel.addNode(parentID: parentID, label: newChildLabelDraft) else {
                                    return
                                }
                                selectedNodeID = created.id
                                renameDraft = created.label
                                newChildLabelDraft = ""
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Clear Tree", role: .destructive) {
                                guard viewModel.clearTree() else { return }
                                let root = viewModel.networkConfig.tree
                                selectedNodeID = root.id
                                renameDraft = root.label
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                GroupBox("BLE Distribution JSON") {
                    Text(viewModel.serializedTreeJSON(prettyPrinted: true) ?? "{}")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .navigationTitle("Tree Builder")
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back", action: onBack)
                }
            }
        }
        .onChange(of: selectedNodeID) { newValue in
            guard
                let newValue,
                let node = viewModel.node(withID: newValue)
            else {
                return
            }
            renameDraft = node.label
        }
    }

    private var selectedNodeSummary: String {
        guard
            let selectedNodeID,
            let node = viewModel.node(withID: selectedNodeID)
        else {
            return "No node selected."
        }

        let nodeLabel = node.label.isEmpty ? "(unnamed)" : node.label
        return "Selected: \(nodeLabel) • \(selectedNodeID)"
    }
}

private struct TreeNodeTreeView: View {
    let node: TreeNode
    let depth: Int
    let selectedNodeID: String?
    let onSelect: (TreeNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                onSelect(node)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.label.isEmpty ? "(unnamed node)" : node.label)
                            .font(.subheadline.weight(.medium))
                        Text(node.claimedBy ?? "Available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(node.id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(rowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, CGFloat(depth) * 16)

            ForEach(node.children, id: \.id) { child in
                TreeNodeTreeView(
                    node: child,
                    depth: depth + 1,
                    selectedNodeID: selectedNodeID,
                    onSelect: onSelect
                )
            }
        }
    }

    private var rowBackground: Color {
        selectedNodeID == node.id ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12)
    }
}

private struct JoinNetworkPlaceholderView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
            Text("Join Network")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Network discovery UI will appear here.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Back", action: onBack)
                .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Join")
    }
}

@MainActor
final class AppBootstrapViewModel: ObservableObject {
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var isDownloadComplete = false
    @Published private(set) var errorMessage: String?

    private let downloadService: ModelDownloadService
    private var hasStarted = false

    init(downloadService: ModelDownloadService = .live) {
        self.downloadService = downloadService
    }

    var progressLabel: String {
        "\(Int((downloadProgress * 100).rounded()))%"
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            if await downloadService.canUseTacticalFeatures() {
                downloadProgress = 1
                isDownloadComplete = true
                errorMessage = nil
                return
            }

            do {
                _ = try await downloadService.ensureModelAvailable { [weak self] progress in
                    Task { @MainActor in
                        guard let self else { return }
                        self.downloadProgress = max(self.downloadProgress, progress)
                    }
                }

                downloadProgress = 1
                isDownloadComplete = true
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func retry() {
        hasStarted = false
        errorMessage = nil
        startIfNeeded()
    }
}

#Preview {
    ContentView()
}
