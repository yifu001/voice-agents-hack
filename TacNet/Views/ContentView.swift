import SwiftUI

struct ContentView: View {
    @StateObject private var bootstrapViewModel = AppBootstrapViewModel()

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
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("TacNet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tactical Communication Network")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Model ready")
                .font(.footnote)
                .foregroundStyle(.green)
        }
        .padding()
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
