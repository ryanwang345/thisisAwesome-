import Foundation
import Combine
import CoreMotion

#if targetEnvironment(simulator)
/// Simple depth script so the watch app can simulate a dive in the simulator.
final class SimulatedWaterSubmersionManager: NSObject, ObservableObject {
    @Published var depthMeters: Double = 0
    @Published var depthState: CMWaterSubmersionMeasurement.DepthState = .unknown
    @Published var isSubmerged: Bool = false
    @Published var waterTemperatureCelsius: Double? = 24

    private var timer: Timer?
    private var startDate: Date?
    // time (s) from start, depth (m)
    private let script: [(TimeInterval, Double)] = [
        (0, 0), (2, 1), (6, 6), (12, 12), (20, 18), (28, 20),
        (36, 14), (44, 8), (54, 2), (60, 0)
    ]
    private let tick: TimeInterval = 0.5

    func start() {
        stop()
        startDate = Date()
        depthState = .unknown
        isSubmerged = true

        timer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { [weak self] _ in
            self?.advance()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        startDate = nil
        depthMeters = 0
        depthState = .unknown
        isSubmerged = false
    }

    private func advance() {
        guard let startDate else { return }
        let elapsed = Date().timeIntervalSince(startDate)
        if let sample = script.last(where: { $0.0 <= elapsed }) {
            depthMeters = sample.1
        }

        if elapsed >= (script.last?.0 ?? 0) {
            // Surface and end the simulated dive.
            stop()
        }
    }
}

typealias ActiveWaterSubmersionManager = SimulatedWaterSubmersionManager
#else
typealias ActiveWaterSubmersionManager = WaterSubmersionManager
#endif
