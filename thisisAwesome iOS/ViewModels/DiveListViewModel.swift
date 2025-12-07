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
    @Published var photoStates: [UUID: PhotoUploadState] = [:]
    @Published var photoURLs: [UUID: URL] = [:]
    @Published var controller: DiveController?

    @Published private(set) var uniqueDives: [DiveSummary] = []
    @Published private(set) var availableLocations: [String] = []
    @Published private(set) var filteredDives: [DiveSummary] = []
    @Published private(set) var limitedDives: [DiveSummary] = []

    private var cancellables = Set<AnyCancellable>()

    func bind(controller: DiveController, maxDuration: @escaping () -> Double) {
        self.controller = controller

        // React to controller history changes
        controller.$dedupedSorted
            .map { $0 }
            .sink { [weak self] dives in
                self?.uniqueDives = dives
                self?.recompute(maxDuration: maxDuration())
            }
            .store(in: &cancellables)

        // React to filter changes with debounce for slider
        $durationRange
            .debounce(for: .milliseconds(180), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recompute(maxDuration: maxDuration())
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3($sortMode, $locationFilter, $minDurationFilter)
            .sink { [weak self] _, _, _ in
                self?.recompute(maxDuration: maxDuration())
            }
            .store(in: &cancellables)
    }

    private func recompute(maxDuration: Double) {
        guard let controller else {
            uniqueDives = []
            availableLocations = []
            filteredDives = []
            limitedDives = []
            return
        }

        let sorted = controller.sortedDives(by: sortMode)
        uniqueDives = sorted

        availableLocations = controller.availableLocations(from: sorted)
        let clamped = clampRange(durationRange, within: 0...maxDuration)
        filteredDives = controller.filteredDives(from: sorted,
                                                durationRange: clamped,
                                                locationFilter: locationFilter,
                                                minDuration: minDurationFilter)
        limitedDives = Array(filteredDives.prefix(displayedCount))
    }

    func resetPagination() {
        displayedCount = 5
        hasUserScrolled = false
        isLastCardVisible = false
        isPaging = false
        limitedDives = Array(filteredDives.prefix(displayedCount))
    }

    func loadMoreIfNeeded(allDives: [DiveSummary]) {
        guard !isPaging, displayedCount < allDives.count else { return }
        isLastCardVisible = false
        isPaging = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.displayedCount = min(self.displayedCount + 5, allDives.count)
            self.limitedDives = Array(self.filteredDives.prefix(self.displayedCount))
            self.hasUserScrolled = false
            self.isPaging = false
        }
    }

    func maybeLoadMore(allDives: [DiveSummary]) {
        guard hasUserScrolled, isLastCardVisible else { return }
        loadMoreIfNeeded(allDives: allDives)
    }

    // MARK: - Photo uploads

    func uploadPhoto(for dive: DiveSummary,
                     data: Data,
                     uploader: PhotoUploadService) async {
        await MainActor.run {
            photoStates[dive.id] = .uploading
        }

        do {
            let url = try await uploader.uploadPhoto(data: data, diveId: dive.id)
            await MainActor.run {
                photoURLs[dive.id] = url
                photoStates[dive.id] = .uploaded(url)
            }
        } catch {
            await MainActor.run {
                photoStates[dive.id] = .failed(error.localizedDescription)
            }
        }
    }

    func state(for dive: DiveSummary) -> PhotoUploadState {
        photoStates[dive.id] ?? .idle
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

enum PhotoUploadState: Equatable {
    case idle
    case uploading
    case uploaded(URL)
    case failed(String)
}
