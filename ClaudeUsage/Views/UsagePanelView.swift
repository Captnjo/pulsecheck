import SwiftUI
import AppKit

struct UsagePanelView: View {
    var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let response = store.usageResponse {
                normalState(response: response)
            } else {
                errorState()
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    @ViewBuilder
    private func normalState(response: UsageResponse) -> some View {
        usageSection(title: "Daily (5h window)", period: response.fiveHour)
        Divider()
        usageSection(title: "Weekly (7-day window)", period: response.sevenDay)
        Divider()
        quitButton()
    }

    @ViewBuilder
    private func usageSection(title: String, period: UsagePeriod?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(period?.displayString ?? "—")
                    .font(.headline)
                    .monospacedDigit()
            }
            ProgressView(value: period != nil ? period!.utilization / 100.0 : 0.0)
                .progressViewStyle(.linear)
            if let period = period {
                Text(resetCountdown(from: period.resetsAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func errorState() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text(store.usageError?.localizedDescription ?? "No data available")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        Divider()
        quitButton()
    }

    @ViewBuilder
    private func quitButton() -> some View {
        Button("Quit", role: .destructive) {
            NSApplication.shared.terminate(nil)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    private func resetCountdown(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else {
            // Fallback: try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date2 = formatter.date(from: isoString) else { return "—" }
            return countdownString(to: date2)
        }
        return countdownString(to: date)
    }

    private func countdownString(to date: Date) -> String {
        let seconds = Int(date.timeIntervalSinceNow)
        guard seconds > 0 else { return "Resets soon" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "Resets in \(hours)h \(minutes)m" }
        return "Resets in \(minutes)m"
    }
}
