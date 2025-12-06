import SwiftUI
import Charts
import UIKit
import MapKit

struct ContentView: View {
    @EnvironmentObject private var environment: AppEnvironment
    private var controller: DiveController { environment.diveController }
    private let primaryText = Color.white.opacity(0.96)
    private let secondaryText = Color.white.opacity(0.72)
    private let neonBlue = Color(red: 0.38, green: 0.86, blue: 1.0)
    private let neonPurple = Color(red: 0.72, green: 0.56, blue: 1.0)
    private let midnight = Color(red: 0.03, green: 0.06, blue: 0.12)
    @State private var selectedDepthTime: Double?
    @State private var selectedHeartTime: Double?
    @State private var scrubTime: Double = 0
    @State private var hasSetScrub: Bool = false
    @State private var expandedDives: Set<UUID> = []
    @StateObject private var listViewModel = DiveListViewModel()

    private func toggleExpansion(for dive: DiveSummary) {
        if expandedDives.contains(dive.id) {
            expandedDives.remove(dive.id)
        } else {
            expandedDives.insert(dive.id)
        }
    }

    var body: some View {
        let uniqueDives = listViewModel.uniqueDives
        let maxDuration = max(uniqueDives.map(\.durationSeconds).max() ?? 0, 60)
        let clampedRange = listViewModel.clampedRange(maxDuration: maxDuration)
        let availableLocations = listViewModel.availableLocations(for: uniqueDives)
        let filteredDives = listViewModel.filteredDives(from: uniqueDives, range: clampedRange)
        let limitedDives = listViewModel.limitedDives(from: filteredDives)

        NavigationStack {
            ZStack {
                glassBackdrop
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 18) {
                        header

                        filterControls(maxDuration: maxDuration)
                        locationControls(availableLocations: availableLocations)
                        sortControls
                        metricStrip(dives: filteredDives)
                        weatherCard()

                        if limitedDives.isEmpty {
                            waitingCard
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Dives")
                                    .font(.headline)
                                    .foregroundStyle(primaryText)

                                ForEach(limitedDives) { dive in
                                    let expanded = expandedDives.contains(dive.id)
                                    let isLast = dive.id == limitedDives.last?.id
                diveCard(dive,
                         showShare: true,
                         showMap: true,
                         isExpanded: expanded,
                         onToggle: { toggleExpansion(for: dive) })
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        toggleExpansion(for: dive)
                                    }
                                    .onAppear {
                                        if isLast {
                                            listViewModel.isLastCardVisible = true
                                            listViewModel.maybeLoadMore(allDives: filteredDives)
                                        }
                                    }
                                    .onDisappear {
                                        if isLast {
                                            listViewModel.isLastCardVisible = false
                                        }
                                    }
                                }

                                Color.clear
                                    .frame(height: 40)
                                    .id("pagination-\(listViewModel.displayedCount)")
                                    .onAppear {
                                        listViewModel.isLastCardVisible = true
                                        listViewModel.maybeLoadMore(allDives: filteredDives)
                                    }
                                    .onDisappear {
                                        listViewModel.isLastCardVisible = false
                                }

                                if listViewModel.isPaging {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                        Text("Loading more dives…")
                                            .font(.caption)
                                            .foregroundStyle(secondaryText)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 8)
                                }

                                if listViewModel.displayedCount < filteredDives.count && !listViewModel.isPaging {
                                    Button {
                                        listViewModel.hasUserScrolled = true
                                        listViewModel.loadMoreIfNeeded(allDives: filteredDives)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.down.circle")
                                            Text("Load 5 more")
                                                .font(.caption.weight(.semibold))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .glassCard(cornerRadius: 14, opacity: 0.22, shadow: 12, y: 6)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(primaryText)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .gesture(DragGesture().onChanged { value in
                    if value.translation.height != 0 {
                        listViewModel.hasUserScrolled = true
                    }
                })
            }
            .navigationTitle("Dive Sync")
            .navigationBarTitleDisplayMode(.inline)
            .foregroundStyle(primaryText)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
        }
        .onAppear {
            if listViewModel.controller == nil {
                listViewModel.controller = controller
            }
            controller.activate()
        }
        .onChange(of: filteredDives.count) { _, _ in
            listViewModel.resetPagination()
        }
        .onChange(of: controller.diveHistory.first?.id) { _, _ in
            if let latest = controller.diveHistory.sorted(by: { $0.endDate > $1.endDate }).first {
                scrubTime = defaultScrubTime(for: latest)
                hasSetScrub = false
                expandedDives.removeAll() // do not auto-expand latest
                listViewModel.resetPagination()
            } else {
                resetScrubber()
            }
        }
        .onChange(of: scrubTime) { _, newValue in
            selectedDepthTime = newValue
            selectedHeartTime = newValue
        }
        .preferredColorScheme(.dark)
    }

    private var glassBackdrop: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.02, green: 0.08, blue: 0.18),
                Color(red: 0.02, green: 0.04, blue: 0.10)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(
                    RadialGradient(colors: [neonBlue.opacity(0.5), Color.clear],
                                   center: .center,
                                   startRadius: 20,
                                   endRadius: 320)
                )
                .blur(radius: 90)
                .offset(x: -120, y: -260)
                .allowsHitTesting(false)

