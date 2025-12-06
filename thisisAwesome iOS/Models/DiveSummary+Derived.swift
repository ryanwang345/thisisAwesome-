import Foundation

extension DiveSummary {
    /// Average heart rate from samples, falling back to the ending value when samples are missing.
    var averageHeartRate: Int? {
        if !heartRateSamples.isEmpty {
            let total = heartRateSamples.reduce(0) { $0 + $1.bpm }
            let avg = Double(total) / Double(heartRateSamples.count)
            return Int(avg.rounded())
        }
        return endingHeartRate
    }

    var averageHeartRateText: String {
        averageHeartRate.map { "\($0) bpm" } ?? "--"
    }

    /// Convenience for parsing the first component of a location description.
    var city: String? {
        guard let desc = locationDescription, !desc.isEmpty else { return nil }
        let parts = desc.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
        let cityName = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cityName?.isEmpty == false ? cityName : nil
    }
}
