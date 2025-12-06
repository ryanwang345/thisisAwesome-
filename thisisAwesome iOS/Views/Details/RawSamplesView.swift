import SwiftUI

struct RawSamplesView: View {
    let dive: DiveSummary
    let primaryText: Color
    let secondaryText: Color

    @State private var isExpanded: Bool = false

    var body: some View {
        let depth = dive.profile.sorted { $0.seconds < $1.seconds }
        let heart = dive.heartRateSamples.sorted { $0.seconds < $1.seconds }
        let temps = dive.waterTempSamples.sorted { $0.seconds < $1.seconds }

        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                rawSection(title: "Depth samples", color: .blue, rows: depth.map {
                    RawRow(id: $0.id, time: $0.seconds, value: String(format: "%.2f m", $0.depthMeters))
                })
                rawSection(title: "Heart rate samples", color: .red, rows: heart.map {
                    RawRow(id: $0.id, time: $0.seconds, value: "\($0.bpm) bpm")
                })
                rawSection(title: "Water temp samples", color: .cyan, rows: temps.map {
                    RawRow(id: $0.id, time: $0.seconds, value: String(format: "%.2f C", $0.celsius))
                })
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 10) {
                Text("Raw samples")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(primaryText)
                Spacer()
                sampleCountPill(label: "Depth", count: depth.count, color: .blue.opacity(0.85))
                sampleCountPill(label: "HR", count: heart.count, color: .red.opacity(0.8))
                sampleCountPill(label: "Temp", count: temps.count, color: .cyan.opacity(0.85))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.16))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1.1)
                )
        )
        .shadow(color: Color.cyan.opacity(0.14), radius: 14, y: 6)
    }

    private func rawSection(title: String, color: Color, rows: [RawRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Spacer()
                Text(rows.isEmpty ? "0" : "\(rows.count)")
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
            }

            if rows.isEmpty {
                Text("No samples recorded.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .padding(.vertical, 4)
            } else {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(rows) { row in
                        HStack(spacing: 10) {
                            Text(formattedElapsed(row.time))
                                .font(.caption.monospacedDigit())
                                .frame(width: 58, alignment: .leading)
                                .foregroundStyle(primaryText)
                            Text(row.value)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(primaryText)
                            Spacer()
                            Text(row.shortId)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(secondaryText)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.14))
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                        .shadow(color: color.opacity(0.18), radius: 6, y: 2)
                    }
                }
            }
        }
    }

    private func sampleCountPill(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
            Text("\(count)")
                .font(.caption2.monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .foregroundStyle(color)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.16))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(color.opacity(0.35), lineWidth: 1.1)
                )
        )
        .shadow(color: color.opacity(0.25), radius: 6, y: 2)
        .clipShape(Capsule())
    }

    private func formattedElapsed(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let remainder = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}

private struct RawRow: Identifiable {
    let id: UUID
    let time: Double
    let value: String

    var shortId: String {
        String(id.uuidString.prefix(8))
    }
}
