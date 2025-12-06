import Foundation
import Combine

/// Central place to construct and share app-wide services.
final class AppEnvironment: ObservableObject {
    let diveController: DiveController
    let diveAPI: DiveAPI
    private var cancellables = Set<AnyCancellable>()

    init(diveController: DiveController = DiveController(),
         diveAPI: DiveAPI? = nil) {
        self.diveController = diveController
        // Point at your API Gateway invoke URL (e.g., https://abc123.execute-api.region.amazonaws.com/v1)
        let base = URL(string: "https://example.execute-api.region.amazonaws.com/v1")!
        self.diveAPI = diveAPI ?? DiveAPI(baseURL: base)
        // Forward controller changes so SwiftUI updates when data arrives.
        diveController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
