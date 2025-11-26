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
    private let autoStartDepthThreshold: Double = 0.0  // meters

    @StateObject private var heartRateManager = HeartRateManager()
    @StateObject private var waterManager = WaterSubmersionManager()
    @StateObject private var compassManager = CompassManager()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.black, Color.blue.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 8) {
                    // Header
                    VStack(spacing: 2) {
                        Text("Freedive")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))

                        Text(phase.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    // Error banner for depth sensor issues
                    if let error = waterManager.errorDescription {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }

                     if let compassError = compassManager.errorDescription {
                        Text(compassError)
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }

                    // Main depth display
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f m", currentDepth))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)

                        Text("GOAL \(String(format: "%.1f", diveGoal)) m")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.top, 4)

                    // Heart rate
                    VStack(spacing: 2) {
                        Text("Heart rate")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))

                        Text(heartRateManager.heartRate > 0
                             ? "\(heartRateManager.heartRate) bpm"
                             : "-- bpm")
                            .font(.system(.title3, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 4)

                    // Water temperature
                    VStack(spacing: 2) {
                        Text("Water temp")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))

                        Text(waterManager.waterTemperatureCelsius.map { String(format: "%.1f C", $0) } ?? "-- C")
                            .font(.system(.title3, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 2)

                    // Compass heading
                    VStack(spacing: 2) {
                        Text("Heading")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))

                        if let heading = compassManager.headingDegrees {
                            let direction = compassManager.headingDirection ?? "--"
                            Text("\(direction) \(String(format: "%.0f°", heading))")
                                .font(.system(.title3, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        } else {
                            Text("--°")
                                .font(.system(.title3, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 2)

                    // Time + depth controls
                    VStack(spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dive time")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.7))

                                Text(formattedTime(diveTime))
                                    .font(.system(.body, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            VStack(alignment: .center, spacing: 2) {
                                Text("Current depth")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.7))

                                Text(String(format: "%.1f m", currentDepth))
                                    .font(.system(.body, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Goal depth")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.7))

                                HStack(spacing: 8) {
                                    Button {
                                        changeDepth(by: -1)
                                    } label: {
                                        Image(systemName: "minus")
                                            .font(.caption2)
                                    }

                                    Button {
                                        changeDepth(by: 1)
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.caption2)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.white)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Start / Stop button
                    Button(action: {
                        isDiving ? stopDive() : startDive()
                    }) {
                        Text(isDiving ? "End Dive" : "Start Dive")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isDiving ? .red : .green)
                    .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            waterManager.start()
            compassManager.start()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            heartRateManager.stop()
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

    // MARK: - Logic

    private func startDive(initialDepth: Double? = nil) {
        isDiving = true
        phase = .diving
        diveTime = 0

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

        timer?.invalidate()
        timer = nil

        heartRateManager.stop()
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
