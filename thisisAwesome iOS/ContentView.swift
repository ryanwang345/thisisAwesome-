import SwiftUI

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
}

#Preview {
    ContentView()
}
