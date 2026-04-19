import Foundation
import SwiftUI
import UIKit
import os

private let log = Logger(subsystem: "com.cactushack.MeshNode", category: "recon.vm")

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
    @Published private(set) var lastAnalysisText: String?
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
        lastAnalysisText = nil
        status = .idle
    }

    func performScan() async {
        guard status != .scanning else {
            log.warning("performScan() called while already scanning — ignoring")
            return
        }
        refreshVisionAvailability()
        if let scanUnavailableMessage {
            log.error("Vision unavailable: \(scanUnavailableMessage, privacy: .public)")
            status = .error(scanUnavailableMessage)
            return
        }
        guard cameraService.authorization == .authorized else {
            log.error("Camera not authorized")
            status = .error("Camera permission is required to scan the scene.")
            return
        }

        log.info("=== SCAN START === mode=\(mode.rawValue, privacy: .public) intent=\(selectedIntentID, privacy: .public)")
        status = .scanning
        lastAnalysisText = nil

        let shouldResumeRange = rangeProvider.mode == .lidar
        let shouldReloadSTT = sttService?.isReady == true
        log.info("Pre-scan state: cameraConfigured=\(cameraService.isConfigured, privacy: .public) shouldResumeRange=\(shouldResumeRange, privacy: .public) shouldReloadSTT=\(shouldReloadSTT, privacy: .public)")

        do {
            if !cameraService.isConfigured {
                log.info("Camera not configured — configuring now")
                try await cameraService.configure()
                cameraService.start()
            }

            log.info("Capturing photo…")
            let shot = try await cameraService.capture()
            log.info("Photo captured: \(Int(shot.pixelSize.width))x\(Int(shot.pixelSize.height))")
            let headingSnapshot = headingProvider.snapshot()

            log.info("Stopping camera and suspending peripherals for inference")
            await cameraService.stopAndWait()
            if shouldResumeRange {
                rangeProvider.suspendForInference()
            }
            if shouldReloadSTT {
                await sttService?.unload()
            }

            log.info("Running vision inference…")
            let scanResult = try await visionService.scan(
                image: shot.image,
                intent: effectiveIntentPrompt,
                mode: mode
            )
            log.info("Vision returned \(scanResult.detections.count) detections")

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
            lastAnalysisText = scanResult.analysisText
            sightings = fused
            log.info("Restoring realtime services after successful scan")
            await restoreRealtimeServices(shouldReloadSTT: shouldReloadSTT, shouldResumeRange: shouldResumeRange)
            log.info("=== SCAN COMPLETE === \(fused.count) sightings fused")
            status = .idle
        } catch {
            log.error("=== SCAN FAILED === error type: \(String(describing: type(of: error)), privacy: .public)")
            await restoreRealtimeServices(shouldReloadSTT: shouldReloadSTT, shouldResumeRange: shouldResumeRange)
            let message: String
            if let visionError = error as? BattlefieldVisionServiceError {
                switch visionError {
                case .modelReturnedNoVisionOutput(let detail):
                    log.error("Vision produced no output: \(detail, privacy: .public)")
                    message = detail
                case .invalidModelResponse(let detail):
                    log.error("Vision invalid response: \(detail, privacy: .public)")
                    message = "Bad model output: \(detail)"
                case .failedToEncodeImage:
                    log.error("Failed to encode camera image to JPEG")
                    message = "Failed to encode camera image."
                case .failedToWriteTempImage(let detail):
                    log.error("Failed to write temp image: \(detail, privacy: .public)")
                    message = "Failed to save image: \(detail)"
                }
            } else if let cameraError = error as? CameraCaptureError {
                log.error("Camera error: \(String(describing: cameraError), privacy: .public)")
                message = "Camera: \(cameraError.localizedDescription ?? String(describing: cameraError))"
            } else if let llmError = error as? LLMService.CompletionError {
                log.error("LLM error: \(String(describing: llmError), privacy: .public)")
                message = llmError.localizedDescription ?? String(describing: llmError)
            } else {
                log.error("Unexpected error: \(error.localizedDescription, privacy: .public)")
                message = error.localizedDescription
            }
            status = .error(message)
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
        log.info("Restoring services: STT=\(shouldReloadSTT, privacy: .public) range=\(shouldResumeRange, privacy: .public)")
        if shouldReloadSTT {
            sttService?.load()
            if case .error(let msg) = sttService?.state {
                log.warning("STT failed to reload after scan: \(msg, privacy: .public)")
            }
        }
        if shouldResumeRange {
            rangeProvider.resumeAfterInference()
        }
        log.info("Restarting camera session")
        await cameraService.startIfNeeded()
        log.info("Camera restart complete, isConfigured=\(cameraService.isConfigured, privacy: .public)")
    }
}
