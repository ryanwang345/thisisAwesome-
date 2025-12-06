//
//  WaterSubmersionManager.swift
//  FreeDiving Computer Watch App
//

import Foundation
import CoreMotion
import Combine

final class WaterSubmersionManager: NSObject, ObservableObject {
    @Published var depthMeters: Double = 0
    @Published var depthState: CMWaterSubmersionMeasurement.DepthState = .unknown
    @Published var isSubmerged: Bool = false
    @Published var waterTemperatureCelsius: Double?
    @Published var errorDescription: String?

    private let manager = CMWaterSubmersionManager()
    private var isRunning = false
    private let logPrefix = "[WaterSubmersion]"
    private let depthEpsilon: Double = 0.02
    private let tempEpsilon: Double = 0.1

    func start() {
        errorDescription = nil
        guard !isRunning else { return }
        let available = CMWaterSubmersionManager.waterSubmersionAvailable
        let auth = CMWaterSubmersionManager.authorizationStatus
        guard available else {
            errorDescription = "Water submersion data is not available on this device."
            return
        }

        switch auth {
        case .denied, .restricted:
            errorDescription = "Motion & Fitness permission is required to read water depth."
            return
        default:
            break
        }

        isRunning = true
        manager.delegate = self
    }

    func stop() {
        guard isRunning else { return }
        manager.delegate = nil
        isRunning = false
        depthMeters = 0
        depthState = .unknown
        isSubmerged = false
        waterTemperatureCelsius = nil
    }
}

extension WaterSubmersionManager: CMWaterSubmersionManagerDelegate {
    func manager(_ manager: CMWaterSubmersionManager, didUpdate event: CMWaterSubmersionEvent) {
        DispatchQueue.main.async {
            self.isSubmerged = event.state == .submerged
            if !self.isSubmerged {
                self.depthMeters = 0
                self.waterTemperatureCelsius = nil
            }
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterSubmersionMeasurement) {
        let depthValue = measurement.depth?.converted(to: .meters).value ?? 0
        DispatchQueue.main.async {
            let clamped = max(0, depthValue)
            if abs(clamped - self.depthMeters) < self.depthEpsilon,
               self.depthState == measurement.submersionState {
                return
            }
            self.depthMeters = clamped
            self.depthState = measurement.submersionState
            self.isSubmerged = measurement.submersionState != .notSubmerged && depthValue > 0
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterTemperature) {
        let temperatureCelsius = measurement.temperature.converted(to: .celsius).value
        DispatchQueue.main.async {
            if let current = self.waterTemperatureCelsius,
               abs(current - temperatureCelsius) < self.tempEpsilon {
                return
            }
            self.waterTemperatureCelsius = temperatureCelsius
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, errorOccurred error: Error) {
        DispatchQueue.main.async {
            self.errorDescription = error.localizedDescription
            self.stop()
        }
    }
}
