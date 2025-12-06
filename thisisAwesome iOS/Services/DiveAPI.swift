import Foundation

/// Lightweight client for the AWS API Gateway endpoints.
final class DiveAPI {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    struct DivePayload: Encodable {
        let id: String
        let summary: DiveSummary
        let samples: [HeartRateSample]
    }

    func uploadDive(_ summary: DiveSummary,
                    samples: [HeartRateSample],
                    authToken: String) async throws -> String {
        let payload = DivePayload(id: summary.id.uuidString, summary: summary, samples: samples)
        let requestURL = baseURL.appendingPathComponent("dives")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
        return decoded.diveId
    }

    func listDives(authToken: String, limit: Int = 20, cursor: String? = nil) async throws -> DiveListResponse {
        var comps = URLComponents(url: baseURL.appendingPathComponent("dives"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor {
            comps.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
        }
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(DiveListResponse.self, from: data)
    }

    // MARK: - DTOs

    private struct UploadResponse: Decodable {
        let diveId: String
    }

    struct DiveListResponse: Decodable {
        struct Item: Decodable {
            let diveId: String
            let summary: DiveSummary
        }
        let dives: [Item]
        let cursor: String?
    }
}