            Circle()
                .fill(
                    RadialGradient(colors: [neonPurple.opacity(0.45), Color.clear],
                                   center: .center,
                                   startRadius: 10,
                                   endRadius: 260)
                )
                .blur(radius: 110)
                .offset(x: 160, y: 140)
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .strokeBorder(LinearGradient(colors: [neonBlue.opacity(0.25), neonPurple.opacity(0.12)],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing),
                              lineWidth: 1.2)
                .blur(radius: 20)
                .scaleEffect(1.05)
                .padding(30)
                .allowsHitTesting(false)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [neonBlue.opacity(0.75), neonPurple.opacity(0.7)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .frame(width: 58, height: 58)
                    .blur(radius: 8)
                    .opacity(0.7)
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle()
                            .stroke(LinearGradient(colors: [Color.white.opacity(0.65), Color.white.opacity(0.18)],
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing),
                                    lineWidth: 1.2)
                    )
                    .shadow(color: neonBlue.opacity(0.24), radius: 16, y: 10)
                Image(systemName: controller.isReachable ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(primaryText)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Dive Sync")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(LinearGradient(colors: [primaryText, neonBlue.opacity(0.95)], startPoint: .leading, endPoint: .trailing))

                HStack(spacing: 8) {
                    Circle()
                        .fill(controller.isReachable ? Color.green.opacity(0.8) : Color.orange.opacity(0.9))
                        .frame(width: 10, height: 10)
                    Text(controller.isReachable ? "Connected to watch" : controller.statusMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }

                Text("Fluid glass interface tuned for your dives.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(controller.isReachable ? "Live" : "Standby")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassPill(opacity: 0.22, shadow: 0)
                    .foregroundStyle(primaryText)

                Text("\(controller.diveHistory.count) dive\(controller.diveHistory.count == 1 ? "" : "s")")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(secondaryText)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22, opacity: 0.22)
    }

    private func filterControls(maxDuration: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Filter by duration", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryText)
                Spacer()
                Text("\(formattedElapsed(listViewModel.durationRange.lowerBound)) – \(formattedElapsed(listViewModel.durationRange.upperBound))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassPill(opacity: 0.22, shadow: 0)
            }
            RangeDurationSlider(range: $listViewModel.durationRange, bounds: 0...maxDuration)
                .frame(height: 44)
        }
        .padding(16)
        .glassCard(cornerRadius: 18, opacity: 0.2)
    }

