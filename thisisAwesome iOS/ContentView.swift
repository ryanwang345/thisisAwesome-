import SwiftUI
import Charts
import UIKit

struct ContentView: View {
    @StateObject private var connectivity = PhoneConnectivityManager()
    private let primaryText = Color(red: 0.05, green: 0.08, blue: 0.15)
    private let secondaryText = Color(red: 0.30, green: 0.34, blue: 0.40)
    @State private var selectedDepthTime: Double?
    @State private var selectedHeartTime: Double?
    @State private var scrubTime: Double = 0
    @State private var hasSetScrub: Bool = false
    @State private var expandedDives: Set<UUID> = []

    private func toggleExpansion(for dive: DiveSummary) {
        if expandedDives.contains(dive.id) {
            expandedDives.remove(dive.id)
        } else {
            expandedDives.insert(dive.id)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.78, green: 0.90, blue: 0.98)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        header

                        let uniqueDives = Dictionary(grouping: connectivity.diveHistory) { $0.id }
                            .compactMap { $0.value.first }
                            .sorted { $0.endDate > $1.endDate }

                        if let latest = uniqueDives.first ?? connectivity.lastDive {
                            let expanded = expandedDives.contains(latest.id)
                            diveCard(latest,
                                     showShare: true,
                                     isExpanded: expanded,
                                     onToggle: { toggleExpansion(for: latest) })
                        } else {
                            waitingCard
                        }

                        if uniqueDives.count > 1 {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Previous dives")
                                    .font(.headline)
                                    .foregroundStyle(primaryText)

                                ForEach(uniqueDives.dropFirst()) { dive in
                                    let expanded = expandedDives.contains(dive.id)
                                    diveCard(dive,
                                             showShare: true,
                                             isExpanded: expanded,
                                             onToggle: { toggleExpansion(for: dive) })
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Dive Sync")
            .navigationBarTitleDisplayMode(.inline)
            .foregroundStyle(primaryText)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
        }
        .onAppear { connectivity.activate() }
        .onChange(of: connectivity.diveHistory.first?.id) { _, _ in
            if let latest = connectivity.diveHistory.sorted(by: { $0.endDate > $1.endDate }).first {
                scrubTime = defaultScrubTime(for: latest)
                hasSetScrub = false
                expandedDives.insert(latest.id)
            } else {
                resetScrubber()
            }
        }
        .onChange(of: scrubTime) { _, newValue in
            selectedDepthTime = newValue
            selectedHeartTime = newValue
        }
        .preferredColorScheme(.light) // ensure text stays dark on light gradient
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(connectivity.isReachable ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
            Text(connectivity.isReachable ? "Connected to watch" : connectivity.statusMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(primaryText)
            Spacer()
        }
    }

    private var waitingCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi")
                .font(.largeTitle)
                .foregroundStyle(Color.blue)
            Text("Finish a dive on your Apple Watch to sync the summary here.")
                .font(.headline)
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private func diveCard(_ dive: DiveSummary, showShare: Bool = true, isExpanded: Bool = true, onToggle: (() -> Void)? = nil) -> some View {
        let profileSamples = profilePoints(for: dive)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last dive")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                    Text(dive.endDate, style: .time)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(primaryText)
                }
                Spacer()
                HStack(spacing: 10) {
                    Text(dive.depthText)
                        .font(.title.weight(.heavy))
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                    if showShare {
                        Button {
                            captureAndShare(dive)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                        }
                        .foregroundStyle(primaryText)
                        .accessibilityLabel("Share dive")
                    }
                    if let onToggle {
                        Button(action: onToggle) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(primaryText)
                    }
                }
            }

            HStack {
                stat(label: "Duration", value: dive.durationText)
                Spacer()
                stat(label: "Avg. Heart Rate", value: averageHeartRateText(for: dive))
                Spacer()
                stat(label: "Water Temp", value: dive.waterTemperatureCelsius.map { String(format: "%.1f C", $0) } ?? "--", color: .white)
            }

            if isExpanded {
                intervalScrubber(for: dive, samples: profileSamples)
                diveProfileChart(dive, samples: profileSamples)
                waterTempChart(dive)
                heartRateChart(dive)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
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
                    .foregroundStyle(.blue)
                    .monospacedDigit()
                Text("\(dive.durationText) • \(averageHeartRateText(for: dive))")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
    
    private func averageHeartRateText(for dive: DiveSummary) -> String {
        guard !dive.heartRateSamples.isEmpty else { return "--" }
        let total = dive.heartRateSamples.reduce(0) { $0 + $1.bpm }
        let avg = Double(total) / Double(dive.heartRateSamples.count)
        return "\(Int(avg.rounded())) bpm"
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
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
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
                    .background(secondaryText.opacity(0.16))

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
                    .background(secondaryText.opacity(0.16))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Water temp")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(secondaryText)
                    Text(waterSample.map { String(format: "%.1f C", $0.celsius) } ?? "--")
                        .font(.headline)
                        .foregroundStyle(primaryText)
                        .monospacedDigit()
                }

//                Spacer()
//                Text("@ \(formattedElapsed(activeTime))")
//                    .font(.caption2.weight(.bold))
//                    .foregroundStyle(.blue)
//                    .padding(.horizontal, 10)
//                    .padding(.vertical, 6)
//                    .background(Color.blue.opacity(0.12))
//                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color(red: 0.96, green: 0.98, blue: 1.0))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(Color.blue.opacity(0.35))
                        .frame(width: x + thumbSize * 0.5, height: trackHeight)

                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                        .overlay {
                            Circle()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
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
        let smoothedSamples = densifyDepth(samples: samples, step: 5)
        let chartPoints = smoothedSamples.map { ChartPoint(id: $0.id, seconds: $0.seconds, depthMeters: $0.depthMeters, plotDepth: -$0.depthMeters) }
        let maxDepth = max(chartPoints.map { $0.depthMeters }.max() ?? 0, dive.maxDepthMeters)
        let duration = max(chartPoints.map { $0.seconds }.max() ?? 0, dive.durationSeconds)
        let focusTime = min(hasSetScrub ? scrubTime : duration, duration)
        let selected = interpolatedDepthPoint(for: chartPoints, at: focusTime)
        let cardBackground = Color(red: 0.09, green: 0.10, blue: 0.15)
        let border = Color.white.opacity(0.08)
        let lineGradient = LinearGradient(colors: [.cyan, .green, .yellow, .orange], startPoint: .leading, endPoint: .trailing)
        let fillGradient = LinearGradient(colors: [Color.cyan.opacity(0.32), Color.blue.opacity(0.12)], startPoint: .top, endPoint: .bottom)
        let xStride = duration > 900 ? 300 : (duration > 480 ? 120 : 60)
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
                        Text(String(format: "%.1f m", selected.depthMeters))
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
        .chartXScale(domain: 0...(duration > 0 ? duration : 1),
                     range: .plotDimension(padding: 0))
        .chartYScale(domain: yDomain)
        .chartXAxis {
            let tickValues: [Double] = Array(stride(from: 0.0, through: max(duration, 1.0), by: Double(xStride)))
            AxisMarks(values: tickValues) { value in
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
                        Text(String(format: "%.0f m", abs(depth)))
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
                                    selectedDepthTime = time
                                    scrubTime = time
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
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
        let minutes = Int(seconds) / 60
        let remainder = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainder)
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
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white)
        .overlay(
            Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private struct ChartPoint: Identifiable {
        let id: UUID
        let seconds: Double
        let depthMeters: Double
        let plotDepth: Double
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
        guard let maxTime = samples.map(\.seconds).max() else { return samples.last }
        let clampedTime = min(max(time, 0), maxTime)
        guard let upperIndex = samples.firstIndex(where: { $0.seconds >= clampedTime }) else {
            return samples.last
        }
        if upperIndex == 0 { return samples.first }
        let lower = samples[upperIndex - 1]
        let upper = samples[upperIndex]
        let span = upper.seconds - lower.seconds
        let ratio = span > 0 ? (clampedTime - lower.seconds) / span : 0
        let bpm = Int((Double(lower.bpm) + (Double(upper.bpm) - Double(lower.bpm)) * ratio).rounded())
        return HeartRateSample(seconds: clampedTime, bpm: bpm)
    }

    private func interpolatedWaterTemp(at time: Double, samples: [WaterTempSample]) -> WaterTempSample? {
        guard let maxTime = samples.map(\.seconds).max() else { return samples.last }
        let clampedTime = min(max(time, 0), maxTime)
        guard let upperIndex = samples.firstIndex(where: { $0.seconds >= clampedTime }) else {
            return samples.last
        }
        if upperIndex == 0 { return samples.first }
        let lower = samples[upperIndex - 1]
        let upper = samples[upperIndex]
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

    private func densifyDepth(samples: [DiveSample], step: Double) -> [DiveSample] {
        guard let maxTime = samples.map(\.seconds).max(), maxTime > 0 else { return samples }
        let sorted = samples.sorted { $0.seconds < $1.seconds }
        return stride(from: 0.0, through: maxTime, by: step).compactMap { t in
            interpolatedDepth(at: t, samples: sorted)
        }
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
            let yTicks = stride(from: yMin, through: yMax, by: step).map { $0 }
            let xStride = duration > 300 ? 60.0 : 30.0
            let focusTime = min(hasSetScrub ? scrubTime : duration, duration)
            let selected = interpolatedWaterTemp(at: focusTime, samples: samples)
            let lineGradient = LinearGradient(colors: [.cyan.opacity(0.85), .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)

            let paddedSamples = padWaterTemp(samples: samples, duration: duration)
            let smoothedSamples = densify(samples: paddedSamples, step: 5)

            let chartBody = Chart {
                ForEach(smoothedSamples) { sample in
                    AreaMark(
                        x: .value("Time", sample.seconds),
                        y: .value("Temp", sample.celsius)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02)
                        ], startPoint: .top, endPoint: .bottom)
                    )

                    LineMark(
                        x: .value("Time", sample.seconds),
                        y: .value("Temp", sample.celsius)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(lineGradient)
                }

                if let selected {
                    RuleMark(x: .value("Time", selected.seconds))
                        .foregroundStyle(.white.opacity(0.25))
                    PointMark(
                        x: .value("Time", selected.seconds),
                        y: .value("Temp", selected.celsius)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(80)
                    .annotation(position: .top, alignment: .center) {
                        VStack(spacing: 4) {
                            Text(formattedElapsed(selected.seconds))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(String(format: "%.1f C", selected.celsius))
                                .font(.caption2)
                                .foregroundStyle(.cyan)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                        .offset(x: tooltipOffset(seconds: selected.seconds, duration: duration))
                    }
                }
            }
            .chartXScale(domain: 0...(duration > 0 ? duration : 1),
                         range: .plotDimension(padding: 0))
            .chartYScale(domain: yMin...yMax)
            .chartPlotStyle { plotArea in
                plotArea
                    .padding(.top, 14)
                    .padding(.horizontal, 5)
                    .padding(.bottom, 10)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xStride)) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    AxisTick().foregroundStyle(Color.white.opacity(0.25))
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(formattedElapsed(seconds))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yTicks) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    AxisTick().foregroundStyle(Color.white.opacity(0.25))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.1f", v))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                }
            }
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
                                        scrubTime = time
                                        selectedHeartTime = time
                                        selectedDepthTime = time
                                        hasSetScrub = true
                                    }
                                    .onEnded { _ in
                                        selectedHeartTime = scrubTime
                                        selectedDepthTime = scrubTime
                                    }
                            )
                    } else {
                        Color.clear
                    }
                }
            }
            .frame(height: 170)
            .padding(12)
            .background(
                LinearGradient(colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.18),
                    Color(red: 0.12, green: 0.16, blue: 0.24)
                ], startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Water temperature")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                chartBody
            }
            .padding(.top, 6)
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
            let avgBpm = Double(samples.map(\.bpm).reduce(0, +)) / Double(samples.count)
            let gradient = LinearGradient(colors: [.red.opacity(0.8), .pink.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
            let xStride = duration > 300 ? 60.0 : 30.0
            let yMax = Double(maxBpm) + 10
            let yMaxScale = max(yMax, 20) + 10 // extra headroom so annotations don't collide with the top edge
            let yTicks = stride(from: 0.0, through: yMaxScale, by: 20.0).map { $0 }
            let minSample = samples.min(by: { $0.bpm < $1.bpm })
            let maxSample = samples.max(by: { $0.bpm < $1.bpm })
            let lastSample = samples.last
            let focusTime = min(hasSetScrub ? scrubTime : duration, duration)
            let selected = interpolatedHeartRate(at: focusTime, samples: samples)

            let paddedSamples = padHeartRate(samples: samples, duration: duration)
            let smoothedSamples = densify(samples: paddedSamples, step: 5)

            let chartBody = Chart {
                ForEach(smoothedSamples) { sample in
                    AreaMark(
                        x: .value("Time", sample.seconds),
                        y: .value("BPM", sample.bpm)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(gradient.opacity(0.25))

                    LineMark(
                        x: .value("Time", sample.seconds),
                        y: .value("BPM", sample.bpm)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(gradient)
                }

                if let minSample {
                    PointMark(
                        x: .value("Time", minSample.seconds),
                        y: .value("BPM", minSample.bpm)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(60)
                    .annotation(position: .topLeading, alignment: .leading) {
                        Text("Low \(minSample.bpm)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 0)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                if let maxSample {
                    PointMark(
                        x: .value("Time", maxSample.seconds),
                        y: .value("BPM", maxSample.bpm)
                    )
                    .foregroundStyle(.orange)
                    .symbolSize(60)
                    .annotation(position: .topLeading, alignment: .leading) {
                        Text("High \(maxSample.bpm)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                if let lastSample {
                    PointMark(
                        x: .value("Time", lastSample.seconds),
                        y: .value("BPM", lastSample.bpm)
                    )
                    .foregroundStyle(.red)
                    .symbolSize(70)
                    .annotation(position: .bottom, alignment: .trailing) {
                        Text("Last \(lastSample.bpm)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                if let selected {
                    RuleMark(x: .value("Time", selected.seconds))
                        .foregroundStyle(.red.opacity(0.35))
                    PointMark(
                        x: .value("Time", selected.seconds),
                        y: .value("BPM", selected.bpm)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(80)
                    .annotation(position: .top, alignment: .center) {
                        VStack(spacing: 4) {
                            Text(formattedElapsed(selected.seconds))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(primaryText)
                            Text("\(selected.bpm) bpm")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        .offset(x: -6)
                    }
                }
            }
            .chartXScale(domain: 0...(duration > 0 ? duration : 1),
                         range: .plotDimension(padding: 0))
            .chartYScale(domain: 0...yMaxScale)
            .chartPlotStyle { plotArea in
                plotArea
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xStride)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(formattedElapsed(seconds))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yTicks) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
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
                                        selectedHeartTime = time
                                        scrubTime = time
                                        hasSetScrub = true
                                    }
                                    .onEnded { _ in
                                        selectedHeartTime = scrubTime
                                    }
                            )
                    } else {
                        Color.clear
                    }
                }
            }
            .frame(height: 200)
            .background(
                LinearGradient(colors: [
                    Color(red: 1.0, green: 0.98, blue: 0.99),
                    Color(red: 1.0, green: 0.96, blue: 0.98)
                ], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Heart rate")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Spacer()
                    capsuleStat(label: "Avg", value: "\(Int(avgBpm.rounded())) bpm", color: Color.orange)
                }
                chartBody
            }
            .padding(.top, 10)
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
                                 isExpanded: true,
                                 onToggle: nil)
            .padding(20)
            .background(
                LinearGradient(colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.78, green: 0.90, blue: 0.98)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
            )

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

#Preview {
    ContentView()
}
