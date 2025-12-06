import Foundation
import CoreLocation
import Combine

/// Lightweight helper to capture a single location fix when the app opens.
final class LocationRecorder: NSObject, ObservableObject {
    @Published var lastLocation: CLLocation?
    @Published var status: CLAuthorizationStatus = .notDetermined
    @Published var errorDescription: String?

    private let manager = CLLocationManager()
    private var hasStarted = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 25
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        requestAuthorizationIfNeeded()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        hasStarted = false
    }

    private func requestAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            errorDescription = "Location permission is required to tag dives."
        default:
            break
        }
        status = manager.authorizationStatus
    }
}

extension LocationRecorder: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.status = manager.authorizationStatus
            if self.status == .authorizedAlways || self.status == .authorizedWhenInUse {
                self.manager.startUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        DispatchQueue.main.async {
            self.lastLocation = latest
        }
        // Stop after first good fix to save battery
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorDescription = error.localizedDescription
        }
    }
}
