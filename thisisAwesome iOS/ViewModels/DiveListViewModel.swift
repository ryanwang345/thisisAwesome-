import Foundation
import Combine

final class DiveListViewModel: ObservableObject {
    @Published var sortMode: SortMode = .dateDesc
    @Published var locationFilter: String?
    @Published var durationRange: ClosedRange<Double> = 0...600
    @Published var minDurationFilter: Double = 0
    @Published var displayedCount: Int = 5
    @Published var hasUserScrolled: Bool = false
    @Published var isLastCardVisible: Bool = false
    @Published var isPaging: Bool = false
    @Published var controller: DiveController?

    var uniqueDives: [DiveSummary] {
        controller?.sortedDives(by: sortMode) ?? []
    }

    func clampedRange(maxDuration: Double) -> ClosedRange<Double> {
        clampRange(durationRange, within: 0...maxDuration)
    }

    func availableLocations(for dives: [DiveSummary]) -> [String] {
        controller?.availableLocations(from: dives) ?? []
    }

    func filteredDives(from dives: [DiveSummary], range: ClosedRange<Double>) -> [DiveSummary] {
        controller?.filteredDives(from: dives,
                                  durationRange: range,
                                  locationFilter: locationFilter,
                                  minDuration: minDurationFilter) ?? []
    }

    func limitedDives(from filtered: [DiveSummary]) -> [DiveSummary] {
        Array(filtered.prefix(displayedCount))
    }

    func resetPagination() {
        displayedCount = 5
        hasUserScrolled = false
        isLastCardVisible = false
        isPaging = false
    }

    func loadMoreIfNeeded(allDives: [DiveSummary]) {
        guard !isPaging, displayedCount < allDives.count else { return }
        isLastCardVisible = false
        isPaging = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.displayedCount = min(self.displayedCount + 5, allDives.count)
            self.hasUserScrolled = false
            self.isPaging = false
        }
    }

    func maybeLoadMore(allDives: [DiveSummary]) {
        guard hasUserScrolled, isLastCardVisible else { return }
        loadMoreIfNeeded(allDives: allDives)
    }

    private func clampRange(_ range: ClosedRange<Double>, within bounds: ClosedRange<Double>) -> ClosedRange<Double> {
        let lower = max(bounds.lowerBound, min(range.lowerBound, bounds.upperBound))
        let upper = min(bounds.upperBound, max(range.upperBound, bounds.lowerBound))
        if lower > upper {
            return bounds.lowerBound...bounds.lowerBound
        }
        return lower...upper
    }
}
