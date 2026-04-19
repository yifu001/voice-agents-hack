import CoreLocation
import Foundation

@MainActor
final class HeadingProvider: NSObject, ObservableObject {
    enum AuthorizationState {
        case notDetermined
        case restricted
        case denied
        case authorized
    }

    @Published private(set) var latestHeadingDegrees: Double?
    @Published private(set) var authorization: AuthorizationState = .notDetermined

    private let locationManager: CLLocationManager

    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        super.init()
        self.locationManager.delegate = self
        self.locationManager.headingFilter = 1.0
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        syncAuthorization(from: locationManager.authorizationStatus)
    }

    func start() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            authorization = status == .restricted ? .restricted : .denied
            return
        case .authorizedWhenInUse, .authorizedAlways:
            authorization = .authorized
        @unknown default:
            break
        }
        beginHeadingUpdatesIfPossible()
    }

    func stop() {
        guard CLLocationManager.headingAvailable() else { return }
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
    }

    func snapshot() -> Double? {
        latestHeadingDegrees
    }

    private func beginHeadingUpdatesIfPossible() {
        guard authorization == .authorized else { return }
        guard CLLocationManager.headingAvailable() else { return }
        locationManager.startUpdatingLocation()
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
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.syncAuthorization(from: status)
            self.beginHeadingUpdatesIfPossible()
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
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

    nonisolated func locationManager(_: CLLocationManager, didFailWithError _: Error) {}
}
