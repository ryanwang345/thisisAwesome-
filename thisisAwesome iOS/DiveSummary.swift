import Foundation

struct DiveSummary: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let maxDepthMeters: Double
    let durationSeconds: Double
    let endingHeartRate: Int?
    let waterTemperatureCelsius: Double?
    let profile: [DiveSample]
    let heartRateSamples: [HeartRateSample]
    let waterTempSamples: [WaterTempSample]

    init(id: UUID = UUID(),
         startDate: Date,
         endDate: Date,
         maxDepthMeters: Double,
         durationSeconds: Double,
         endingHeartRate: Int?,
         waterTemperatureCelsius: Double?,
         profile: [DiveSample] = [],
         heartRateSamples: [HeartRateSample] = [],
         waterTempSamples: [WaterTempSample] = []) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.maxDepthMeters = maxDepthMeters
        self.durationSeconds = durationSeconds
        self.endingHeartRate = endingHeartRate
        self.waterTemperatureCelsius = waterTemperatureCelsius
        self.profile = profile
        self.heartRateSamples = heartRateSamples
        self.waterTempSamples = waterTempSamples
    }

    init?(userInfo: [String: Any]) {
        guard let start = userInfo["startDate"] as? TimeInterval,
              let end = userInfo["endDate"] as? TimeInterval,
              let maxDepth = userInfo["maxDepthMeters"] as? Double,
              let duration = userInfo["durationSeconds"] as? Double else {
            return nil
        }

        let heartRate = userInfo["endingHeartRate"] as? Int
        let waterTemp = userInfo["waterTemperatureCelsius"] as? Double
        let rawId = (userInfo["id"] as? String).flatMap(UUID.init) ?? UUID()
        let rawProfile = userInfo["profile"] as? [[String: Any]] ?? []
        let samples = DiveSummary.decodeProfile(rawProfile)
        let rawHeartRates = userInfo["heartRateSamples"] as? [[String: Any]] ?? []
        let hrSamples = DiveSummary.decodeHeartRates(rawHeartRates)
        let rawWaterTemps = userInfo["waterTempSamples"] as? [[String: Any]] ?? []
        let wtSamples = DiveSummary.decodeWaterTemps(rawWaterTemps)

        self.init(id: rawId,
                  startDate: Date(timeIntervalSince1970: start),
                  endDate: Date(timeIntervalSince1970: end),
                  maxDepthMeters: maxDepth,
                  durationSeconds: duration,
                  endingHeartRate: heartRate,
                  waterTemperatureCelsius: waterTemp,
                  profile: samples,
                  heartRateSamples: hrSamples,
                  waterTempSamples: wtSamples)
    }

    private enum CodingKeys: String, CodingKey {
        case id, startDate, endDate, maxDepthMeters, durationSeconds, endingHeartRate, waterTemperatureCelsius, profile, heartRateSamples, waterTempSamples
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        maxDepthMeters = try container.decode(Double.self, forKey: .maxDepthMeters)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        endingHeartRate = try container.decodeIfPresent(Int.self, forKey: .endingHeartRate)
        waterTemperatureCelsius = try container.decodeIfPresent(Double.self, forKey: .waterTemperatureCelsius)
        profile = try container.decodeIfPresent([DiveSample].self, forKey: .profile) ?? []
        heartRateSamples = try container.decodeIfPresent([HeartRateSample].self, forKey: .heartRateSamples) ?? []
        waterTempSamples = try container.decodeIfPresent([WaterTempSample].self, forKey: .waterTempSamples) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(maxDepthMeters, forKey: .maxDepthMeters)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(endingHeartRate, forKey: .endingHeartRate)
        try container.encodeIfPresent(waterTemperatureCelsius, forKey: .waterTemperatureCelsius)
        try container.encode(profile, forKey: .profile)
        try container.encode(heartRateSamples, forKey: .heartRateSamples)
        try container.encode(waterTempSamples, forKey: .waterTempSamples)
    }

    var durationText: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var depthText: String {
        String(format: "%.1f m", maxDepthMeters)
    }
}

struct DiveSample: Identifiable, Codable {
    let id: UUID
    let seconds: Double
    let depthMeters: Double

    init(id: UUID = UUID(), seconds: Double, depthMeters: Double) {
        self.id = id
        self.seconds = seconds
        self.depthMeters = depthMeters
    }
}

struct HeartRateSample: Identifiable, Codable {
    let id: UUID
    let seconds: Double
    let bpm: Int

    init(id: UUID = UUID(), seconds: Double, bpm: Int) {
        self.id = id
        self.seconds = seconds
        self.bpm = bpm
    }
}

struct WaterTempSample: Identifiable, Codable {
    let id: UUID
    let seconds: Double
    let celsius: Double

    init(id: UUID = UUID(), seconds: Double, celsius: Double) {
        self.id = id
        self.seconds = seconds
        self.celsius = celsius
    }
}

private extension DiveSummary {
    static func decodeProfile(_ rawProfile: [[String: Any]]) -> [DiveSample] {
        rawProfile.compactMap { dict in
            guard let seconds = dict["seconds"] as? Double,
                  let depth = dict["depthMeters"] as? Double else {
                return nil
            }
            let rawId = (dict["id"] as? String).flatMap(UUID.init) ?? UUID()
            return DiveSample(id: rawId, seconds: seconds, depthMeters: depth)
        }
    }

    static func decodeHeartRates(_ raw: [[String: Any]]) -> [HeartRateSample] {
        raw.compactMap { dict in
            guard let seconds = dict["seconds"] as? Double,
                  let bpm = dict["bpm"] as? Int else {
                return nil
            }
            let rawId = (dict["id"] as? String).flatMap(UUID.init) ?? UUID()
            return HeartRateSample(id: rawId, seconds: seconds, bpm: bpm)
        }
    }

    static func decodeWaterTemps(_ raw: [[String: Any]]) -> [WaterTempSample] {
        raw.compactMap { dict in
            guard let seconds = dict["seconds"] as? Double,
                  let celsius = dict["celsius"] as? Double else {
                return nil
            }
            let rawId = (dict["id"] as? String).flatMap(UUID.init) ?? UUID()
            return WaterTempSample(id: rawId, seconds: seconds, celsius: celsius)
        }
    }
}
