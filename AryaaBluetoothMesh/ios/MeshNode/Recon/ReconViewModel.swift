import Foundation
import SwiftUI
import UIKit

@MainActor
final class ReconViewModel: ObservableObject {
    enum ScanStatus: Equatable {
        case idle
        case scanning
        case error(String)
    }

    struct IntentPreset: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        let prompt: String
    }

    @Published private(set) var status: ScanStatus = .idle
    @Published private(set) var sightings: [TargetSighting] = []
    @Published private(set) var lastCapturedImage: UIImage?
    @Published private(set) var scanUnavailableMessage: String?
    @Published private(set) var scanWarningMessage: String?

    @Published var mode: ReconScanMode = .quick
    @Published var selectedIntentID: String
    @Published var customIntent: String = ""

    let intentPresets: [IntentPreset] = [
        IntentPreset(
            id: "combatants",
            title: "Combatants",
            prompt: "Detect every visible combatant, soldier, or person carrying a weapon. Describe uniform, weapon silhouette, and posture for each."
        ),
        IntentPreset(
            id: "vehicles",
            title: "Vehicles",
            prompt: "Detect every visible vehicle. Classify it (car, truck, technical, tank, APC, IFV, motorcycle) and describe notable features."
        ),
        IntentPreset(
            id: "people-vehicles",
            title: "People + Vehicles",
            prompt: "Detect every visible person and vehicle. For each, describe class, count, and anything tactically relevant."
        ),
        IntentPreset(
            id: "weapons",
            title: "Weapons",
            prompt: "Detect any visible weapon or weapon system and describe it briefly."
        ),
        IntentPreset(
            id: "drones",
            title: "Drones",
            prompt: "Detect any visible UAV, drone, or airborne surveillance asset and describe it."
        )
    ]

    let cameraService: CameraCaptureService
    private let llmService: LLMService
    private let sttService: STTService?
    private let visionService: BattlefieldVisionService
    private let headingProvider: HeadingProvider
    private let rangeProvider: RangeProvider

    private var isWarmStarted = false

    init(
        llmService: LLMService,
        sttService: STTService? = nil,
        cameraService: CameraCaptureService? = nil,
        headingProvider: HeadingProvider? = nil,
        rangeProvider: RangeProvider? = nil
    ) {
        self.llmService = llmService
        self.sttService = sttService
        self.cameraService = cameraService ?? CameraCaptureService()
        self.headingProvider = headingProvider ?? HeadingProvider()
        self.rangeProvider = rangeProvider ?? RangeProvider()
        self.visionService = BattlefieldVisionService(llmService: llmService)
        self.selectedIntentID = intentPresets.first?.id ?? "combatants"
    }

    func prepareIfNeeded() async {
        refreshVisionAvailability()
        llmService.load()

        guard !isWarmStarted else {
            cameraService.start()
            return
        }
        isWarmStarted = true

        await cameraService.requestPermissionIfNeeded()
        if cameraService.authorization == .authorized {
            do {
                try await cameraService.configure()
                cameraService.start()
            } catch {
                status = .error(error.localizedDescription)
                return
            }
        }
        headingProvider.start()
        rangeProvider.start()
    }

    func teardown() {
        cameraService.stop()
        headingProvider.stop()
        rangeProvider.stop()
    }

    var effectiveIntentPrompt: String {
        let custom = customIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        return intentPresets.first(where: { $0.id == selectedIntentID })?.prompt
            ?? intentPresets[0].prompt
    }

    func selectIntent(id: String) {
        selectedIntentID = id
    }

    func clearSightings() {
        sightings = []
        lastCapturedImage = nil
        status = .idle
    }

    func performScan() async {
        guard status != .scanning else { return }
        refreshVisionAvailability()
        if let scanUnavailableMessage {
            status = .error(scanUnavailableMessage)
            return
        }
        guard cameraService.authorization == .authorized else {
            status = .error("Camera permission is required to scan the scene.")
            return
        }

        status = .scanning

        let shouldResumeRange = rangeProvider.mode == .lidar
        let shouldReloadSTT = sttService?.isReady == true

        do {
            if !cameraService.isConfigured {
                try await cameraService.configure()
                cameraService.start()
            }

            let shot = try await cameraService.capture()
            let headingSnapshot = headingProvider.snapshot()

            await cameraService.stopAndWait()
            if shouldResumeRange {
                rangeProvider.suspendForInference()
            }
            if shouldReloadSTT {
                await sttService?.unload()
            }

            let scanResult = try await visionService.scan(
                image: shot.image,
                intent: effectiveIntentPrompt,
                mode: mode
            )

            let now = Date()
            let fused: [TargetSighting] = scanResult.detections.compactMap { raw in
                var lidarSample: Double?
                if let box = TargetSighting.NormalizedBox(gemmaArray: raw.box_2d) {
                    let centroid = box.centroid
                    let normalized = CGPoint(x: centroid.x / 1000.0, y: centroid.y / 1000.0)
                    lidarSample = rangeProvider.sampleDepthMeters(atNormalizedPoint: normalized)
                }
                return TargetFusion.fuse(
                    detection: raw,
                    imagePixelSize: shot.pixelSize,
                    horizontalFoVDegrees: shot.horizontalFoVDegrees,
                    verticalFoVDegrees: shot.verticalFoVDegrees,
                    headingTrueNorth: headingSnapshot,
                    lidarRangeMeters: lidarSample,
                    capturedAt: now
                )
            }

            lastCapturedImage = scanResult.previewImage
            sightings = fused
            await restoreRealtimeServices(shouldReloadSTT: shouldReloadSTT, shouldResumeRange: shouldResumeRange)
            status = .idle
        } catch {
            await restoreRealtimeServices(shouldReloadSTT: shouldReloadSTT, shouldResumeRange: shouldResumeRange)
            status = .error(error.localizedDescription)
        }
    }

    private func refreshVisionAvailability() {
        switch llmService.visionBundleStatus() {
        case .ready:
            scanUnavailableMessage = nil
            scanWarningMessage = nil
        case .degraded(let message):
            scanUnavailableMessage = nil
            scanWarningMessage = message
        case .unavailable(let message):
            scanUnavailableMessage = message
            scanWarningMessage = nil
            if sightings.isEmpty {
                status = .error(message)
            }
        }
    }

    private func restoreRealtimeServices(
        shouldReloadSTT: Bool,
        shouldResumeRange: Bool
    ) async {
        if shouldReloadSTT {
            sttService?.load()
        }
        if shouldResumeRange {
            rangeProvider.resumeAfterInference()
        }
        await cameraService.startIfNeeded()
    }
}
