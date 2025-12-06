import Foundation
import WatchConnectivity
import CoreLocation
import Combine

final class PhoneConnectivityManager: NSObject, ObservableObject {
    @Published var lastDive: DiveSummary?
    @Published var diveHistory: [DiveSummary] = []
    @Published var statusMessage: String = "Waiting for the watch to finish a dive..."
    @Published var isReachable: Bool = false
    @Published var currentWeather: WeatherSnapshot?
    @Published var weatherError: String?

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private let storageKey = "savedDiveSummaries"
    private let historyLimit = 50
    private let geocoder = CLGeocoder()
    private let weatherGeocoder = CLGeocoder()

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
            if let latest = lastDive {
                fetchWeatherIfPossible(for: latest)
            }
        }
    }

    private func handle(userInfo: [String: Any]) {
        guard var dive = DiveSummary(userInfo: userInfo) else {
            DispatchQueue.main.async {
                self.statusMessage = "Received data but could not decode a dive."
            }
            return
        }

        if dive.locationDescription == nil,
           let lat = dive.locationLatitude,
           let lon = dive.locationLongitude {
            let coordLabel = formatCoordinateLabel(lat: lat, lon: lon)
            dive = dive.withLocationDescription(coordLabel)
        }

        DispatchQueue.main.async {
            self.insertIntoHistory(dive)
            self.lastDive = self.diveHistory.first
            self.statusMessage = "Latest dive synced at \(DateFormatter.shortTime.string(from: dive.endDate))."
            self.persistHistory()
            self.enrichLocationIfNeeded(for: dive)
            self.fetchWeatherIfPossible(for: dive)
        }
    }
}

extension PhoneConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error {
                self.statusMessage = "Session failed: \(error.localizedDescription)"
            } else {
                self.updateStatus(for: session, activationState: activationState)
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.updateStatus(for: session, activationState: .inactive)
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = false
            self.statusMessage = "Reconnecting to watch..."
        }
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.updateStatus(for: session)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo: userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(userInfo: message)
    }
}

private extension PhoneConnectivityManager {
    func updateStatus(for session: WCSession?, activationState: WCSessionActivationState? = nil) {
        guard let session else {
            statusMessage = "WatchConnectivity unavailable."
            isReachable = false
            return
        }

        let state = activationState ?? session.activationState
        let reachable = session.isReachable
        isReachable = reachable

        switch state {
        case .activated:
            statusMessage = reachable ? "Connected to watch" : "Watch not reachable"
        case .inactive:
            statusMessage = "Session inactive"
        case .notActivated:
            statusMessage = "Session not activated"
        @unknown default:
            statusMessage = "Session state unknown"
        }
    }

    func fetchWeatherIfPossible(for dive: DiveSummary) {
        if let lat = dive.locationLatitude, let lon = dive.locationLongitude {
            fetchWeather(latitude: lat, longitude: lon, dive: dive)
            return
        }

        // Fallback: geocode the location description if coordinates were not sent
        if let description = dive.locationDescription, !description.isEmpty {
            weatherGeocoder.cancelGeocode()
            weatherGeocoder.geocodeAddressString(description) { [weak self] placemarks, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async { self.weatherError = error.localizedDescription }
                    return
                }
                guard let coord = placemarks?.first?.location?.coordinate else { return }
                self.fetchWeather(latitude: coord.latitude, longitude: coord.longitude, dive: dive)
            }
        }
    }

    func fetchWeather(latitude: Double, longitude: Double, dive: DiveSummary) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current_weather=true"
        guard let url = URL(string: urlString) else { return }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { self.weatherError = error.localizedDescription }
                return
            }
            guard let data else {
                DispatchQueue.main.async { self.weatherError = "No weather data received." }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                guard let current = decoded.currentWeather else {
                    DispatchQueue.main.async { self.weatherError = "Weather unavailable." }
                    return
                }
                let snapshot = WeatherSnapshot(
                    temperatureC: current.temperature,
                    windSpeedKmh: current.windSpeed,
                    condition: self.weatherDescription(code: current.weatherCode),
                    symbolName: self.weatherSymbol(code: current.weatherCode),
                    timestamp: current.time,
                    latitude: latitude,
                    longitude: longitude
                )
                DispatchQueue.main.async {
                    self.currentWeather = snapshot
                    self.weatherError = nil
                    self.applyWeatherSnapshot(snapshot, for: dive.id)
                }
            } catch {
                DispatchQueue.main.async { self.weatherError = error.localizedDescription }
            }
        }
        task.resume()
    }

    func applyWeatherSnapshot(_ snapshot: WeatherSnapshot, for diveID: UUID) {
        var updatedDive: DiveSummary?

        if let idx = diveHistory.firstIndex(where: { $0.id == diveID }) {
            let updated = diveHistory[idx].withWeather(summary: snapshot.condition, airTempCelsius: snapshot.temperatureC)
            diveHistory[idx] = updated
            updatedDive = updated
        } else if let current = lastDive, current.id == diveID {
            updatedDive = current.withWeather(summary: snapshot.condition, airTempCelsius: snapshot.temperatureC)
        }

        if let updated = updatedDive {
            lastDive = updated
            insertIntoHistory(updated)
            persistHistory()
        }
    }

    func enrichLocationIfNeeded(for dive: DiveSummary) {
        guard let lat = dive.locationLatitude,
              let lon = dive.locationLongitude else { return }

        let location = CLLocation(latitude: lat, longitude: lon)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard error == nil, let place = placemarks?.first else { return }
            let parts = [place.locality, place.administrativeArea, place.country].compactMap { $0 }.filter { !$0.isEmpty }
            let name = parts.prefix(2).joined(separator: ", ")
            guard !name.isEmpty else { return }
            let updated = dive.withLocationDescription(name)
            DispatchQueue.main.async {
                self.insertIntoHistory(updated)
                self.lastDive = self.diveHistory.first
                self.persistHistory()
            self.statusMessage = "Location updated for latest dive."
            self.fetchWeatherIfPossible(for: updated)
        }
    }
    }

    func formatCoordinateLabel(lat: Double, lon: Double) -> String {
        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"
        return String(format: "%.4f°%@, %.4f°%@", abs(lat), latDir, abs(lon), lonDir)
    }

    func weatherDescription(code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Weather update"
        }
    }

    func weatherSymbol(code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75: return "snow"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

struct WeatherSnapshot: Equatable {
    let temperatureC: Double
    let windSpeedKmh: Double
    let condition: String
    let symbolName: String
    let timestamp: Date
    let latitude: Double
    let longitude: Double
}

private struct OpenMeteoResponse: Decodable {
    let currentWeather: CurrentWeather?

    private enum CodingKeys: String, CodingKey {
        case currentWeather = "current_weather"
    }
}

private struct CurrentWeather: Decodable {
    let temperature: Double
    let windSpeed: Double
    let weatherCode: Int
    let time: Date

    private enum CodingKeys: String, CodingKey {
        case temperature
        case windSpeed = "windspeed"
        case weatherCode = "weathercode"
        case time
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        temperature = try container.decode(Double.self, forKey: .temperature)
        windSpeed = try container.decode(Double.self, forKey: .windSpeed)
        weatherCode = try container.decode(Int.self, forKey: .weatherCode)

        if let timeString = try? container.decode(String.self, forKey: .time),
           let date = ISO8601DateFormatter().date(from: timeString) {
            time = date
        } else if let timestamp = try? container.decode(Double.self, forKey: .time) {
            time = Date(timeIntervalSince1970: timestamp)
        } else {
            time = Date()
        }
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
