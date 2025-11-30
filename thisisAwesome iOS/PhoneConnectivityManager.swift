import Foundation
import WatchConnectivity
internal import Combine

final class PhoneConnectivityManager: NSObject, ObservableObject {
    @Published var lastDive: DiveSummary?
    @Published var statusMessage: String = "Waiting for the watch to finish a dive..."
    @Published var isReachable: Bool = false

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    func activate() {
#if targetEnvironment(simulator)
        injectSimulatedDive()
        return
#endif

        guard let session else {
            statusMessage = "WatchConnectivity is not supported on this device."
            return
        }
        session.delegate = self
        session.activate()
        statusMessage = "Looking for your watch..."
    }

    private func handle(userInfo: [String: Any]) {
        guard let dive = DiveSummary(userInfo: userInfo) else {
            DispatchQueue.main.async {
                self.statusMessage = "Received data but could not decode a dive."
            }
            return
        }

        DispatchQueue.main.async {
            self.lastDive = dive
            self.statusMessage = "Latest dive synced at \(DateFormatter.shortTime.string(from: dive.endDate))."
        }
    }
}

extension PhoneConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error {
                self.statusMessage = "Session failed: \(error.localizedDescription)"
            } else {
                self.statusMessage = activationState == .activated ? "Connected to watch" : "Session inactive"
            }
            self.isReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.statusMessage = "Session inactive"
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo: userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(userInfo: message)
    }
}

private extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

#if targetEnvironment(simulator)
private extension PhoneConnectivityManager {
    /// Provides a fake dive so the iOS simulator can show the UI without WatchConnectivity.
    func injectSimulatedDive() {
        let now = Date()
        let duration: TimeInterval = 320
        let profile: [DiveSample] = [
            .init(seconds: 0, depthMeters: 0),
            .init(seconds: 8, depthMeters: 3),
            .init(seconds: 20, depthMeters: 9),
            .init(seconds: 40, depthMeters: 16),
            .init(seconds: 80, depthMeters: 22),
            .init(seconds: 120, depthMeters: 24),
            .init(seconds: 200, depthMeters: 16),
            .init(seconds: 260, depthMeters: 8),
            .init(seconds: 320, depthMeters: 0)
        ]
        let heartRates: [HeartRateSample] = [
            .init(seconds: 10, bpm: 78),
            .init(seconds: 60, bpm: 84),
            .init(seconds: 120, bpm: 88),
            .init(seconds: 180, bpm: 92),
            .init(seconds: 240, bpm: 95),
            .init(seconds: 300, bpm: 90),
            .init(seconds: 320, bpm: 86)
        ]

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.lastDive = DiveSummary(
                startDate: now.addingTimeInterval(-duration),
                endDate: now,
                maxDepthMeters: 24,
                durationSeconds: duration,
                endingHeartRate: 92,
                waterTemperatureCelsius: 24.5,
                profile: profile,
                heartRateSamples: heartRates
            )
            self.statusMessage = "Simulated dive loaded in simulator."
            self.isReachable = false
        }
    }
}
#endif
