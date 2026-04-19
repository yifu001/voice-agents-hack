import SwiftUI
import MapKit

struct MapTab: View {
    @EnvironmentObject var mesh: MeshManager
    @EnvironmentObject var identity: NodeIdentity

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedPeer: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    // Show current user location
                    UserAnnotation()

                    // Show each peer as an annotation
                    ForEach(peerAnnotations, id: \.id) { peer in
                        Annotation(peer.label, coordinate: peer.coordinate) {
                            peerMarker(for: peer)
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }

                // Bottom info panel
                peerListOverlay
            }
            .navigationTitle("Squad Map")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Peer annotations

    private var peerAnnotations: [PeerAnnotation] {
        mesh.peerLocations.compactMap { (peerId, location) in
            let label = shortId(peerId)
            let isSelf = peerId == mesh.selfId
            let staleness = Date().timeIntervalSince(location.timestamp)
            return PeerAnnotation(
                id: peerId,
                label: isSelf ? "You" : label,
                coordinate: location.coordinate,
                accuracy: location.accuracy,
                isSelf: isSelf,
                isStale: staleness > 30
            )
        }
    }

    private func peerMarker(for peer: PeerAnnotation) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(peer.isSelf ? Color.blue : (peer.isStale ? Color.gray : Color.green))
                    .frame(width: 32, height: 32)
                Image(systemName: peer.isSelf ? "person.fill" : "person.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
            Text(peer.label)
                .font(.caption2.bold())
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: - Bottom overlay

    private var peerListOverlay: some View {
        VStack(spacing: 0) {
            if peerAnnotations.isEmpty {
                HStack {
                    Image(systemName: "location.slash")
                    Text("No squad positions yet — waiting for GPS + mesh peers")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(peerAnnotations, id: \.id) { peer in
                            peerChip(peer)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(.ultraThinMaterial)
            }
        }
    }

    private func peerChip(_ peer: PeerAnnotation) -> some View {
        Button {
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: peer.coordinate,
                    latitudinalMeters: 200,
                    longitudinalMeters: 200
                ))
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(peer.isSelf ? Color.blue : (peer.isStale ? Color.gray : Color.green))
                    .frame(width: 8, height: 8)
                Text(peer.label)
                    .font(.caption.bold())
                if let acc = peer.accuracy {
                    Text("±\(Int(acc))m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func shortId(_ id: String) -> String {
        String(id.prefix(8))
    }
}

private struct PeerAnnotation {
    let id: String
    let label: String
    let coordinate: CLLocationCoordinate2D
    let accuracy: Double?
    let isSelf: Bool
    let isStale: Bool
}
