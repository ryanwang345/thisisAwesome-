import Foundation
import WatchConnectivity
internal import Combine

final class PhoneConnectivityManager: NSObject, ObservableObject {
    @Published var lastDive: DiveSummary?
    @Published var diveHistory: [DiveSummary] = []
    @Published var statusMessage: String = "Waiting for the watch to finish a dive..."
    @Published var isReachable: Bool = false

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private let storageKey = "savedDiveSummaries"
    private let historyLimit = 50

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

        // Load persisted history if available
        let saved = loadPersistedHistory()
        if !saved.isEmpty {
            diveHistory = saved.sorted { $0.endDate > $1.endDate }
            lastDive = diveHistory.first
            statusMessage = "Loaded last saved dive."
        }
    }

    private func handle(userInfo: [String: Any]) {
        guard let dive = DiveSummary(userInfo: userInfo) else {
            DispatchQueue.main.async {
                self.statusMessage = "Received data but could not decode a dive."
            }
            return
        }

        DispatchQueue.main.async {
            self.insertIntoHistory(dive)
            self.lastDive = self.diveHistory.first
            self.statusMessage = "Latest dive synced at \(DateFormatter.shortTime.string(from: dive.endDate))."
            self.persistHistory()
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
        let mockConfigs: [(TimeInterval, Double, Int, Double, Double)] = [
            (320, 24, 92, 24.6, 1.1),  // deeper, longer
            (240, 18, 88, 25.0, 0.8),  // mid-depth
            (420, 30, 96, 24.2, 1.4)   // longest/deepest
        ]
        // Toronto pool/leak test locations
        let mockMeta: [(String, String, Double, Double, Double)] = [
            ("Toronto Pan Am Sports Centre, Toronto", "Indoor pool • calm", 29.0, 43.7810, -79.2342),
            ("Alex Duff Memorial Pool, Toronto", "Outdoor pool • light breeze", 27.5, 43.6657, -79.4186),
            ("Donald D. Summerville Pool, Toronto", "Lake breeze • partly cloudy", 22.0, 43.6685, -79.2958)
        ]

        let summaries: [DiveSummary] = mockConfigs.enumerated().map { idx, config in
            let (duration, maxDepth, endingHR, baseTemp, swing) = config
            let end = now.addingTimeInterval(-Double(idx) * 1800) // stagger end times 30 min apart
            let start = end.addingTimeInterval(-duration)
            let profile = simulatedProfile(duration: duration, maxDepth: maxDepth, step: 0.5)
            let heartRates = simulatedHeartRates(duration: duration, step: 0.5)
            let waterTemps = simulatedWaterTemps(duration: duration, base: baseTemp, swing: swing, step: 0.5)
            let meta = mockMeta[idx % mockMeta.count]

            return DiveSummary(
                startDate: start,
                endDate: end,
                maxDepthMeters: maxDepth,
                durationSeconds: duration,
                endingHeartRate: endingHR,
                waterTemperatureCelsius: baseTemp,
                locationDescription: meta.0,
                weatherSummary: meta.1,
                weatherAirTempCelsius: meta.2,
                locationLatitude: meta.3,
                locationLongitude: meta.4,
                profile: profile,
                heartRateSamples: heartRates,
                waterTempSamples: waterTemps
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.diveHistory = summaries.sorted { $0.endDate > $1.endDate }
            self.lastDive = self.diveHistory.first
            self.persistHistory()
            self.statusMessage = "Simulated dives loaded in simulator."
            self.isReachable = false
        }
    }

    func simulatedProfile(duration: TimeInterval, maxDepth: Double, step: TimeInterval) -> [DiveSample] {
        // Faster descent, longer bottom, controlled ascent
        let keyframes: [(Double, Double)] = [
            (0.0, 0),
            (0.08, maxDepth * 0.45),   // quick drop
            (0.18, maxDepth),          // reach max
            (0.55, maxDepth),          // stay near bottom
            (0.70, maxDepth * 0.75),   // ascent pause
            (0.85, maxDepth * 0.25),   // shallow stop
            (1.0, 0)
        ]

        return stride(from: 0.0, through: duration, by: step).map { t in
            let depth = interpolatedValue(at: t / duration, keyframes: keyframes)
            return DiveSample(seconds: t, depthMeters: depth)
        }
    }

    func simulatedHeartRates(duration: TimeInterval, step: TimeInterval) -> [HeartRateSample] {
        // Mild bradycardia during descent/bottom, then rising on ascent/surface
        let keyframes: [(Double, Double)] = [
            (0.0, 92),   // anticipation
            (0.10, 78),  // dive response kicks in
            (0.30, 72),  // bottom bradycardia
            (0.60, 76),  // ascent start
            (0.80, 84),  // nearing surface
            (1.0, 88)    // surface recovery
        ]

        return stride(from: 0.0, through: duration, by: step).map { t in
            let bpm = Int(interpolatedValue(at: t / duration, keyframes: keyframes).rounded())
            return HeartRateSample(seconds: t, bpm: bpm)
        }
    }

    func simulatedWaterTemps(duration: TimeInterval, base: Double, swing: Double, step: TimeInterval) -> [WaterTempSample] {
        // Slightly cooler at depth, warming near surface
        let keyframes: [(Double, Double)] = [
            (0.0, base),
            (0.25, base - swing),          // drop with depth
            (0.55, base - swing * 0.7),    // cooler at bottom
            (0.8, base - swing * 0.3),     // warming on ascent
            (1.0, base - swing * 0.1)      // near-surface
        ]

        return stride(from: 0.0, through: duration, by: step).map { t in
            let c = interpolatedValue(at: t / duration, keyframes: keyframes)
            return WaterTempSample(seconds: t, celsius: c)
        }
    }

    func interpolatedValue(at progress: Double, keyframes: [(Double, Double)]) -> Double {
        let clamped = max(0, min(progress, 1))
        guard let upperIndex = keyframes.firstIndex(where: { $0.0 >= clamped }) else {
            return keyframes.last?.1 ?? 0
        }
        if upperIndex == 0 { return keyframes[0].1 }

        let lower = keyframes[upperIndex - 1]
        let upper = keyframes[upperIndex]
        let span = upper.0 - lower.0
        let ratio = span > 0 ? (clamped - lower.0) / span : 0
        return lower.1 + (upper.1 - lower.1) * ratio
    }
}
#endif

private extension PhoneConnectivityManager {
    func insertIntoHistory(_ dive: DiveSummary) {
        if let idx = diveHistory.firstIndex(where: { $0.id == dive.id }) {
            diveHistory[idx] = dive
        } else {
            diveHistory.append(dive)
        }
        diveHistory = diveHistory
            .sorted { $0.endDate > $1.endDate }
            .prefix(historyLimit)
            .map { $0 }
    }

    func persistHistory() {
        do {
            let data = try JSONEncoder().encode(diveHistory)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to persist dive history: \(error)")
        }
    }

    func loadPersistedHistory() -> [DiveSummary] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([DiveSummary].self, from: data)) ?? []
    }

    /// Convenience: log the current history as pretty JSON for debugging.
    func debugLogHistory() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(diveHistory)
            if let json = String(data: data, encoding: .utf8) {
                print("---- DiveHistory JSON ----\n\(json)\n-------------------------")
            }
        } catch {
            print("Failed to encode dive history: \(error)")
        }
    }

    /// Convenience: write the current history to a JSON file in Documents for offline inspection.
    /// Returns the file URL if successful so you can pull it with Files/Finder.
    @discardableResult
    func exportHistoryToFile() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(diveHistory)
            let filename = "DiveHistory-\(Self.fileDateFormatter.string(from: Date())).json"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            print("Wrote dive history to \(url.path)")
            return url
        } catch {
            print("Failed to export dive history: \(error)")
            return nil
        }
    }

    private static let fileDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmmss"
        df.locale = .init(identifier: "en_US_POSIX")
        return df
    }()
}
