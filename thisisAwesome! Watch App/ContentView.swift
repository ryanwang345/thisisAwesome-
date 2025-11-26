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
    private let autoStartDepthThreshold: Double = 0.0  // meters

    @StateObject private var heartRateManager = HeartRateManager()
    @StateObject private var waterManager = WaterSubmersionManager()
    @StateObject private var compassManager = CompassManager()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color.blue.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    // Header
                    VStack(spacing: 1) {
                        Text("Freedive")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                        Text(phase.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if waterManager.errorDescription != nil || compassManager.errorDescription != nil {
                        VStack(spacing: 4) {
                            if let error = waterManager.errorDescription {
                                Text(error)
                            }
                            if let compassError = compassManager.errorDescription {
                                Text(compassError)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .multilineTextAlignment(.center)
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Depth + goal
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f m", currentDepth))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text("GOAL \(String(format: "%.1f", diveGoal)) m")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }

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
                                            .frame(width: 26, height: 26)
                                            .background(Color.white.opacity(0.18))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    Button { changeDepth(by: 1) } label: {
                                        Image(systemName: "plus")
                                            .font(.caption)
                                            .frame(width: 26, height: 26)
                                            .background(Color.white.opacity(0.18))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
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
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 10)
            }
        }
        .onAppear {
            waterManager.start()
            compassManager.start()
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
        VStack(alignment: alignment, spacing: 3) {
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

    // MARK: - Logic

    private func startDive(initialDepth: Double? = nil) {
        isDiving = true
        phase = .diving
        diveTime = 0
        diveStartDate = Date()

        let startingDepth = max(0, initialDepth ?? 0)
        currentDepth = startingDepth
        maxDepth = startingDepth

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            diveTime += 1
        }

        heartRateManager.start()
    }

    private func stopDive() {
        isDiving = false
        phase = .surface
        let endDate = Date()

        timer?.invalidate()
        timer = nil

        heartRateManager.stop()
        if let startDate = diveStartDate {
            heartRateManager.saveDiveResult(startDate: startDate,
                                            endDate: endDate,
                                            maxDepthMeters: maxDepth)
        }
        diveStartDate = nil
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
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}

// MARK: - Compass Dial

private struct CompassDial: View {
    let heading: Double?
    let direction: String?

    private var displayHeading: String {
        guard let heading else { return "--" }
        return String(format: "%.0f°", heading)
    }

    private var displayDirection: String {
        direction ?? "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Heading")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(displayDirection) \(displayHeading)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            GeometryReader { geo in
                let width = geo.size.width
                let needleX = normalizedOffset(width: width)
                let sweepWidth = max(width * 0.18, width * 0.24)

                VStack(spacing: 4) {
                    ZStack(alignment: .leading) {
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
                            .frame(height: 12)

                        // Tick marks every 30 degrees
                        ForEach(0..<13) { index in
                            let x = width * CGFloat(index) / 12
                            Rectangle()
                                .fill(Color.white.opacity(index % 2 == 0 ? 0.7 : 0.35))
                                .frame(width: 1, height: index % 2 == 0 ? 12 : 8)
                                .offset(x: x - 0.5)
                        }

                        // Gradient fill representing heading sweep, centered on the needle
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.orange.opacity(0.95), .red.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: sweepWidth, height: 8)
                            .offset(x: needleX - sweepWidth / 2)
                            .animation(.easeOut(duration: 0.2), value: heading)

                        // Needle
                        Triangle()
                            .fill(.orange)
                            .frame(width: 8, height: 16)
                            .offset(x: needleX - 4, y: -2)
                            .opacity(heading == nil ? 0.3 : 1)
                    }
                    .frame(height: 18)

                    HStack {
                        ForEach(cardinalMarkers, id: \.label) { marker in
                            Spacer()
                            Text(marker.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(marker.label == displayDirection ? .orange : .white.opacity(0.8))
                            Spacer()
                        }
                    }
                }
            }
            .frame(height: 46)
        }
    }

    private func normalizedOffset(width: CGFloat) -> CGFloat {
        guard let heading else { return width / 2 }
        let ratio = CGFloat((heading.truncatingRemainder(dividingBy: 360)) / 360.0)
        return ratio * width
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
