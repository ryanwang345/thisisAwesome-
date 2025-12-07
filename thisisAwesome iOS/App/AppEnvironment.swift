import Foundation
import Combine

/// Central place to construct and share app-wide services.
final class AppEnvironment: ObservableObject {
    let diveController: DiveController
    let diveAPI: DiveAPI
    let photoUploader: PhotoUploadService
    private var cancellables = Set<AnyCancellable>()

    init(diveController: DiveController = DiveController(),
         diveAPI: DiveAPI? = nil,
         photoUploader: PhotoUploadService? = nil) {
        self.diveController = diveController
        // Point at your API Gateway invoke URL (e.g., https://abc123.execute-api.region.amazonaws.com/v1)
        let base = URL(string: "https://example.execute-api.region.amazonaws.com/v1")!
        self.diveAPI = diveAPI ?? DiveAPI(baseURL: base)
        let uploadBase = URL(string: Bundle.main.object(forInfoDictionaryKey: "S3UploadBaseURL") as? String ?? "https://example-bucket.s3.amazonaws.com")!
        let publicBase = (Bundle.main.object(forInfoDictionaryKey: "S3PublicBaseURL") as? String).flatMap(URL.init(string:))
        let authHeader = Bundle.main.object(forInfoDictionaryKey: "S3UploadAuthorization") as? String
        let uploadConfig = S3UploadConfig(uploadBaseURL: uploadBase, publicBaseURL: publicBase, authorizationHeader: authHeader)
        self.photoUploader = photoUploader ?? PhotoUploadService(config: uploadConfig)
        // Forward controller changes so SwiftUI updates when data arrives.
        diveController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
