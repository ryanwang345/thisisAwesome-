import Foundation
import Combine

/// Central place to construct and share app-wide services.
final class AppEnvironment: ObservableObject {
    let diveController: DiveController
    private var cancellables = Set<AnyCancellable>()

    init(diveController: DiveController = DiveController()) {
        self.diveController = diveController
        // Forward controller changes so SwiftUI updates when data arrives.
        diveController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
