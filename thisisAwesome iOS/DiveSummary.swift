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

    init(id: UUID = UUID(),
         startDate: Date,
         endDate: Date,
         maxDepthMeters: Double,
         durationSeconds: Double,
         endingHeartRate: Int?,
         waterTemperatureCelsius: Double?,
         profile: [DiveSample] = []) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.maxDepthMeters = maxDepthMeters
        self.durationSeconds = durationSeconds
        self.endingHeartRate = endingHeartRate
        self.waterTemperatureCelsius = waterTemperatureCelsius
        self.profile = profile
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
        let samples = rawProfile.compactMap(DiveSample.init(dictionary:))

        self.init(id: rawId,
                  startDate: Date(timeIntervalSince1970: start),
                  endDate: Date(timeIntervalSince1970: end),
                  maxDepthMeters: maxDepth,
                  durationSeconds: duration,
                  endingHeartRate: heartRate,
                  waterTemperatureCelsius: waterTemp,
                  profile: samples)
    }

    private enum CodingKeys: String, CodingKey {
        case id, startDate, endDate, maxDepthMeters, durationSeconds, endingHeartRate, waterTemperatureCelsius, profile
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

    init?(dictionary: [String: Any]) {
        guard let seconds = dictionary["seconds"] as? Double,
              let depth = dictionary["depthMeters"] as? Double else {
            return nil
        }
        let rawId = (dictionary["id"] as? String).flatMap(UUID.init) ?? UUID()
        self.init(id: rawId, seconds: seconds, depthMeters: depth)
    }
}
