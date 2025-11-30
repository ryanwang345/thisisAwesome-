import Foundation
import WatchConnectivity
internal import Combine

final class PhoneConnectivityManager: NSObject, ObservableObject {
    @Published var lastDive: DiveSummary?
    @Published var statusMessage: String = "Waiting for the watch to finish a dive..."
    @Published var isReachable: Bool = false

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    func activate() {
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
