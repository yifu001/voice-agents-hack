import AVFoundation
import CoreGraphics
import Foundation
import UIKit
import os

private let log = Logger(subsystem: "com.cactushack.MeshNode", category: "recon.camera")

struct CameraShot: Sendable {
    let image: UIImage
    let pixelSize: CGSize
    let horizontalFoVDegrees: Double
    let verticalFoVDegrees: Double
}

enum CameraCaptureError: Error, Equatable {
    case permissionDenied
    case configurationFailed(String)
    case captureFailed(String)
    case captureTimedOut
    case noImageData
}

@MainActor
final class CameraCaptureService: NSObject, ObservableObject {
    enum AuthorizationState {
        case notDetermined
        case denied
        case authorized
    }

    @Published private(set) var authorization: AuthorizationState = .notDetermined
    @Published private(set) var isConfigured: Bool = false

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "meshnode.recon.captureSession", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private var activeDevice: AVCaptureDevice?
    private var pendingContinuation: CheckedContinuation<CameraShot, Error>?

    override init() {
        super.init()
        syncAuthorization(from: AVCaptureDevice.authorizationStatus(for: .video))
    }

    func requestPermissionIfNeeded() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorization = granted ? .authorized : .denied
        case .denied, .restricted:
            authorization = .denied
        @unknown default:
            authorization = .denied
        }
    }

    func configure() async throws {
        guard authorization == .authorized else {
            throw CameraCaptureError.permissionDenied
        }
        if isConfigured { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraCaptureError.configurationFailed("service gone"))
                    return
                }
                do {
                    try self.configureSessionLocked()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        isConfigured = true
    }

    func start() {
        log.info("Camera start requested")
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            log.info("Camera session started, isRunning=\(self.session.isRunning, privacy: .public)")
        }
    }

    func startIfNeeded() async {
        guard isConfigured else { return }
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func stopAndWait() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                if self.session.isRunning {
                    self.session.stopRunning()
                }
                continuation.resume()
            }
        }
    }

    func capture() async throws -> CameraShot {
        guard isConfigured else {
            log.error("capture() called but camera is not configured")
            throw CameraCaptureError.configurationFailed("not configured")
        }
        if pendingContinuation != nil {
            log.warning("Stale pendingContinuation detected — clearing it (previous capture likely timed out or delegate never fired)")
            pendingContinuation = nil
        }

        let isRunning = await withCheckedContinuation { cont in
            sessionQueue.async { cont.resume(returning: self.session.isRunning) }
        }
        log.info("capture(): session.isRunning=\(isRunning, privacy: .public)")
        if !isRunning {
            log.warning("Camera session not running at capture time — restarting")
            start()
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms for session to stabilize
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = .speed

        log.info("Requesting photo capture")
        return try await withThrowingTaskGroup(of: CameraShot.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { continuation in
                    self.pendingContinuation = continuation
                    self.sessionQueue.async { [weak self] in
                        guard let self else {
                            continuation.resume(throwing: CameraCaptureError.captureFailed("service gone"))
                            return
                        }
                        self.photoOutput.capturePhoto(with: settings, delegate: self)
                    }
                }
            }
            group.addTask { @MainActor in
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10s timeout
                throw CameraCaptureError.captureTimedOut
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func configureSessionLocked() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Recon only needs enough fidelity for Gemma detections, not a full
        // 12MP still pipeline, which is much heavier on-device.
        session.sessionPreset = .high

        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            throw CameraCaptureError.configurationFailed("no back wide camera")
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraCaptureError.configurationFailed("input init failed: \(error.localizedDescription)")
        }

        guard session.canAddInput(input) else {
            throw CameraCaptureError.configurationFailed("cannot add input")
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            throw CameraCaptureError.configurationFailed("cannot add output")
        }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .speed

        activeDevice = device
    }

    fileprivate func currentHorizontalFoVDegrees() -> Double {
        let fallback: Double = 68.0
        guard let device = activeDevice else { return fallback }
        let fov = Double(device.activeFormat.videoFieldOfView)
        return fov > 0 ? fov : fallback
    }

    fileprivate func currentVerticalFoVDegrees() -> Double {
        let hFoV = currentHorizontalFoVDegrees()
        let hRad = hFoV * .pi / 180.0
        let vRad = 2.0 * atan(tan(hRad / 2.0) * (3.0 / 4.0))
        return vRad * 180.0 / .pi
    }

    private func syncAuthorization(from status: AVAuthorizationStatus) {
        switch status {
        case .authorized:
            authorization = .authorized
        case .notDetermined:
            authorization = .notDetermined
        case .denied, .restricted:
            authorization = .denied
        @unknown default:
            authorization = .notDetermined
        }
    }
}

extension CameraCaptureService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            guard let continuation = self.pendingContinuation else {
                log.warning("Photo delegate fired but no pendingContinuation (timed out or cancelled)")
                return
            }
            self.pendingContinuation = nil

            if let error {
                log.error("Photo capture delegate error: \(error.localizedDescription, privacy: .public)")
                continuation.resume(throwing: CameraCaptureError.captureFailed(error.localizedDescription))
                return
            }

            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                log.error("Photo delegate returned no image data")
                continuation.resume(throwing: CameraCaptureError.noImageData)
                return
            }

            let size = CGSize(
                width: image.size.width * image.scale,
                height: image.size.height * image.scale
            )
            log.info("Photo captured: \(Int(size.width))x\(Int(size.height))")
            let shot = CameraShot(
                image: image,
                pixelSize: size,
                horizontalFoVDegrees: self.currentHorizontalFoVDegrees(),
                verticalFoVDegrees: self.currentVerticalFoVDegrees()
            )
            continuation.resume(returning: shot)
        }
    }
}
