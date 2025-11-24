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

    func start() {
        errorDescription = nil
        guard !isRunning else { return }
        let available = CMWaterSubmersionManager.waterSubmersionAvailable
        let auth = CMWaterSubmersionManager.authorizationStatus
        print("\(logPrefix) start requested. available=\(available), auth=\(auth.rawValue)")

        guard available else {
            errorDescription = "Water submersion data is not available on this device."
            print("\(logPrefix) start aborted: unavailable")
            return
        }

        switch auth {
        case .denied, .restricted:
            errorDescription = "Motion & Fitness permission is required to read water depth."
            print("\(logPrefix) start aborted: auth \(auth.rawValue)")
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
        print("\(logPrefix) stopped")
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
            print("\(self.logPrefix) event state=\(event.state.rawValue), submerged=\(self.isSubmerged)")
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterSubmersionMeasurement) {
        let depthValue = measurement.depth?.converted(to: .meters).value ?? 0
        DispatchQueue.main.async {
            self.depthMeters = max(0, depthValue)
            self.depthState = measurement.submersionState
            self.isSubmerged = measurement.submersionState != .notSubmerged && depthValue > 0
            let maxDepth = manager.maximumDepth?.converted(to: .meters).value
            let maxDepthString = maxDepth.map { "\($0)m" } ?? "nil"
            print("\(self.logPrefix) measurement depth=\(self.depthMeters)m state=\(self.depthState.rawValue) maxDepth=\(maxDepthString)")
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterTemperature) {
        let temperatureCelsius = measurement.temperature.converted(to: .celsius).value
        DispatchQueue.main.async {
            self.waterTemperatureCelsius = temperatureCelsius
            print("\(self.logPrefix) temperature=\(temperatureCelsius)C")
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, errorOccurred error: Error) {
        DispatchQueue.main.async {
            self.errorDescription = error.localizedDescription
            //print more detailed error info
            print("\(self.logPrefix) error details: \(error)")
            self.stop()
            print("\(self.logPrefix) error=\(error.localizedDescription)")
        }
    }
}
