import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var identity: NodeIdentity
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Current node") {
                    if let node = identity.currentNode {
                        nodeRow(node, selected: true)
                    } else {
                        Text("Not selected").foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(identity.availableNodes.filter { $0.id != identity.nodeID }) { node in
                        Button {
                            identity.select(node.id)
                            dismiss()
                        } label: {
                            nodeRow(node, selected: false)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Switch to")
                } footer: {
                    Text("Changing the node resets the mesh session on this device.")
                }

            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func nodeRow(_ node: GraphNode, selected: Bool) -> some View {
        HStack {
            Text(node.id).font(.headline)
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
    }
}

#Preview {
    SettingsView().environmentObject(NodeIdentity())
}
