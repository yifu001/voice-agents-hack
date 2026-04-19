import SwiftUI

struct NodeSelectionView: View {
    @EnvironmentObject var identity: NodeIdentity

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if identity.availableNodes.isEmpty {
                        Text("No nodes found in graph.json")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(identity.availableNodes) { node in
                            Button {
                                identity.select(node.id)
                            } label: {
                                HStack {
                                    Text(node.id).font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Select a node identity")
                } footer: {
                    Text("This device will identify as the chosen node in the mesh. You can't enter the app until a node is selected.")
                }
            }
            .navigationTitle("Choose Node")
        }
    }
}

#Preview {
    NodeSelectionView().environmentObject(NodeIdentity())
}
