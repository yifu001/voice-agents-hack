import CoreLocation
import Foundation

/// Streams magnetometer heading (true north) to the Recon tab.
///
/// This wraps `CLLocationManager.startUpdatingHeading()` behind a small `@MainActor`
/// observable. The actor exposes `latestHeadingDegrees` as the last reported true-north
/// bearing, which `ReconViewModel` samples at shutter time when fusing detections.
///
/// If the user denies location permission, `latestHeadingDegrees` simply stays `nil` and
/// bearing fields in sightings will also be `nil` — the rest of the feature continues to
/// work offline.
@MainActor
public final class HeadingProvider: NSObject, ObservableObject {

    public enum AuthorizationState {
        case notDetermined
        case restricted
        case denied
        case authorized
    }

    /// Latest true-north heading in degrees, `0..<360`. `nil` until the first update arrives or
    /// if heading is unavailable on this device.
    @Published public private(set) var latestHeadingDegrees: Double?

    @Published public private(set) var authorization: AuthorizationState = .notDetermined

    private let locationManager: CLLocationManager

    public init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        super.init()
        self.locationManager.delegate = self
        self.locationManager.headingFilter = 1.0
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        syncAuthorization(from: locationManager.authorizationStatus)
    }

    /// Request location permission if not granted, then begin streaming heading.
    public func start() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            authorization = (status == .restricted) ? .restricted : .denied
            return
        case .authorizedWhenInUse, .authorizedAlways:
            authorization = .authorized
        @unknown default:
            break
        }
        beginHeadingUpdatesIfPossible()
    }

    public func stop() {
        guard CLLocationManager.headingAvailable() else { return }
        locationManager.stopUpdatingHeading()
    }

    /// Snapshot the latest heading (safe to call from any actor via `await`).
    public func snapshot() -> Double? {
        latestHeadingDegrees
    }

    private func beginHeadingUpdatesIfPossible() {
        guard authorization == .authorized else { return }
        guard CLLocationManager.headingAvailable() else { return }
        locationManager.startUpdatingLocation() // needed so `.trueHeading` can be resolved
        locationManager.startUpdatingHeading()
    }

    private func syncAuthorization(from status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            authorization = .notDetermined
        case .restricted:
            authorization = .restricted
        case .denied:
            authorization = .denied
        case .authorizedAlways, .authorizedWhenInUse:
            authorization = .authorized
        @unknown default:
            authorization = .notDetermined
        }
    }
}

extension HeadingProvider: CLLocationManagerDelegate {
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.syncAuthorization(from: status)
            self.beginHeadingUpdatesIfPossible()
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Prefer `.trueHeading` once location is fixed; fall back to magnetic when not.
        let trueHeading = newHeading.trueHeading
        let magneticHeading = newHeading.magneticHeading
        let heading: Double
        if trueHeading >= 0 {
            heading = trueHeading
        } else if magneticHeading >= 0 {
            heading = magneticHeading
        } else {
            return
        }

        Task { @MainActor in
            self.latestHeadingDegrees = heading
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Swallow: heading failures are non-fatal — bearing simply stays nil.
    }
}
