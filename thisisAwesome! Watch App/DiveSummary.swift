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

    init(id: UUID = UUID(),
         startDate: Date,
         endDate: Date,
         maxDepthMeters: Double,
         durationSeconds: Double,
         endingHeartRate: Int?,
         waterTemperatureCelsius: Double?) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.maxDepthMeters = maxDepthMeters
        self.durationSeconds = durationSeconds
        self.endingHeartRate = endingHeartRate
        self.waterTemperatureCelsius = waterTemperatureCelsius
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

        self.init(id: rawId,
                  startDate: Date(timeIntervalSince1970: start),
                  endDate: Date(timeIntervalSince1970: end),
                  maxDepthMeters: maxDepth,
                  durationSeconds: duration,
                  endingHeartRate: heartRate,
                  waterTemperatureCelsius: waterTemp)
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
        return payload
    }
}
