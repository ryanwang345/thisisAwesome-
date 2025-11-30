//
//  DiveSyncManager.swift
//  thisisAwesome! Watch App
//

import Foundation
import WatchConnectivity
import Combine

final class DiveSyncManager: NSObject, ObservableObject {
    @Published var lastSentSummary: DiveSummary?
    @Published var lastErrorMessage: String?

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    func activate() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    func send(_ summary: DiveSummary) {
        guard let session else {
            lastErrorMessage = "WatchConnectivity is not supported on this device."
            return
        }

        lastErrorMessage = nil
        lastSentSummary = summary

        let payload = summary.asUserInfo

        // Fire-and-forget transfer for reliability; also try a live message if reachable.
        session.transferUserInfo(payload)

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                DispatchQueue.main.async {
                    self?.lastErrorMessage = error.localizedDescription
                }
            }
        } else {
            #if os(iOS)
            if !session.isPaired || !session.isWatchAppInstalled {
                lastErrorMessage = "Paired Apple Watch is unavailable."
            } else {
                lastErrorMessage = "Paired iPhone is unavailable."
            }
            #else
            // On watchOS, `isPaired` and `isWatchAppInstalled` are unavailable.
            // If not reachable, report a generic connectivity issue.
            lastErrorMessage = "Paired iPhone is unavailable."
            #endif
        }
    }
}

extension DiveSyncManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            DispatchQueue.main.async {
                self.lastErrorMessage = error.localizedDescription
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        // Optional: react to reachability changes later if we want to surface status.
    }
}
