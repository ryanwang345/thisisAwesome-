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
    let locationDescription: String?
    let weatherSummary: String?
    let weatherAirTempCelsius: Double?
    let locationLatitude: Double?
    let locationLongitude: Double?
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
         locationDescription: String? = nil,
         weatherSummary: String? = nil,
         weatherAirTempCelsius: Double? = nil,
         locationLatitude: Double? = nil,
         locationLongitude: Double? = nil,
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
        self.locationDescription = locationDescription
        self.weatherSummary = weatherSummary
        self.weatherAirTempCelsius = weatherAirTempCelsius
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
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
        let location = userInfo["locationDescription"] as? String
        let weather = userInfo["weatherSummary"] as? String
        let airTemp = userInfo["weatherAirTempCelsius"] as? Double
        let lat = userInfo["locationLatitude"] as? Double
        let lon = userInfo["locationLongitude"] as? Double
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
                  locationDescription: location,
                  weatherSummary: weather,
                  weatherAirTempCelsius: airTemp,
                  locationLatitude: lat,
                  locationLongitude: lon,
                  profile: samples,
                  heartRateSamples: hrSamples,
                  waterTempSamples: wtSamples)
    }

    private enum CodingKeys: String, CodingKey {
        case id, startDate, endDate, maxDepthMeters, durationSeconds, endingHeartRate, waterTemperatureCelsius, locationDescription, weatherSummary, weatherAirTempCelsius, locationLatitude, locationLongitude, profile, heartRateSamples, waterTempSamples
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
        locationDescription = try container.decodeIfPresent(String.self, forKey: .locationDescription)
        weatherSummary = try container.decodeIfPresent(String.self, forKey: .weatherSummary)
        weatherAirTempCelsius = try container.decodeIfPresent(Double.self, forKey: .weatherAirTempCelsius)
        locationLatitude = try container.decodeIfPresent(Double.self, forKey: .locationLatitude)
        locationLongitude = try container.decodeIfPresent(Double.self, forKey: .locationLongitude)
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
        try container.encodeIfPresent(locationDescription, forKey: .locationDescription)
        try container.encodeIfPresent(weatherSummary, forKey: .weatherSummary)
        try container.encodeIfPresent(weatherAirTempCelsius, forKey: .weatherAirTempCelsius)
        try container.encodeIfPresent(locationLatitude, forKey: .locationLatitude)
        try container.encodeIfPresent(locationLongitude, forKey: .locationLongitude)
        try container.encode(profile, forKey: .profile)
        try container.encode(heartRateSamples, forKey: .heartRateSamples)
        try container.encode(waterTempSamples, forKey: .waterTempSamples)
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
        if let locationDescription {
            payload["locationDescription"] = locationDescription
        }
        if let weatherSummary {
            payload["weatherSummary"] = weatherSummary
        }
        if let weatherAirTempCelsius {
            payload["weatherAirTempCelsius"] = weatherAirTempCelsius
        }
        if let locationLatitude {
            payload["locationLatitude"] = locationLatitude
        }
        if let locationLongitude {
            payload["locationLongitude"] = locationLongitude
        }
        if !profile.isEmpty {
            payload["profile"] = profile.map { $0.asDictionary }
        }
        if !heartRateSamples.isEmpty {
            payload["heartRateSamples"] = heartRateSamples.map { $0.asDictionary }
        }
        if !waterTempSamples.isEmpty {
            payload["waterTempSamples"] = waterTempSamples.map { $0.asDictionary }
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

struct WaterTempSample: Identifiable, Codable {
    let id: UUID
    let seconds: Double
    let celsius: Double

    init(id: UUID = UUID(), seconds: Double, celsius: Double) {
        self.id = id
        self.seconds = seconds
        self.celsius = celsius
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "seconds": seconds,
            "celsius": celsius
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
