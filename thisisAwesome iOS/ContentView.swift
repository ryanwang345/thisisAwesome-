import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var connectivity = PhoneConnectivityManager()
    private let primaryText = Color(red: 0.05, green: 0.08, blue: 0.15)
    private let secondaryText = Color(red: 0.30, green: 0.34, blue: 0.40)

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.78, green: 0.90, blue: 0.98)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    header

                    if let dive = connectivity.lastDive {
                        diveCard(dive)
                    } else {
                        waitingCard
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Dive Sync")
            .foregroundStyle(primaryText)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
        }
        .onAppear {
            connectivity.activate()
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

    private func diveCard(_ dive: DiveSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last dive")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                    Text(dive.endDate, style: .time)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(primaryText)
                }
                Spacer()
                Text(dive.depthText)
                    .font(.title.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(.blue)
            }

            HStack {
                stat(label: "Duration", value: dive.durationText)
                Spacer()
                stat(label: "Heart rate", value: dive.endingHeartRate.map { "\($0) bpm" } ?? "--")
                Spacer()
                stat(label: "Water temp", value: dive.waterTemperatureCelsius.map { String(format: "%.1f C", $0) } ?? "--")
            }

            diveProfileChart(dive)
            heartRateChart(dive)
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

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.headline)
                .foregroundStyle(primaryText)
                .monospacedDigit()
        }
    }

    private func diveProfileChart(_ dive: DiveSummary) -> some View {
        let baseSamples = profilePoints(for: dive)
        let chartPoints = baseSamples.map { ChartPoint(id: $0.id, seconds: $0.seconds, depthMeters: $0.depthMeters, plotDepth: -$0.depthMeters) }
        let maxDepth = max(chartPoints.map { $0.depthMeters }.max() ?? 0, dive.maxDepthMeters)
        let duration = max(chartPoints.map { $0.seconds }.max() ?? 0, dive.durationSeconds)
        let cardBackground = Color(red: 0.09, green: 0.10, blue: 0.15)
        let border = Color.white.opacity(0.08)
        let lineGradient = LinearGradient(colors: [.cyan, .green, .yellow, .orange], startPoint: .leading, endPoint: .trailing)
        let fillGradient = LinearGradient(colors: [Color.cyan.opacity(0.32), Color.blue.opacity(0.12)], startPoint: .top, endPoint: .bottom)
        let xStride = duration > 900 ? 300 : (duration > 480 ? 120 : 60)
        let yDomain = (-(maxDepth + 2))...0

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
                Chart {
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
                }
                .chartXScale(domain: 0...(duration > 0 ? duration : 1))
                .chartYScale(domain: yDomain)
                .chartXAxis {
                    // Provide explicit numeric tick positions to avoid Calendar.Component overload
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
            let yMaxScale = max(yMax, 20)
            let yTicks = stride(from: 0.0, through: yMaxScale, by: 20.0).map { $0 }
            let minSample = samples.min(by: { $0.bpm < $1.bpm })
            let maxSample = samples.max(by: { $0.bpm < $1.bpm })
            let lastSample = samples.last
            let lowBpm = minSample?.bpm ?? 0

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Heart rate")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Spacer()
                    capsuleStat(label: "Avg", value: "\(Int(avgBpm.rounded())) bpm", color: Color.orange)
                }

                Chart {
                    ForEach(samples) { sample in
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
                                 .padding(.horizontal, 6)
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
                }
                .chartXScale(domain: 0...(duration > 0 ? duration : 1))
                .chartYScale(domain: 0...yMaxScale)
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
                .frame(height: 200)
            }
            .padding(.top, 6)
        }
    }
}

#Preview {
    ContentView()
}
