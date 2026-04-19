import SwiftUI
import UIKit

/// Battlefield-scan tab. Drives `ReconViewModel` to capture a photo, run Gemma 4 E4B on-device
/// for object detection, fuse the result with heading + LiDAR/pinhole range, and render each
/// detection as a tactical sighting card.
struct ReconView: View {
    @ObservedObject var viewModel: ReconViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                viewfinder
                controls
                resultsList
            }
            .navigationTitle("Recon")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.prepareIfNeeded() }
        .onDisappear { viewModel.teardown() }
        .accessibilityIdentifier("tacnet.recon.root")
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "viewfinder.circle.fill")
                .foregroundStyle(.tint)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Battlefield Scan")
                    .font(.headline)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("tacnet.recon.statusLine")
            }
            Spacer()
            if case .scanning = viewModel.status {
                ProgressView()
                    .accessibilityIdentifier("tacnet.recon.scanningIndicator")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
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
                        .accessibilityIdentifier("tacnet.recon.preview")

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
                    subtitle: "TacNet needs camera access to scan targets."
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
            Picker("Mode", selection: $viewModel.mode) {
                ForEach(ReconScanMode.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("tacnet.recon.modePicker")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.intentPresets) { preset in
                        Button(preset.title) {
                            viewModel.selectIntent(id: preset.id)
                        }
                        .buttonStyle(.bordered)
                        .tint(preset.id == viewModel.selectedIntentID ? .accentColor : .gray)
                        .accessibilityIdentifier("tacnet.recon.intent.\(preset.id)")
                    }
                }
                .padding(.horizontal, 2)
            }

            TextField("Custom intent (overrides preset)", text: $viewModel.customIntent, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .accessibilityIdentifier("tacnet.recon.customIntent")

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
                .accessibilityIdentifier("tacnet.recon.scanButton")

                Button("Clear") {
                    viewModel.clearSightings()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.sightings.isEmpty && viewModel.lastCapturedImage == nil)
                .accessibilityIdentifier("tacnet.recon.clearButton")
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var resultsList: some View {
        Group {
            if viewModel.sightings.isEmpty {
                if case .error(let message) = viewModel.status {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("tacnet.recon.errorMessage")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "binoculars")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No targets yet. Point the camera and tap Scan.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("tacnet.recon.emptyState")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List(viewModel.sightings) { sighting in
                    SightingRow(sighting: sighting)
                        .accessibilityIdentifier("tacnet.recon.sighting.\(sighting.id.uuidString)")
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
            Text("Open Settings to allow TacNet to use your camera and enable battlefield scanning.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("tacnet.recon.openSettingsButton")
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding()
    }

    // MARK: - Helpers

    private var canScan: Bool {
        guard viewModel.cameraService.authorization == .authorized else { return false }
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

    private var statusLine: String {
        switch viewModel.status {
        case .idle:
            if viewModel.sightings.isEmpty {
                return "Ready. Model: Gemma 4 E4B (on-device)."
            }
            return "\(viewModel.sightings.count) target\(viewModel.sightings.count == 1 ? "" : "s") detected."
        case .scanning:
            return "Running Gemma 4 on-device…"
        case .error(let message):
            return "Error: \(message)"
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
                    .accessibilityIdentifier("tacnet.recon.description")
            }

            HStack(spacing: 16) {
                Label(bearingText, systemImage: "safari")
                    .font(.caption.monospacedDigit())
                    .accessibilityIdentifier("tacnet.recon.bearing")

                Label(rangeText, systemImage: rangeSymbol)
                    .font(.caption.monospacedDigit())
                    .accessibilityIdentifier("tacnet.recon.range")
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
