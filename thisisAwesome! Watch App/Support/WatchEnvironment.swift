import Foundation
import Combine

/// Central container for shared Watch services.
final class WatchEnvironment: ObservableObject {
    let heartRateManager = HeartRateManager()
    let waterManager = ActiveWaterSubmersionManager()
    let compassManager = CompassManager()
    let syncManager = DiveSyncManager()
    let locationRecorder = LocationRecorder()
}
