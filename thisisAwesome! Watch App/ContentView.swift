//
//  ContentView.swift
//  FreeDiving Computer Watch App
//
//  Created by Ryan Wang on 11/21/25.
//

import SwiftUI
import WatchKit

// MARK: - Dive State

enum DivePhase: String {
    case surface = "Surface"
    case diving  = "Dive"
}

struct ContentView: View {
    @State private var isDiving: Bool = false
    @State private var diveTime: TimeInterval = 0
    @State private var currentDepth: Double = 0
    @State private var maxDepth: Double = 0
    @State private var diveGoal: Double = 0
    @State private var phase: DivePhase = .surface
    @State private var timer: Timer?
    @State private var diveStartDate: Date?
    @State private var profileSamples: [DiveSample] = []
    @State private var lastSampleTime: TimeInterval = 0
    @State private var heartRateSamples: [HeartRateSample] = []
    @State private var lastHeartSampleTime: TimeInterval = 0
    private let autoStartDepthThreshold: Double = 0.0  // meters
    private let sampleInterval: TimeInterval = 1.5
    private let heartRateSampleInterval: TimeInterval = 5.0

    @StateObject private var heartRateManager = HeartRateManager()
    @StateObject private var waterManager = ActiveWaterSubmersionManager()
    @StateObject private var compassManager = CompassManager()
    @StateObject private var syncManager = DiveSyncManager()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color.blue.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 5) {
                // Depth + goal (kept outside ScrollView so it stays fixed)
                VStack(spacing: 1) {
                    Text(String(format: "%.1f m", currentDepth))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("GOAL \(String(format: "%.1f", diveGoal)) m")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }

                ScrollView {
                    VStack(spacing: 10) {
                        // Header
                        VStack(spacing: 1) {
                            Text(phase.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }

//                    if waterManager.errorDescription != nil || compassManager.errorDescription != nil {
//                        VStack(spacing: 4) {
//                            if let error = waterManager.errorDescription {
//                                Text(error)
//                            }
//                            if let compassError = compassManager.errorDescription {
//                                Text(compassError)
//                            }
//                        }
//                        .font(.caption2)
//                        .foregroundStyle(.yellow)
//                        .multilineTextAlignment(.center)
//                        .padding(6)
//                        .frame(maxWidth: .infinity)
//                        .background(Color.black.opacity(0.35))
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                    }

                        // Unified info card (content drives the height; rounded rect sits behind)
                        VStack(spacing: 12) {
                            HStack {
                                statBlock(title: "Heart rate",
                                          value: heartRateManager.heartRate > 0 ? "\(heartRateManager.heartRate) bpm" : "-- bpm",
                                          alignment: .center,
                                          valueFont: .title3)
                                Divider()
                                    .background(Color.white.opacity(0.15))
                                    .padding(.vertical, 6)
                                statBlock(title: "Water temp",
                                          value: waterManager.waterTemperatureCelsius.map { String(format: "%.1f C", $0) } ?? "-- C",
                                          alignment: .center,
                                          valueFont: .title3)
                            }

                            CompassDial(
                                heading: compassManager.headingDegrees,
                                direction: compassManager.headingDirection
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .center, spacing: 10) {
                                    statBlock(title: "Dive Time", value: formattedTime(diveTime), valueFont: .body)
                                    Divider()
                                        .background(Color.white.opacity(0.15))
                                        .frame(height: 26)
                                    statBlock(title: "Depth", value: String(format: "%.1f m", currentDepth), alignment: .center, valueFont: .body)
                                    Spacer()
                                }

                                HStack(spacing: 10) {
                                    Text("Goal")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Button { changeDepth(by: -1) } label: {
                                            Image(systemName: "minus")
                                                .font(.caption)
                                        }
                                        .buttonStyle(GoalStepButtonStyle())
                                        Button { changeDepth(by: 1) } label: {
                                            Image(systemName: "plus")
                                                .font(.caption)
                                        }
                                        .buttonStyle(GoalStepButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                        // Start / Stop button
                        Button(action: { isDiving ? stopDive() : startDive() }) {
                            Text(isDiving ? "End Dive" : "Start Dive")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isDiving ? .red : .green)

                        if let sent = syncManager.lastSentSummary {
                            VStack(spacing: 2) {
                                Text("Sent to iPhone")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text(sent.endDate, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                        } else if let error = syncManager.lastErrorMessage {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
            .padding(.top, -40)
//         .safeAreaInset(edge: .top) {
//             Color.clear.frame(height: 2)
//         }
        }
        .onAppear {
            waterManager.start()
            compassManager.start()
            syncManager.activate()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            heartRateManager.stop()
            waterManager.stop()
            compassManager.stop()
        }
        .onReceive(waterManager.$depthMeters) { depth in
            handleDepthChange(to: depth)
        }
        .onReceive(waterManager.$isSubmerged) { submerged in
            if submerged, !isDiving {
                startDive(initialDepth: max(currentDepth, waterManager.depthMeters))
            } else if !submerged, isDiving {
                stopDive()
            }
        }
        .onReceive(heartRateManager.$heartRate) { bpm in
            recordHeartRateSample(bpm: bpm)
        }
    }

    // MARK: - Helpers

    private func banner(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.yellow)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6)
    }

    private func statBlock(title: String, value: String, alignment: HorizontalAlignment = .leading, valueFont: Font.TextStyle = .title3) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(valueFont, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private struct GoalStepButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(configuration.isPressed ? 0.55 : 0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(configuration.isPressed ? 0.8 : 0.45), lineWidth: 1.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }

    // MARK: - Logic

    private func startDive(initialDepth: Double? = nil) {
        isDiving = true
        phase = .diving
        diveTime = 0
        let startDate = Date()
        diveStartDate = startDate

        let startingDepth = max(0, initialDepth ?? 0)
        currentDepth = startingDepth
        maxDepth = startingDepth
        profileSamples = [DiveSample(seconds: 0, depthMeters: startingDepth)]
        lastSampleTime = 0
        heartRateSamples = []
        lastHeartSampleTime = 0

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            diveTime += 1
        }

        heartRateManager.start()
    }

    private func stopDive() {
        if diveStartDate != nil {
            recordDepthSample(depth: currentDepth, force: true)
        }
        isDiving = false
        phase = .surface
        let endDate = Date()

        timer?.invalidate()
        timer = nil

        if let startDate = diveStartDate {
            let summary = DiveSummary(startDate: startDate,
                                      endDate: endDate,
                                      maxDepthMeters: maxDepth,
                                      durationSeconds: diveTime,
                                      endingHeartRate: heartRateManager.heartRate > 0 ? heartRateManager.heartRate : nil,
                                      waterTemperatureCelsius: waterManager.waterTemperatureCelsius,
                                      profile: profileSamples,
                                      heartRateSamples: heartRateSamples)
            syncManager.send(summary)

            heartRateManager.completeDive(startDate: startDate,
                                          endDate: endDate,
                                          maxDepthMeters: maxDepth)
        } else {
            heartRateManager.stop()
        }
        diveStartDate = nil
        profileSamples = []
        lastSampleTime = 0
        heartRateSamples = []
        lastHeartSampleTime = 0
    }

    private func changeDepth(by delta: Double) {
        diveGoal = max(0, diveGoal + delta)
    }

    private func handleDepthChange(to depth: Double) {
        if !isDiving {
            currentDepth = depth
            // Auto-start when we detect the watch has gone under water (depth above threshold)
            if depth > autoStartDepthThreshold {
                startDive(initialDepth: depth)
            }
            return
        }

        currentDepth = depth
        if currentDepth > maxDepth {
            maxDepth = currentDepth
            WKInterfaceDevice.current().play(.success) // Haptic when a new max depth is reached
        }
        recordDepthSample(depth: depth)
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func recordDepthSample(depth: Double, force: Bool = false) {
        guard let start = diveStartDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        let clampedDepth = max(0, depth)
        let lastDepth = profileSamples.last?.depthMeters ?? clampedDepth

        if force
            || profileSamples.isEmpty
            || elapsed - lastSampleTime >= sampleInterval
            || abs(clampedDepth - lastDepth) >= 0.4 {
            profileSamples.append(DiveSample(seconds: elapsed, depthMeters: clampedDepth))
            lastSampleTime = elapsed
        }
    }

    private func recordHeartRateSample(bpm: Int) {
        guard isDiving, bpm > 0, let start = diveStartDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        let lastBpm = heartRateSamples.last?.bpm ?? bpm

        if heartRateSamples.isEmpty
            || elapsed - lastHeartSampleTime >= heartRateSampleInterval
            || abs(lastBpm - bpm) >= 3 {
            heartRateSamples.append(HeartRateSample(seconds: elapsed, bpm: bpm))
            lastHeartSampleTime = elapsed
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - Compass Dial

private struct CompassDial: View {
    let heading: Double?
    let direction: String?

    @State private var accumulatedHeading: Double = 0
    @State private var lastHeading: Double?

    private var displayHeading: String {
        guard let heading else { return "--" }
        return String(format: "%.0f°", heading)
    }

    private var displayDirection: String {
        direction ?? "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .center) {
//                HStack {
//                    Text("Heading")
//                        .font(.caption2.weight(.medium))
//                        .foregroundStyle(.white.opacity(0.8))
//                    Spacer()
//                    Spacer()
//                    Spacer()
//                }.frame(height: 30)

                HStack(spacing: 10) {
                    Text(displayDirection)
                        .font(.caption.weight(.bold))
                    Text(displayHeading)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26, alignment: .center)

            GeometryReader { geo in
                let inset: CGFloat = 18
                let width = max(geo.size.width - inset * 2, 0)
                // Center the scale under the arrow: shift so current heading sits at x = 0
                let rawOffset = (width / 2) - (CGFloat(accumulatedHeading) / 360.0 * width)
                let tileRadius = 10
                let edgeMask = LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .white, location: 0.08),
                        .init(color: .white, location: 0.92),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                VStack(spacing: 21) {
                    // Tile the scale so it scrolls infinitely while the arrow stays centered
                    ZStack {
                        ForEach(-tileRadius...tileRadius, id: \.self) { idx in
                            scaleBar(width: width)
                                .offset(x: rawOffset + CGFloat(idx) * width)
                        }
                    }
                    .frame(width: width, height: 18, alignment: .center)
                    .mask(edgeMask.frame(width: width, height: 18))
                    .overlay(alignment: .center) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.85), .red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: min(width * 0.25, 56), height: 10)
                            .shadow(color: .orange.opacity(0.35), radius: 3, y: 1)
                    }
                    .animation(.linear(duration: 0.15), value: accumulatedHeading)
                    .overlay(
                        Triangle()
                            .fill(.yellow)
                            .frame(width: 12, height: 22)
                            .offset(y: -4)
                            .opacity(heading == nil ? 0.3 : 1)
                    )

                    ZStack {
                        ForEach(-tileRadius...tileRadius, id: \.self) { idx in
                            cardinalRow(width: width)
                                .offset(x: rawOffset + CGFloat(idx) * width)
                        }
                    }
                    .frame(width: width, alignment: .center)
                    .mask(edgeMask.frame(width: width, height: 16))
                    .overlay(alignment: .center) {
                        Text(displayDirection)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                            .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
                            .offset(y: -18)
                    }
                    .animation(.linear(duration: 0.15), value: accumulatedHeading)
                }
                .frame(width: width)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: 46)
        }
        .onAppear { updateAccumulatedHeading(with: heading) }
        .onChange(of: heading) { _, newHeading in
            updateAccumulatedHeading(with: newHeading)
        }
    }

    private func updateAccumulatedHeading(with newHeading: Double?) {
        guard let newHeading else { return }
        if let lastHeading {
            var delta = newHeading - lastHeading
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            accumulatedHeading += delta
        } else {
            accumulatedHeading = newHeading
        }
        lastHeading = newHeading
    }

    @ViewBuilder
    private func scaleBar(width: CGFloat) -> some View {
        ZStack(alignment: .center) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 12)

            ForEach(0..<13) { index in
                let x = width * CGFloat(index) / 12 - width / 2
                Rectangle()
                    .fill(Color.white.opacity(index % 2 == 0 ? 0.7 : 0.35))
                    .frame(width: 1, height: index % 2 == 0 ? 12 : 8)
                    .offset(x: x)
            }
        }
    }

    @ViewBuilder
    private func cardinalRow(width: CGFloat) -> some View {
        ZStack(alignment: .center) {
            ForEach(cardinalMarkers, id: \.label) { marker in
                let x = width * CGFloat(marker.degrees / 360.0) - width / 2
                Text(marker.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(marker.label == displayDirection ? .orange : .white.opacity(0.8))
                    .offset(x: x)
            }
        }
        .frame(width: width, height: 16)
    }

    private var cardinalMarkers: [(label: String, degrees: Double)] {
        [
            ("N", 0),
            ("E", 90),
            ("S", 180),
            ("W", 270)
        ]
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let w = rect.width
            let h = rect.height
            path.move(to: CGPoint(x: w / 2, y: 0))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
            return path
        }
    }
}
