import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var identity: NodeIdentity
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        GraphView()
                        GraphLegend()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.tSurface)
                } header: {
                    Text("Mesh graph")
                }

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

                Section {
                    Toggle(isOn: $identity.developerMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Developer mode")
                            Text("Show mesh stats bar in the Node tab.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Diagnostics")
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
