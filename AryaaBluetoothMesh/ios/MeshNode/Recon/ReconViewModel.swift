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
    private let enableDepthFusion = false

    private static let defaultIntentPrompt =
        "Detect tactically relevant people, vehicles, weapons, or drones in the scene. Return only clearly visible items."

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
        self.visionService = BattlefieldVisionService(llmService: llmService, maxModelImageDimension: 320)
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
        if enableDepthFusion {
            rangeProvider.start()
        }
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
            ?? Self.defaultIntentPrompt
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
        guard self.status != .scanning else {
            log.warning("performScan() called while already scanning — ignoring")
            return
        }
        self.refreshVisionAvailability()
        if let msg = self.scanUnavailableMessage {
            log.error("Vision unavailable: \(msg, privacy: .public)")
            self.status = .error(msg)
            return
        }
        guard self.cameraService.authorization == .authorized else {
            log.error("Camera not authorized")
            self.status = .error("Camera permission is required to scan the scene.")
            return
        }

        log.info("=== SCAN START === mode=\(self.mode.rawValue, privacy: .public) intent=\(self.selectedIntentID, privacy: .public)")
        status = .scanning
        lastAnalysisText = nil
        lastCapturedImage = nil
        sightings = []

        let shouldResumeRange = enableDepthFusion && rangeProvider.mode == .lidar
        // With the 320px image cap, Metal prefill buffers are small enough that
        // Parakeet can stay resident. Only unload if it was ready (so we can
        // reload it after) AND if a previous scan already bad_alloc'd (indicating
        // this device needs the extra headroom). For now keep Parakeet in memory
        // and let the bad_alloc recovery path handle the rare failure case.
        let shouldReloadSTT = false
        log.info("Pre-scan state: cameraConfigured=\(self.cameraService.isConfigured, privacy: .public) shouldResumeRange=\(shouldResumeRange, privacy: .public) parakeetKept=true")

        do {
            if !self.cameraService.isConfigured {
                log.info("Camera not configured — configuring now")
                try await self.cameraService.configure()
                self.cameraService.start()
            }

            log.info("Capturing photo…")
            let shot = try await self.cameraService.capture()
            log.info("Photo captured: \(Int(shot.pixelSize.width))x\(Int(shot.pixelSize.height))")
            let headingSnapshot = self.headingProvider.snapshot()

            log.info("Stopping camera for inference (Parakeet stays loaded)")
            await self.cameraService.stopAndWait()
            if shouldResumeRange {
                self.rangeProvider.suspendForInference()
            }

            log.info("Running vision inference…")
            let scanResult = try await self.visionService.scan(
                image: shot.image,
                intent: self.effectiveIntentPrompt,
                mode: self.mode
            )
            log.info("Vision returned \(scanResult.detections.count) detections")

            let now = Date()
            let rangeProviderRef = self.rangeProvider
            let fused: [TargetSighting] = scanResult.detections.compactMap { raw in
                var lidarSample: Double?
                if enableDepthFusion,
                   let box = TargetSighting.NormalizedBox(gemmaArray: raw.box_2d) {
                    let centroid = box.centroid
                    let normalized = CGPoint(x: centroid.x / 1000.0, y: centroid.y / 1000.0)
                    lidarSample = rangeProviderRef.sampleDepthMeters(atNormalizedPoint: normalized)
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

            self.lastCapturedImage = scanResult.previewImage
            self.lastAnalysisText = scanResult.analysisText
            self.sightings = fused
            log.info("Restoring realtime services after successful scan")
            await self.restoreRealtimeServices(shouldReloadSTT: shouldReloadSTT, shouldResumeRange: shouldResumeRange)
            log.info("=== SCAN COMPLETE === \(fused.count) sightings fused")
            self.status = .idle
        } catch {
            log.error("=== SCAN FAILED === error type: \(String(describing: type(of: error)), privacy: .public)")
            await self.restoreRealtimeServices(shouldReloadSTT: shouldReloadSTT, shouldResumeRange: shouldResumeRange)
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
                let desc = error.localizedDescription
                if desc.contains("bad_alloc") || desc.contains("Cannot map file") {
                    log.error("Memory pressure failure: \(desc, privacy: .public)")
                    message = "Out of memory. Model is reloading — tap Scan again in a few seconds."
                } else {
                    log.error("Unexpected error: \(desc, privacy: .public)")
                    message = desc
                }
            }
            self.status = .error(message)
        }
    }

    private func refreshVisionAvailability() {
        switch llmService.visionBundleStatus() {
        case .ready:
            scanUnavailableMessage = nil
        case .degraded(let message):
            log.info("Recon running in degraded vision mode: \(message, privacy: .public)")
            scanUnavailableMessage = nil
        case .unavailable(let message):
            scanUnavailableMessage = message
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
        if shouldReloadSTT, let sttService {
            Task { @MainActor in
                // 5 s delay: after a bad_alloc the OS needs several seconds to
                // reclaim the freed Gemma compute buffers before Parakeet's mmap
                // and CoreML mlmodelc parse can succeed. 1.5 s was too short.
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                sttService.load()
                if case .error(let msg) = sttService.state {
                    log.warning("STT failed to reload after scan: \(msg, privacy: .public)")
                }
            }
        }
        if shouldResumeRange {
            self.rangeProvider.resumeAfterInference()
        }
        log.info("Restarting camera session")
        await self.cameraService.startIfNeeded()
        log.info("Camera restart complete, isConfigured=\(self.cameraService.isConfigured, privacy: .public)")
    }
}
