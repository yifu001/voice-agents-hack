import Foundation
import SwiftUI
import UIKit

/// UI-facing state for the Recon tab. Owned by `AppNetworkCoordinator` so the scan services
/// outlive a tab switch (keeps the Gemma 4 handle warm and the camera session configured).
@MainActor
public final class ReconViewModel: ObservableObject {

    public enum ScanStatus: Equatable {
        case idle
        case scanning
        case error(String)
    }

    public struct IntentPreset: Identifiable, Equatable, Sendable {
        public let id: String
        public let title: String
        public let prompt: String

        public init(id: String, title: String, prompt: String) {
            self.id = id
            self.title = title
            self.prompt = prompt
        }
    }

    // MARK: - Published UI state

    @Published public private(set) var status: ScanStatus = .idle
    @Published public private(set) var sightings: [TargetSighting] = []
    @Published public private(set) var lastCapturedImage: UIImage?

    @Published public var mode: ReconScanMode = .standard
    @Published public var selectedIntentID: String
    @Published public var customIntent: String = ""

    public let intentPresets: [IntentPreset] = [
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

    // MARK: - Services

    public let cameraService: CameraCaptureService
    private let visionService: BattlefieldVisionService
    private let headingProvider: HeadingProvider
    private let rangeProvider: RangeProvider

    private var isWarmStarted = false

    public init(
        cameraService: CameraCaptureService? = nil,
        visionService: BattlefieldVisionService? = nil,
        headingProvider: HeadingProvider? = nil,
        rangeProvider: RangeProvider? = nil
    ) {
        self.cameraService = cameraService ?? CameraCaptureService()
        self.visionService = visionService ?? BattlefieldVisionService()
        self.headingProvider = headingProvider ?? HeadingProvider()
        self.rangeProvider = rangeProvider ?? RangeProvider()

        let defaultIntent = self.intentPresets.first?.id ?? "combatants"
        self.selectedIntentID = defaultIntent
    }

    // MARK: - Lifecycle (called from ReconView)

    public func prepareIfNeeded() async {
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

    public func teardown() {
        cameraService.stop()
        headingProvider.stop()
        rangeProvider.stop()
    }

    // MARK: - Intent

    public var effectiveIntentPrompt: String {
        let custom = customIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        return intentPresets.first(where: { $0.id == selectedIntentID })?.prompt
            ?? intentPresets[0].prompt
    }

    public func selectIntent(id: String) {
        selectedIntentID = id
    }

    public func clearSightings() {
        sightings = []
        lastCapturedImage = nil
        status = .idle
    }

    // MARK: - Scan pipeline

    public func performScan() async {
        guard status != .scanning else { return }
        guard cameraService.authorization == .authorized else {
            status = .error("Camera permission is required to scan the battlefield.")
            return
        }

        status = .scanning

        do {
            if !cameraService.isConfigured {
                try await cameraService.configure()
                cameraService.start()
            }

            let shot = try await cameraService.capture()
            lastCapturedImage = shot.image

            let headingSnapshot = headingProvider.snapshot()
            let intent = effectiveIntentPrompt

            let rawDetections = try await visionService.scan(
                image: shot.image,
                intent: intent,
                mode: mode
            )

            let now = Date()
            let fused: [TargetSighting] = rawDetections.compactMap { raw in
                // Use LiDAR sample at the bounding box centroid when available.
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

            sightings = fused
            status = .idle
        } catch {
            status = .error(error.localizedDescription)
        }
    }
}
