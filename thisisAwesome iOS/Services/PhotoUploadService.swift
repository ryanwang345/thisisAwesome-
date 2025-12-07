import Foundation

struct S3UploadConfig {
    /// Base URL for PUT uploads, e.g. https://your-bucket.s3.amazonaws.com
    let uploadBaseURL: URL
    /// Optional public base URL if different from upload (e.g. CloudFront), else uploadBaseURL is used.
    let publicBaseURL: URL?
    /// Optional authorization header (e.g. for presigned gateways)
    let authorizationHeader: String?
}

final class PhotoUploadService {
    private let config: S3UploadConfig
    private let session: URLSession

    init(config: S3UploadConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func uploadPhoto(data: Data, diveId: UUID) async throws -> URL {
        let fileName = "\(diveId.uuidString)-\(UUID().uuidString).jpg"
        let key = "dives/\(diveId.uuidString)/\(fileName)"
        let uploadURL = config.uploadBaseURL.appendingPathComponent(key)

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        if let auth = config.authorizationHeader {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }

        _ = try await session.upload(for: request, from: data)

        let publicBase = config.publicBaseURL ?? config.uploadBaseURL
        return publicBase.appendingPathComponent(key)
    }
}