    private func locationControls(availableLocations: [String]) -> some View {
        HStack {
            Label("Location", systemImage: "mappin.and.ellipse")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryText)
            Menu {
                Button {
                    listViewModel.locationFilter = nil
                } label: {
                    Label("All locations", systemImage: listViewModel.locationFilter == nil ? "checkmark" : "")
                }
                ForEach(availableLocations, id: \.self) { city in
                    Button {
                        listViewModel.locationFilter = city
                    } label: {
                        Label(city, systemImage: listViewModel.locationFilter == city ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(listViewModel.locationFilter ?? "All locations")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassPill()
            }
            Spacer()
        }
        .padding(16)
        .glassCard(cornerRadius: 18, opacity: 0.2)
    }

    private var sortControls: some View {
        HStack {
            Label("Sort by", systemImage: "arrow.up.arrow.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryText)
            Menu {
                ForEach(SortMode.allCases) { option in
                    Button {
                        listViewModel.sortMode = option
                    } label: {
                        Label(option.label, systemImage: option == listViewModel.sortMode ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle.magnifyingglass")
                    Text(listViewModel.sortMode.label)
                        .font(.caption.weight(.bold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassPill()
            }
            Spacer()
        }
        .padding(16)
        .glassCard(cornerRadius: 18, opacity: 0.2)
    }

    private var waitingCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi")
                .font(.largeTitle)
                .foregroundStyle(neonBlue)
            Text("Finish a dive on your Apple Watch to sync the summary here.")
                .font(.headline)
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("The new liquid glass layout will light up as soon as data flows in.")
                .font(.caption)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard(cornerRadius: 20, opacity: 0.22)
    }

    private func diveCard(_ dive: DiveSummary, showShare: Bool = true, showMap: Bool = true, isExpanded: Bool = true, onToggle: (() -> Void)? = nil) -> some View {
        let profileSamples = profilePoints(for: dive)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last dive")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        Text(dive.endDate, style: .time)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(dive.endDate, style: .date)
                            .font(.caption2)
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    if showShare {
                        Button {
                            captureAndShare(dive)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassPill(opacity: 0.22)
                        }
                        .foregroundStyle(primaryText)
                        .accessibilityLabel("Share dive")
                    }
                    if let onToggle {
                        Button(action: onToggle) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.subheadline.weight(.bold))
                                .frame(width: 38, height: 38)
                                .glassPill(opacity: 0.22, shadow: 0)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(primaryText)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dive.depthText)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LinearGradient(colors: [neonBlue, neonPurple.opacity(0.9)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text("Max depth")
                            .font(.caption2)
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        stat(label: "Duration", value: dive.durationText)
                        Divider().frame(height: 28).background(secondaryText.opacity(0.25))
                        stat(label: "Avg. Heart Rate", value: dive.averageHeartRateText)
                    }
                }
            }

            HStack(spacing: 12) {
                capsuleStat(label: "Duration", value: dive.durationText, color: neonBlue)
                capsuleStat(label: "Water", value: dive.waterTemperatureCelsius.map { String(format: "%.1f C", $0) } ?? "--", color: Color.cyan)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            diveMetaRow(dive)
            if showMap {
                diveMap(dive)
            }

            if isExpanded {
                intervalScrubber(for: dive, samples: profileSamples)
                diveProfileChart(dive, samples: profileSamples)
                waterTempChart(dive)
                heartRateChart(dive)
                RawSamplesView(dive: dive, primaryText: primaryText, secondaryText: secondaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24, opacity: 0.22)
    }

    private func stat(label: String, value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color ?? secondaryText)
            Text(value)
                .font(.headline)
                .foregroundStyle(color ?? primaryText)
                .monospacedDigit()
        }
    }

    private func historyRow(_ dive: DiveSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dive.endDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                Text(dive.endDate, style: .time)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(primaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(dive.depthText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(neonBlue)
                    .monospacedDigit()
                Text("\(dive.durationText) • \(dive.averageHeartRateText)")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 14, opacity: 0.18, shadow: 12, y: 6)
    }
    
    private func intervalScrubber(for dive: DiveSummary, samples: [DiveSample]) -> some View {
        let maxProfileTime = samples.map(\.seconds).max() ?? 0
        let maxHeartTime = dive.heartRateSamples.map(\.seconds).max() ?? 0
        let maxTempTime = dive.waterTempSamples.map(\.seconds).max() ?? 0
        let duration = max(dive.durationSeconds, max(maxProfileTime, maxHeartTime))
        let safeDuration = max(duration, maxTempTime, 1)
        let timelineTime = min(scrubTime, safeDuration)
        let activeTime = timelineTime
        let depthSample = interpolatedDepth(at: activeTime, samples: samples)
        let heartSample = interpolatedHeartRate(at: activeTime, samples: dive.heartRateSamples)
        let waterSample = interpolatedWaterTemp(at: activeTime, samples: dive.waterTempSamples)
        let sliderBinding = Binding(
            get: { min(timelineTime, safeDuration) },
            set: { newValue in
                scrubTime = newValue
                hasSetScrub = true
                selectedDepthTime = newValue
                selectedHeartTime = newValue
            }
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Timeline")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)
                Spacer()
                Text(formattedElapsed(activeTime))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassPill(opacity: 0.22, shadow: 0)
            }

            HStack(spacing: 10) {
                Text("0:00")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)

                TimelineSlider(value: sliderBinding, range: 0...safeDuration) { editing in
                    if !editing {
                        selectedDepthTime = scrubTime
                        selectedHeartTime = scrubTime
                    }
                }

                Text(formattedElapsed(safeDuration))
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Depth")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryText)
                    Text(depthSample.map { String(format: "%.1f m", $0.depthMeters) } ?? "--")
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    .monospacedDigit()
                }

                Divider()
                    .frame(height: 24)
                    .background(secondaryText.opacity(0.25))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Heart rate")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryText)
                    Text(heartSample.map { "\($0.bpm) bpm" } ?? "--")
                        .font(.headline)
                        .foregroundStyle(primaryText)
                        .monospacedDigit()
                }

                Divider()
                    .frame(height: 24)
                    .background(secondaryText.opacity(0.25))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Water temp")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryText)
                    Text(waterSample.map { String(format: "%.1f C", $0.celsius) } ?? "--")
                        .font(.headline)
                        .foregroundStyle(primaryText)
                        .monospacedDigit()
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 16, opacity: 0.2, shadow: 12, y: 6)
        .onAppear {
            scrubTime = safeDuration
            hasSetScrub = false
        }
        .onChange(of: dive.id) { _, _ in
            scrubTime = safeDuration
            hasSetScrub = false
        }
    }

    private func resetScrubber() {
        scrubTime = 0
        hasSetScrub = false
        selectedDepthTime = nil
        selectedHeartTime = nil
    }

    private func defaultScrubTime(for dive: DiveSummary) -> Double {
        let profileTime = dive.profile.map(\.seconds).max() ?? 0
        let heartTime = dive.heartRateSamples.map(\.seconds).max() ?? 0
        let tempTime = dive.waterTempSamples.map(\.seconds).max() ?? 0
        return max(dive.durationSeconds, profileTime, heartTime, tempTime, 1)
    }

    private struct TimelineSlider: View {
        @Binding var value: Double
        let range: ClosedRange<Double>
        var onEditingChanged: (Bool) -> Void = { _ in }

        private let trackHeight: CGFloat = 8
        private let thumbSize: CGFloat = 28

        var body: some View {
            GeometryReader { geo in
                let totalWidth = max(geo.size.width, thumbSize)
                let normalized = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                let clamped = max(0, min(normalized, 1))
                let x = clamped * (totalWidth - thumbSize)
                let activeGradient = LinearGradient(colors: [Color.cyan.opacity(0.9), Color.purple.opacity(0.75)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(activeGradient)
                        .frame(width: x + thumbSize * 0.5, height: trackHeight)

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: Color.cyan.opacity(0.35), radius: 8, y: 3)
                        .overlay {
                            Circle()
                                .stroke(activeGradient, lineWidth: 1.2)
                        }
                        .offset(x: x)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    let location = gesture.location.x
                                    let ratio = max(0, min(location / (totalWidth - thumbSize), 1))
                                    let newValue = Double(ratio) * (range.upperBound - range.lowerBound) + range.lowerBound
                                    value = newValue
                                    onEditingChanged(true)
                                }
                                .onEnded { _ in
                                    onEditingChanged(false)
                                }
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { gesture in
                            let location = gesture.location.x
                            let ratio = max(0, min(location / totalWidth, 1))
                            let newValue = Double(ratio) * (range.upperBound - range.lowerBound) + range.lowerBound
                            value = newValue
                            onEditingChanged(false)
                        }
                )
            }
            .frame(height: max(thumbSize, 32))
        }
    }

    private func diveProfileChart(_ dive: DiveSummary, samples: [DiveSample]) -> some View {
        // Ensure the series is padded to the full duration so the line reaches the right edge
        let effectiveDuration = max(samples.map { $0.seconds }.max() ?? 0, dive.durationSeconds, 1)
        let smoothedSamples = densifyDepth(samples: samples, step: 5, duration: effectiveDuration)
        let chartPoints = smoothedSamples.map { ChartPoint(id: $0.id, seconds: $0.seconds, depthMeters: $0.depthMeters, plotDepth: -$0.depthMeters) }
        let maxDepth = max(chartPoints.map { $0.depthMeters }.max() ?? 0, dive.maxDepthMeters)
        let duration = effectiveDuration
        let focusTime = min(hasSetScrub ? scrubTime : duration, duration)
        let selected = interpolatedDepthPoint(for: chartPoints, at: focusTime)
        let cardBackground = LinearGradient(colors: [midnight.opacity(0.9), Color.black.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing)
        let border = Color.white.opacity(0.14)
        let lineGradient = LinearGradient(colors: [.cyan, .green, .yellow, .orange], startPoint: .leading, endPoint: .trailing)
        let fillGradient = LinearGradient(colors: [Color.cyan.opacity(0.32), Color.blue.opacity(0.12)], startPoint: .top, endPoint: .bottom)
        _ = duration > 900 ? 300 : (duration > 480 ? 120 : 60)
        let yDomain = (-(maxDepth + 2))...0

        let chartBody = Chart {
            ForEach(chartPoints) { sample in
                AreaMark(
                    x: .value("Time", sample.seconds),
                    y: .value("Depth", sample.plotDepth)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(fillGradient)
            }

            ForEach(chartPoints) { sample in
                LineMark(
                    x: .value("Time", sample.seconds),
                    y: .value("Depth", sample.plotDepth)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(lineGradient)
            }

            if let selected {
                RuleMark(x: .value("Time", selected.seconds))
                    .foregroundStyle(.white.opacity(0.35))
                PointMark(
                    x: .value("Time", selected.seconds),
                    y: .value("Depth", selected.plotDepth)
                )
                .symbolSize(90)
                .foregroundStyle(.white)
                .annotation(position: .topLeading, alignment: .leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedElapsed(selected.seconds))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(String(format: "%.2f m", selected.depthMeters))
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .chartXScale(domain: 0...effectiveDuration,
                     range: .plotDimension(padding: 0))
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: timeTickValues(duration: effectiveDuration)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisTick().foregroundStyle(Color.white.opacity(0.25))
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(formattedElapsed(seconds))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: depthTicks(maxDepth: maxDepth)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisTick().foregroundStyle(Color.white.opacity(0.25))
                AxisValueLabel {
                    if let depth = value.as(Double.self) {
                        Text(String(format: "%.2f m", abs(depth)))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
        }
        .frame(height: 240)
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let anchor = proxy.plotFrame {
                    let frame = geo[anchor]
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x - frame.minX
                                    guard x >= 0, x <= frame.width,
                                          let time: Double = proxy.value(atX: x) else { return }
                                    let clamped = max(0, min(time, effectiveDuration))
                                    selectedDepthTime = clamped
                                    scrubTime = clamped
                                    hasSetScrub = true
                                }
                                .onEnded { _ in
                                    selectedDepthTime = scrubTime
                                }
                        )
                } else {
                    Color.clear
                }
            }
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dive profile")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.white.opacity(0.7))
            }

            if chartPoints.count > 1 {
                chartBody
            } else {
                Text("We didn't receive a depth trace for this dive yet.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            }

            HStack(spacing: 12) {
                legendSwatch(color: .cyan, label: "Descent")
                legendSwatch(color: .green, label: "Bottom")
                legendSwatch(color: .yellow, label: "Ascent")
                legendSwatch(color: .red.opacity(0.85), label: "Fast")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(border, lineWidth: 1.2)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: neonBlue.opacity(0.16), radius: 18, y: 10)
    }

    private func profilePoints(for dive: DiveSummary) -> [DiveSample] {
        if !dive.profile.isEmpty {
            return dive.profile.sorted { $0.seconds < $1.seconds }
        }

        // Fallback shape so the UI still has a visual profile even if the watch did not send samples.
        let duration = max(dive.durationSeconds, 600)
        let stages: [(Double, Double)] = [
            (0.05, 2),
            (0.18, dive.maxDepthMeters * 0.35),
            (0.35, dive.maxDepthMeters),
            (0.55, dive.maxDepthMeters * 0.9),
            (0.8, dive.maxDepthMeters * 0.2),
            (1.0, 0)
        ]
        return stages.enumerated().map { idx, stage in
            DiveSample(id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", idx))") ?? UUID(),
                       seconds: duration * stage.0,
                       depthMeters: stage.1)
        }
    }

    private func depthTicks(maxDepth: Double) -> [Double] {
        let step: Double
        switch maxDepth {
        case 0..<10: step = 2
        case 10..<30: step = 5
        default: step = 10
        }
        let maxTick = maxDepth + step
        return stride(from: 0.0, through: maxTick, by: step).map { -$0 }
    }

    private func formattedElapsed(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let remainder = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private func formattedHoursMinutes(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func coordinateLabel(lat: Double, lon: Double) -> String {
        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"
        return String(format: "%.2f°%@ %.2f°%@", abs(lat), latDir, abs(lon), lonDir)
    }

    private func weatherCard() -> some View {
        if let weather = controller.currentWeather {
            return AnyView(
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Weather near dive")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryText)
                        HStack(spacing: 10) {
                            Image(systemName: weather.symbolName)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(neonBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%.1f°C", weather.temperatureC))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(primaryText)
                                Text(weather.condition)
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Wind \(String(format: "%.0f km/h", weather.windSpeedKmh))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(primaryText)
                                Text(coordinateLabel(lat: weather.latitude, lon: weather.longitude))
                                    .font(.caption2)
                                    .foregroundStyle(secondaryText)
                            }
                        }
                    }
                }
                .padding(14)
                .glassCard(cornerRadius: 18, opacity: 0.2, shadow: 12, y: 6)
            )
        } else if let error = controller.weatherError {
            return AnyView(
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weather unavailable")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(primaryText)
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(secondaryText)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(14)
                .glassCard(cornerRadius: 16, opacity: 0.18, shadow: 10, y: 6)
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 24, height: 6)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func capsuleStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(primaryText)
                .monospacedDigit()
        }
    }

    private func diveMetaRow(_ dive: DiveSummary) -> some View {
        let location = dive.locationDescription ?? "Location not recorded"
        let weather = dive.weatherSummary ?? "Weather not recorded"
        let air = dive.weatherAirTempCelsius.map { String(format: "%.1f C", $0) }

        return HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(neonBlue)
                Text(location)
                    .font(.caption)
                    .foregroundStyle(primaryText)
                    .lineLimit(2)
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "cloud.sun")
                    .foregroundStyle(neonPurple)
                VStack(alignment: .leading, spacing: 2) {
                    Text(weather)
                        .font(.caption)
                        .foregroundStyle(primaryText)
                        .lineLimit(2)
                    if let air {
                        Text("Air \(air)")
                            .font(.caption2)
                            .foregroundStyle(secondaryText)
                    }
                }
            }
        }
    }

    private func diveMap(_ dive: DiveSummary) -> some View {
        guard let lat = dive.locationLatitude,
              let lon = dive.locationLongitude else {
            return AnyView(EmptyView())
        }
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        return AnyView(
            Map(position: .constant(.region(region))) {
                Marker(dive.locationDescription ?? "Dive", coordinate: region.center)
            }
            .mapStyle(.standard)
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: neonBlue.opacity(0.15), radius: 12, y: 6)
        )
    }

    private struct ChartPoint: Identifiable {
        let id: UUID
        let seconds: Double
        let depthMeters: Double
        let plotDepth: Double
    }

    private struct RangeDurationSlider: View {
        @Binding var range: ClosedRange<Double>
        let bounds: ClosedRange<Double>

        private let trackHeight: CGFloat = 8
        private let thumbSize: CGFloat = 26

        var body: some View {
            GeometryReader { geo in
                let width = max(geo.size.width, thumbSize * 2)
                let lowerRatio = CGFloat((range.lowerBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound))
                let upperRatio = CGFloat((range.upperBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound))
                let lowerX = max(0, min(lowerRatio, 1)) * (width - thumbSize)
                let upperX = max(0, min(upperRatio, 1)) * (width - thumbSize)
                let activeGradient = LinearGradient(colors: [Color.cyan.opacity(0.9), Color.purple.opacity(0.75)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(activeGradient)
                        .frame(width: max(upperX - lowerX + thumbSize, 0), height: trackHeight)
                        .offset(x: lowerX)

                    thumb(x: lowerX)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    let location = gesture.location.x
                                    let ratio = max(0, min(location / (width - thumbSize), 1))
                                    let value = Double(ratio) * (bounds.upperBound - bounds.lowerBound) + bounds.lowerBound
                                    range = min(value, range.upperBound)...range.upperBound
                                }
                        )

                    thumb(x: upperX)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    let location = gesture.location.x
                                    let ratio = max(0, min(location / (width - thumbSize), 1))
                                    let value = Double(ratio) * (bounds.upperBound - bounds.lowerBound) + bounds.lowerBound
                                    range = range.lowerBound...max(value, range.lowerBound)
                                }
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        private func thumb(x: CGFloat) -> some View {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: thumbSize, height: thumbSize)
                .shadow(color: Color.cyan.opacity(0.35), radius: 6, y: 2)
                .overlay {
                    Circle()
                        .stroke(LinearGradient(colors: [Color.cyan.opacity(0.9), Color.purple.opacity(0.75)],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing),
                                lineWidth: 1.1)
                }
                .offset(x: x)
        }
    }

    private func timeTickValues(duration: Double) -> [Double] {
        let spacing = timeTickSpacing(for: duration)
        let cappedDuration = max(duration, spacing)
        var values: [Double] = []
        var current: Double = 0
        while current < cappedDuration {
            values.append(current)
            current += spacing
        }
        values.append(cappedDuration)
        return values
    }

    private func timeTickSpacing(for duration: Double) -> Double {
        // Aim for ~6 ticks with a friendly spacing
        let targetTicks = 6.0
        let raw = max(duration / targetTicks, 1)
        let candidates: [Double] = [
            1, 2, 5,
            10, 15, 20, 30,
            60, 90, 120, 180,
            300, 600, 900, 1200,
            1800, 3600, 7200
        ]
        return candidates.first(where: { $0 >= raw }) ?? 7200
    }

    private func metricStrip(dives: [DiveSummary]) -> some View {
        guard !dives.isEmpty else {
            return AnyView(
                HStack {
                    metricTile(title: "Ready", value: "No dives yet", subtitle: "Sync from your watch", icon: "sparkles")
                    Spacer(minLength: 0)
                }
            )
        }

        let totalSeconds = dives.reduce(0) { $0 + $1.durationSeconds }
        let avgSeconds = totalSeconds / Double(max(dives.count, 1))
        let deepest = dives.map(\.maxDepthMeters).max() ?? 0
        let uniqueLocations = Set(dives.compactMap(\.city)).count

        return AnyView(
            HStack(spacing: 12) {
                metricTile(title: "Total time", value: formattedHoursMinutes(totalSeconds), subtitle: "\(dives.count) dive\(dives.count == 1 ? "" : "s")", icon: "timer")
                metricTile(title: "Deepest", value: String(format: "%.1f m", deepest), subtitle: "\(uniqueLocations) location\(uniqueLocations == 1 ? "" : "s")", icon: "drop.fill")
                metricTile(title: "Avg. duration", value: formattedElapsed(avgSeconds), subtitle: "per dive", icon: "heart.text.square")
            }
        )
    }

    private func metricTile(title: String, value: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(neonBlue)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(secondaryText)
            }
            Text(value)
                .font(.title3.weight(.heavy))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 16, opacity: 0.2, shadow: 10, y: 6)
    }

    private func interpolatedDepth(at time: Double, samples: [DiveSample]) -> DiveSample? {
        guard let maxTime = samples.map(\.seconds).max() else { return nil }
        let clampedTime = min(max(time, 0), maxTime)
        guard let upperIndex = samples.firstIndex(where: { $0.seconds >= clampedTime }) else {
            return samples.last
        }
        if upperIndex == 0 { return samples.first }
        let lower = samples[upperIndex - 1]
        let upper = samples[upperIndex]
        let span = upper.seconds - lower.seconds
        let ratio = span > 0 ? (clampedTime - lower.seconds) / span : 0
        let depth = lower.depthMeters + (upper.depthMeters - lower.depthMeters) * ratio
        return DiveSample(seconds: clampedTime, depthMeters: depth)
    }

    private func interpolatedDepthPoint(for samples: [ChartPoint], at time: Double) -> ChartPoint? {
        guard let maxTime = samples.map(\.seconds).max() else { return nil }
        let clampedTime = min(max(time, 0), maxTime)
        guard let upperIndex = samples.firstIndex(where: { $0.seconds >= clampedTime }) else {
            return samples.last
        }
        if upperIndex == 0 { return samples.first }
        let lower = samples[upperIndex - 1]
        let upper = samples[upperIndex]
        let span = upper.seconds - lower.seconds
        let ratio = span > 0 ? (clampedTime - lower.seconds) / span : 0
        let depth = lower.depthMeters + (upper.depthMeters - lower.depthMeters) * ratio
        return ChartPoint(id: UUID(), seconds: clampedTime, depthMeters: depth, plotDepth: -depth)
    }

    private func interpolatedHeartRate(at time: Double, samples: [HeartRateSample]) -> HeartRateSample? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted { $0.seconds < $1.seconds }
        guard let minTime = sorted.first?.seconds, let maxTime = sorted.last?.seconds else { return sorted.last }

        let clampedTime = min(max(time, 0), maxTime)

        // Before the first sample: pin to clampedTime with first BPM
        if clampedTime <= minTime {
            return HeartRateSample(seconds: clampedTime, bpm: sorted.first!.bpm)
        }
        // After the last sample: pin to clampedTime with last BPM
        if clampedTime >= maxTime {
            return HeartRateSample(seconds: clampedTime, bpm: sorted.last!.bpm)
        }

        // Interpolate between surrounding samples
        guard let upperIndex = sorted.firstIndex(where: { $0.seconds >= clampedTime }) else {
            return HeartRateSample(seconds: clampedTime, bpm: sorted.last!.bpm)
        }
        let lower = sorted[upperIndex - 1]
        let upper = sorted[upperIndex]
        let span = upper.seconds - lower.seconds
        let ratio = span > 0 ? (clampedTime - lower.seconds) / span : 0
        let bpm = Int((Double(lower.bpm) + (Double(upper.bpm) - Double(lower.bpm)) * ratio).rounded())
        return HeartRateSample(seconds: clampedTime, bpm: bpm)
    }

    private func interpolatedWaterTemp(at time: Double, samples: [WaterTempSample]) -> WaterTempSample? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted { $0.seconds < $1.seconds }
        guard let minTime = sorted.first?.seconds, let maxTime = sorted.last?.seconds else { return sorted.last }

        let clampedTime = min(max(time, 0), maxTime)

        if clampedTime <= minTime { return WaterTempSample(seconds: clampedTime, celsius: sorted.first!.celsius) }
        if clampedTime >= maxTime { return WaterTempSample(seconds: clampedTime, celsius: sorted.last!.celsius) }

        guard let upperIndex = sorted.firstIndex(where: { $0.seconds >= clampedTime }) else {
            return WaterTempSample(seconds: clampedTime, celsius: sorted.last!.celsius)
        }
        let lower = sorted[upperIndex - 1]
        let upper = sorted[upperIndex]
        let span = upper.seconds - lower.seconds
        let ratio = span > 0 ? (clampedTime - lower.seconds) / span : 0
        let c = lower.celsius + (upper.celsius - lower.celsius) * ratio
        return WaterTempSample(seconds: clampedTime, celsius: c)
    }

    private func densify(samples: [HeartRateSample], step: Double) -> [HeartRateSample] {
        guard let maxTime = samples.map(\.seconds).max(), maxTime > 0 else { return samples }
        let sorted = samples.sorted { $0.seconds < $1.seconds }
        return stride(from: 0.0, through: maxTime, by: step).compactMap { t in
            interpolatedHeartRate(at: t, samples: sorted)
        }
    }

    private func densify(samples: [WaterTempSample], step: Double) -> [WaterTempSample] {
        guard let maxTime = samples.map(\.seconds).max(), maxTime > 0 else { return samples }
        let sorted = samples.sorted { $0.seconds < $1.seconds }
        return stride(from: 0.0, through: maxTime, by: step).compactMap { t in
            interpolatedWaterTemp(at: t, samples: sorted)
        }
    }

    private func densifyDepth(samples: [DiveSample], step: Double, duration: Double? = nil) -> [DiveSample] {
        guard let maxTime = samples.map(\.seconds).max(), maxTime > 0 else { return samples }
        let targetEnd = max(maxTime, duration ?? 0)
        var sorted = samples.sorted { $0.seconds < $1.seconds }
        if let last = sorted.last {
            if last.seconds < targetEnd {
                // Extend the last depth horizontally to the target end so the chart line doesn't cut off
                sorted.append(DiveSample(seconds: targetEnd, depthMeters: last.depthMeters))
            }
        } else if targetEnd > 0 {
            // If we have no samples, synthesize a flat line at 0 depth
            sorted = [DiveSample(seconds: 0, depthMeters: 0), DiveSample(seconds: targetEnd, depthMeters: 0)]
        }
        var out = stride(from: 0.0, through: targetEnd, by: step).compactMap { t in
            interpolatedDepth(at: t, samples: sorted)
        }
        // Ensure we have an exact sample at the end time (floating-point stride may miss it)
        if out.last?.seconds != targetEnd, let end = interpolatedDepth(at: targetEnd, samples: sorted) {
            out.append(end)
        }
        return out
    }

    private func padHeartRate(samples: [HeartRateSample], duration: Double) -> [HeartRateSample] {
        guard !samples.isEmpty else { return samples }
        var padded = samples.sorted { $0.seconds < $1.seconds }
        if let first = padded.first, first.seconds > 0 {
            padded.insert(HeartRateSample(seconds: 0, bpm: first.bpm), at: 0)
        }
        if let last = padded.last, last.seconds < duration {
            padded.append(HeartRateSample(seconds: duration, bpm: last.bpm))
        }
        return padded
    }

    private func tooltipOffset(seconds: Double, duration: Double) -> CGFloat {
        guard duration > 0 else { return 0 }
        let fraction = seconds / duration
        if fraction > 0.8 { return -8 }    // nudge left near right edge
        if fraction < 0.2 { return 8 }     // nudge right near left edge
        return 0                           // center otherwise
    }

    private func padWaterTemp(samples: [WaterTempSample], duration: Double) -> [WaterTempSample] {
        guard !samples.isEmpty else { return samples }
        var padded = samples.sorted { $0.seconds < $1.seconds }
        if let first = padded.first, first.seconds > 0 {
            padded.insert(WaterTempSample(seconds: 0, celsius: first.celsius), at: 0)
        }
        if let last = padded.last, last.seconds < duration {
            padded.append(WaterTempSample(seconds: duration, celsius: last.celsius))
        }
        return padded
    }

    @ViewBuilder
