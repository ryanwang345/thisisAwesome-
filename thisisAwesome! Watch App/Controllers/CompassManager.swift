//
//  CompassManager.swift
//  FreeDiving Computer Watch App
//

import Foundation
import CoreLocation
import Combine

final class CompassManager: NSObject, ObservableObject {
    @Published var headingDegrees: Double?
    @Published var headingDirection: String?
    @Published var errorDescription: String?

    private let locationManager = CLLocationManager()
    private var isRunning = false
    private let headingEpsilon: Double = 0.8

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.headingFilter = 1 // reduce churn while keeping responsiveness
    }

    func start() {
        guard !isRunning else { return }
        errorDescription = nil
        guard CLLocationManager.headingAvailable() else {
            errorDescription = "Compass data is not available on this device."
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            errorDescription = "Location permission is required to read heading."
            return
        default:
            break
        }

        isRunning = true
        locationManager.startUpdatingHeading()
    }

    func stop() {
        locationManager.stopUpdatingHeading()
        isRunning = false
    }

    private static func cardinalDirection(for angle: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((angle + 22.5) / 45.0) % directions.count
        return directions[index]
    }
}

extension CompassManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard heading >= 0 else { return }
        let normalized = (heading.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)

        DispatchQueue.main.async {
            if let current = self.headingDegrees,
               abs(current - normalized) < self.headingEpsilon {
                return
            }
            self.headingDegrees = normalized
            self.headingDirection = Self.cardinalDirection(for: normalized)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorDescription = error.localizedDescription
        }
    }
}
