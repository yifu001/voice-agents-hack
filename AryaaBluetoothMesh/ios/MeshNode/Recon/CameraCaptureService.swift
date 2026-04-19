import AVFoundation
import CoreGraphics
import Foundation
import UIKit

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
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
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
            throw CameraCaptureError.configurationFailed("not configured")
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = .speed

        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuation = continuation
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraCaptureError.captureFailed("service gone"))
                    return
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
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
            guard let continuation = self.pendingContinuation else { return }
            self.pendingContinuation = nil

            if let error {
                continuation.resume(throwing: CameraCaptureError.captureFailed(error.localizedDescription))
                return
            }

            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                continuation.resume(throwing: CameraCaptureError.noImageData)
                return
            }

            let size = CGSize(
                width: image.size.width * image.scale,
                height: image.size.height * image.scale
            )
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