private func waterTempChart(_ dive: DiveSummary) -> some View {
    let samples = dive.waterTempSamples.sorted { $0.seconds < $1.seconds }

    if samples.count <= 1 {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Water temperature")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)
                Spacer()
            }
            Text("No water temp samples recorded for this dive.")
                .font(.footnote)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    } else {
        let minTemp = samples.map(\.celsius).min() ?? 0
        let maxTemp = samples.map(\.celsius).max() ?? 0
        let duration = max(samples.map(\.seconds).max() ?? 0, dive.durationSeconds)
        let padding = max(0.2, (maxTemp - minTemp) * 0.25)
        let yMin = max(0, minTemp - padding)
        let yMax = maxTemp + padding
        let range = max(0.1, yMax - yMin)
        let step: Double = range > 2.5 ? 0.5 : (range > 1.0 ? 0.25 : 0.1)
        let yTicks = Array(stride(from: yMin, through: yMax, by: step))
        let focusTime = min(hasSetScrub ? scrubTime : duration, duration)
        let selected = interpolatedWaterTemp(at: focusTime, samples: samples)
        let lineGradient = LinearGradient(colors: [.cyan.opacity(0.85), .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)

        let base = padWaterTemp(samples: samples, duration: duration)
        let smoothed = densify(samples: base, step: 2)

        let chartBody = Chart {
            ForEach(smoothed) { s in
                AreaMark(x: .value("Time", s.seconds), y: .value("Temp", s.celsius))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom))

                LineMark(x: .value("Time", s.seconds), y: .value("Temp", s.celsius))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(lineGradient)
            }

            if let selected {
                RuleMark(x: .value("Time", selected.seconds))
                    .foregroundStyle(.white.opacity(0.25))
                PointMark(x: .value("Time", selected.seconds), y: .value("Temp", selected.celsius))
                    .foregroundStyle(.white)
                    .symbolSize(80)
                    .annotation(position: .top, alignment: .center) {
                        VStack(spacing: 4) {
                            Text(formattedElapsed(selected.seconds)).font(.caption2.weight(.semibold)).foregroundStyle(.white)
                            Text(String(format: "%.1f C", selected.celsius)).font(.caption2).foregroundStyle(.cyan)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                        .offset(x: tooltipOffset(seconds: selected.seconds, duration: duration))
                    }
            }
        }
        .chartXScale(domain: 0...(duration > 0 ? duration : 1), range: .plotDimension(padding: 12))
        .chartYScale(domain: yMin...yMax)
        .chartPlotStyle { $0.padding(.top, 14).padding(.horizontal, 5).padding(.bottom, 10) }
        .chartXAxis {
            AxisMarks(values: timeTickValues(duration: duration)) { v in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisTick().foregroundStyle(Color.white.opacity(0.25))
                AxisValueLabel {
                    if let s = v.as(Double.self) { Text(formattedElapsed(s)).foregroundStyle(Color.white.opacity(0.7)) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { v in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisTick().foregroundStyle(Color.white.opacity(0.25))
                AxisValueLabel {
                    if let val = v.as(Double.self) { Text(String(format: "%.1f", val)).foregroundStyle(Color.white.opacity(0.7)) }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let anchor = proxy.plotFrame {
                    let frame = geo[anchor]
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - frame.minX
                                guard x >= 0, x <= frame.width, let t: Double = proxy.value(atX: x) else { return }
                                let clamped = max(0, min(t, duration))
                                scrubTime = clamped; selectedHeartTime = clamped; selectedDepthTime = clamped; hasSetScrub = true
                            }
                            .onEnded { _ in selectedHeartTime = scrubTime; selectedDepthTime = scrubTime })
                }
            }
        }

        // Card with built-in title (like Dive profile)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Water temperature")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "thermometer.medium").foregroundStyle(.white.opacity(0.7))
            }
            chartBody
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [midnight.opacity(0.92), Color.black.opacity(0.7)],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.1)],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing),
                                lineWidth: 1.1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: neonBlue.opacity(0.14), radius: 18, y: 10)
    }
}

    @ViewBuilder
