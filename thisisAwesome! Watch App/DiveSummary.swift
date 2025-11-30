//
//  DiveSummary.swift
//  thisisAwesome! Watch App
//

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

    init(id: UUID = UUID(),
         startDate: Date,
         endDate: Date,
         maxDepthMeters: Double,
         durationSeconds: Double,
         endingHeartRate: Int?,
         waterTemperatureCelsius: Double?,
         profile: [DiveSample] = [],
         heartRateSamples: [HeartRateSample] = []) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.maxDepthMeters = maxDepthMeters
        self.durationSeconds = durationSeconds
        self.endingHeartRate = endingHeartRate
        self.waterTemperatureCelsius = waterTemperatureCelsius
        self.profile = profile
        self.heartRateSamples = heartRateSamples
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

        self.init(id: rawId,
                  startDate: Date(timeIntervalSince1970: start),
                  endDate: Date(timeIntervalSince1970: end),
                  maxDepthMeters: maxDepth,
                  durationSeconds: duration,
                  endingHeartRate: heartRate,
                  waterTemperatureCelsius: waterTemp,
                  profile: samples,
                  heartRateSamples: hrSamples)
    }

    private enum CodingKeys: String, CodingKey {
        case id, startDate, endDate, maxDepthMeters, durationSeconds, endingHeartRate, waterTemperatureCelsius, profile, heartRateSamples
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
    }

    var asUserInfo: [String: Any] {
        var payload: [String: Any] = [
            "id": id.uuidString,
            "startDate": startDate.timeIntervalSince1970,
            "endDate": endDate.timeIntervalSince1970,
            "maxDepthMeters": maxDepthMeters,
            "durationSeconds": durationSeconds
        ]
        if let endingHeartRate {
            payload["endingHeartRate"] = endingHeartRate
        }
        if let waterTemperatureCelsius {
            payload["waterTemperatureCelsius"] = waterTemperatureCelsius
        }
        if !profile.isEmpty {
            payload["profile"] = profile.map { $0.asDictionary }
        }
        if !heartRateSamples.isEmpty {
            payload["heartRateSamples"] = heartRateSamples.map { $0.asDictionary }
        }
        return payload
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

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "seconds": seconds,
            "depthMeters": depthMeters
        ]
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

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "seconds": seconds,
            "bpm": bpm
        ]
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
}
