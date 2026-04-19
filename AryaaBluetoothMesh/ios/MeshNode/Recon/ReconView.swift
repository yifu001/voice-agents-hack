import SwiftUI
import UIKit

struct ReconView: View {
    @ObservedObject var viewModel: ReconViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                viewfinder
                controls
                resultsList
            }
            .navigationTitle("Recon")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.prepareIfNeeded() }
        .onDisappear { viewModel.teardown() }
    }

    private var viewfinder: some View {
        Group {
            switch viewModel.cameraService.authorization {
            case .authorized:
                ZStack {
                    CameraPreviewRepresentable(session: viewModel.cameraService.session)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    if let image = viewModel.lastCapturedImage,
                       case .idle = viewModel.status,
                       !viewModel.sightings.isEmpty {
                        boxOverlay(for: image)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

            case .notDetermined:
                permissionHint(
                    title: "Waiting for camera access",
                    subtitle: "MeshNode needs camera access to scan the scene."
                )
            case .denied:
                permissionDeniedView
            }
        }
    }

    @ViewBuilder
    private func boxOverlay(for image: UIImage) -> some View {
        GeometryReader { proxy in
            let imageSize = CGSize(
                width: image.size.width * image.scale,
                height: image.size.height * image.scale
            )
            let scale = min(
                proxy.size.width / imageSize.width,
                proxy.size.height / imageSize.height
            )
            let offsetX = (proxy.size.width - imageSize.width * scale) / 2.0
            let offsetY = (proxy.size.height - imageSize.height * scale) / 2.0

            ForEach(viewModel.sightings) { sighting in
                let rect = sighting.boundingBox.rect(inImageOfSize: imageSize)
                let mapped = CGRect(
                    x: offsetX + rect.origin.x * scale,
                    y: offsetY + rect.origin.y * scale,
                    width: rect.size.width * scale,
                    height: rect.size.height * scale
                )
                Rectangle()
                    .stroke(Color.red.opacity(0.9), lineWidth: 2)
                    .frame(width: mapped.width, height: mapped.height)
                    .position(x: mapped.midX, y: mapped.midY)
                    .overlay(
                        Text(sighting.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
                            .position(x: mapped.midX, y: max(10, mapped.minY - 10))
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            TextField("Custom scan prompt (optional)", text: $viewModel.customIntent, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)

            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.performScan() }
                } label: {
                    HStack {
                        Image(systemName: "scope")
                        Text(scanButtonTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canScan)

                Button("Clear") {
                    viewModel.clearSightings()
                }
                .buttonStyle(.bordered)
                .disabled(
                    viewModel.sightings.isEmpty &&
                    viewModel.lastCapturedImage == nil &&
                    (viewModel.lastAnalysisText?.isEmpty != false)
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var resultsList: some View {
        Group {
            if viewModel.sightings.isEmpty {
                if let analysis = viewModel.lastAnalysisText, !analysis.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Model Analysis", systemImage: "text.viewfinder")
                                .font(.headline)
                            Text(analysis)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if case .error(let message) = viewModel.status {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "binoculars")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No detections yet. Point the camera and tap Scan.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List(viewModel.sightings) { sighting in
                    SightingRow(sighting: sighting)
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func permissionHint(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "camera")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Camera permission denied")
                .font(.headline)
            Text("Open Settings to allow MeshNode to use your camera for on-device image analysis.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding()
    }

    private var canScan: Bool {
        guard viewModel.cameraService.authorization == .authorized else { return false }
        guard viewModel.scanUnavailableMessage == nil else { return false }
        if case .scanning = viewModel.status { return false }
        return true
    }

    private var scanButtonTitle: String {
        switch viewModel.status {
        case .scanning:
            return "Scanning…"
        default:
            return "Scan"
        }
    }

}

private struct SightingRow: View {
    let sighting: TargetSighting

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(sighting.label.capitalized)
                    .font(.headline)
                Spacer()
                if sighting.confidence > 0 {
                    Text(String(format: "%.0f%%", sighting.confidence * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if !sighting.description.isEmpty {
                Text(sighting.description)
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 16) {
                Label(bearingText, systemImage: "safari")
                    .font(.caption.monospacedDigit())

                Label(rangeText, systemImage: rangeSymbol)
                    .font(.caption.monospacedDigit())
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var bearingText: String {
        guard let bearing = sighting.bearingDegreesTrueNorth else { return "--° TN" }
        return String(format: "%03.0f° TN", bearing)
    }

    private var rangeText: String {
        guard let range = sighting.rangeMeters, range.isFinite else { return "-- m" }
        if range >= 1000 {
            return String(format: "%.1f km", range / 1000.0)
        }
        if range >= 100 {
            return String(format: "%.0f m", range)
        }
        return String(format: "%.1f m", range)
    }

    private var rangeSymbol: String {
        switch sighting.rangeSource {
        case .lidar: return "sensor.tag.radiowaves.forward"
        case .pinhole: return "ruler"
        case .unknown: return "questionmark.circle"
        }
    }
}