private func heartRateChart(_ dive: DiveSummary) -> some View {
    let samples = dive.heartRateSamples.sorted { $0.seconds < $1.seconds }

    if samples.count <= 1 {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Heart rate")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)
                Spacer()
            }
            Text("No heart rate samples recorded for this dive.")
                .font(.footnote)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    } else {
        let maxBpm = max(samples.map(\.bpm).max() ?? 0, 60)
        let duration = max(samples.map(\.seconds).max() ?? 0, dive.durationSeconds)
        let yMaxScale = Double(((maxBpm + 10 + 5) / 10) * 10)
        let yTicks = Array(stride(from: 0.0, through: yMaxScale, by: 20.0))
        let focusTime = min(hasSetScrub ? scrubTime : duration, duration)
        let selected = interpolatedHeartRate(at: focusTime, samples: samples)

        let lineGradient = LinearGradient(colors: [.red.opacity(0.85), .pink.opacity(0.8)],
                                          startPoint: .leading, endPoint: .trailing)
        let padded = padHeartRate(samples: samples, duration: duration)
        let smoothed = densify(samples: padded, step: 2)

        let chartBody = Chart {
            ForEach(smoothed) { s in
                AreaMark(x: .value("Time", s.seconds), y: .value("BPM", s.bpm))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                                                    startPoint: .top, endPoint: .bottom))

                LineMark(x: .value("Time", s.seconds), y: .value("BPM", s.bpm))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(lineGradient)
            }

            if let selected {
                RuleMark(x: .value("Time", selected.seconds))
                    .foregroundStyle(.white.opacity(0.25))
                PointMark(x: .value("Time", selected.seconds), y: .value("BPM", selected.bpm))
                    .foregroundStyle(.white)
                    .symbolSize(80)
                    .annotation(position: .top, alignment: .center) {
                        VStack(spacing: 4) {
                            Text(formattedElapsed(selected.seconds)).font(.caption2.weight(.semibold)).foregroundStyle(.white)
                            Text("\(selected.bpm) bpm").font(.caption2).foregroundStyle(.red)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                        .offset(x: tooltipOffset(seconds: selected.seconds, duration: duration))
                    }
            }
        }
        .chartXScale(domain: 0...(duration > 0 ? duration : 1), range: .plotDimension(padding: 12))
        .chartYScale(domain: 0...yMaxScale)
        .chartPlotStyle { $0.padding(.top, 14).padding(.horizontal, 5).padding(.bottom, 10) }
        .chartXAxis {
            AxisMarks(values: timeTickValues(duration: duration)) { v in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisTick().foregroundStyle(Color.white.opacity(0.25))
                AxisValueLabel {
                    if let s = v.as(Double.self) { Text(formattedElapsed(s)).foregroundStyle(Color.white.opacity(0.7)) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { v in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisTick().foregroundStyle(Color.white.opacity(0.25))
                AxisValueLabel {
                    if let val = v.as(Double.self) { Text("\(Int(val))").foregroundStyle(Color.white.opacity(0.7)) }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let anchor = proxy.plotFrame {
                    let frame = geo[anchor]
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - frame.minX
                                guard x >= 0, x <= frame.width, let t: Double = proxy.value(atX: x) else { return }
                                let clamped = max(0, min(t, duration))
                                selectedHeartTime = clamped; scrubTime = clamped; hasSetScrub = true
                            }
                            .onEnded { _ in selectedHeartTime = scrubTime })
                }
            }
        }

        // Card with built-in title (like Dive profile)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Heart rate")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "heart.fill").foregroundStyle(.white.opacity(0.7))
            }
            chartBody
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [midnight.opacity(0.92), Color.black.opacity(0.7)],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.1)],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing),
                                lineWidth: 1.1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: neonBlue.opacity(0.14), radius: 18, y: 10)
    }
}


    #if os(iOS)
    private func captureAndShare(_ dive: DiveSummary) {
        guard let snapshot = snapshotDiveCard(dive) else { return }

        let activity = UIActivityViewController(activityItems: [snapshot], applicationActivities: nil)
        if let presenter = topViewController() {
            // On iPad, configure popover anchor if needed
            activity.popoverPresentationController?.sourceView = presenter.view
            activity.popoverPresentationController?.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
            presenter.present(activity, animated: true)
        }
    }

    private func snapshotDiveCard(_ dive: DiveSummary) -> UIImage? {
        let shareView = diveCard(dive,
                                 showShare: false,
                                 showMap: false,
                                 isExpanded: true,
                                 onToggle: nil)
            .padding(20)
            .background(glassBackdrop)

        let targetWidth = max(UIScreen.main.bounds.width - 40, 320)
        if #available(iOS 17.0, *) {
            let renderer = ImageRenderer(content: shareView.frame(maxWidth: targetWidth))
            renderer.proposedSize = .init(width: targetWidth, height: nil)
            renderer.scale = UIScreen.main.scale
            return renderer.uiImage
        } else {
            let controller = UIHostingController(rootView: shareView)
            let size = controller.sizeThatFits(in: CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
            controller.view.bounds = CGRect(origin: .zero, size: size)
            controller.view.backgroundColor = .clear

            // Attach to a temporary window tied to the current active scene so layout/rendering has full context
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else {
                return nil
            }

            let window = UIWindow(windowScene: scene)
            window.rootViewController = controller
            window.frame = CGRect(origin: .zero, size: size)
            window.isHidden = false
            window.layoutIfNeeded()
            controller.view.layoutIfNeeded()

            let format = UIGraphicsImageRendererFormat()
            format.scale = UIScreen.main.scale
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let image = renderer.image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }

            window.isHidden = true
            return image
        }
    }

    // Traverse to find the top-most presented view controller for presentation
    private func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
    #endif
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: Double
    let shadow: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(
                shape
                    .fill(Color.white.opacity(opacity))
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(
                        shape
                            .stroke(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.16)],
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing),
                                    lineWidth: 1.1)
                    )
            )
            .shadow(color: Color.cyan.opacity(shadow > 0 ? 0.16 : 0), radius: shadow, y: y)
            .shadow(color: Color.black.opacity(shadow > 0 ? 0.22 : 0), radius: shadow, y: y / 2)
    }
}

private struct GlassPillModifier: ViewModifier {
    let opacity: Double
    let shadow: CGFloat

    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)
        content
            .padding(.horizontal, 2)
            .background(
                shape
                    .fill(Color.white.opacity(opacity))
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(
                        shape
                            .stroke(LinearGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.2)],
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing),
                                    lineWidth: 1)
                    )
            )
            .shadow(color: Color.cyan.opacity(shadow > 0 ? 0.16 : 0), radius: shadow, y: shadow / 2)
            .shadow(color: Color.black.opacity(shadow > 0 ? 0.2 : 0), radius: shadow, y: shadow / 4)
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 18, opacity: Double = 0.18, shadow: CGFloat = 18, y: CGFloat = 8) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, opacity: opacity, shadow: shadow, y: y))
    }

    func glassPill(opacity: Double = 0.18, shadow: CGFloat = 6) -> some View {
        modifier(GlassPillModifier(opacity: opacity, shadow: shadow))
    }
}

#Preview {
    ContentView()
}
