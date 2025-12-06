import Foundation
import Combine

/// Mediates watch connectivity data for the UI.
final class DiveController: ObservableObject {
    @Published private(set) var diveHistory: [DiveSummary] = []
    @Published private(set) var dedupedSorted: [DiveSummary] = []
    @Published private(set) var statusMessage: String = "Waiting for the watch to finish a dive..."
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var currentWeather: WeatherSnapshot?
    @Published private(set) var weatherError: String?

    private let connectivity: PhoneConnectivityManager
    private var cancellables = Set<AnyCancellable>()

    init(connectivity: PhoneConnectivityManager = PhoneConnectivityManager()) {
        self.connectivity = connectivity
        bindConnectivity()
    }

    func activate() {
        connectivity.activate()
    }

    func sortedDives(by sortMode: SortMode) -> [DiveSummary] {
        deduped(by: sortMode, dives: diveHistory)
    }

    func filteredDives(from dives: [DiveSummary],
                      durationRange: ClosedRange<Double>,
                      locationFilter: String?,
                      minDuration: Double) -> [DiveSummary] {
        dives.filter {
            durationRange.contains($0.durationSeconds) &&
            (locationFilter == nil || $0.city == locationFilter) &&
            ($0.durationSeconds >= minDuration)
        }
    }

    func availableLocations(from dives: [DiveSummary]) -> [String] {
        Array(Set(dives.compactMap { $0.city }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func bindConnectivity() {
        connectivity.$diveHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dives in
                guard let self else { return }
                self.diveHistory = dives
                self.dedupedSorted = self.deduped(by: .dateDesc, dives: dives)
            }
            .store(in: &cancellables)

        connectivity.$statusMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$statusMessage)

        connectivity.$isReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$isReachable)

        connectivity.$currentWeather
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentWeather)

        connectivity.$weatherError
            .receive(on: DispatchQueue.main)
            .assign(to: &$weatherError)
    }

    private func deduped(by sortMode: SortMode, dives: [DiveSummary]) -> [DiveSummary] {
        let deduped = Dictionary(grouping: dives) { $0.id }
            .compactMap { $0.value.first }
        switch sortMode {
        case .dateDesc:
            return deduped.sorted { $0.endDate > $1.endDate }
        case .dateAsc:
            return deduped.sorted { $0.endDate < $1.endDate }
        case .locationAZ:
            return deduped.sorted { ($0.locationDescription ?? "").localizedCaseInsensitiveCompare($1.locationDescription ?? "") == .orderedAscending }
        case .locationZA:
            return deduped.sorted { ($0.locationDescription ?? "").localizedCaseInsensitiveCompare($1.locationDescription ?? "") == .orderedDescending }
        }
    }
}
