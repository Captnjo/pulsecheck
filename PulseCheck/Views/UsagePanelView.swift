import SwiftUI
import AppKit
import ServiceManagement

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
        usageSection(title: "Daily (5h window)", period: response.fiveHour, showDate: false)
        Divider()
        usageSection(title: "Weekly (7-day window)", period: response.sevenDay, showDate: true)
        Divider()
        launchClaudeButton()
        bottomRow()
    }

    @ViewBuilder
    private func usageSection(title: String, period: UsagePeriod?, showDate: Bool) -> some View {
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
                .tint(Color(red: 0.83, green: 0.65, blue: 0.45))
            if let period = period {
                Text(showDate ? resetDateString(from: period.resetsAt) : resetCountdown(from: period.resetsAt))
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
        launchClaudeButton()
        bottomRow()
    }

    @ViewBuilder
    private func launchClaudeButton() -> some View {
        Button {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Claude.app"))
        } label: {
            HStack {
                Image(systemName: "arrow.up.forward.app")
                Text("Open Claude")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!FileManager.default.fileExists(atPath: "/Applications/Claude.app"))
    }

    @ViewBuilder
    private func bottomRow() -> some View {
        HStack {
            Toggle("Launch at Login", isOn: Binding(
                get: { SMAppService.mainApp.status == .enabled },
                set: { enable in
                    do {
                        if enable {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // Silently ignore — user may have denied in System Settings
                    }
                }
            ))
            .toggleStyle(.switch)
            Spacer()
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
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
        let timeStr = formatResetTime(date)
        guard seconds > 0 else { return "Resets soon" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "Resets in \(hours)h \(minutes)m at \(timeStr)" }
        return "Resets in \(minutes)m at \(timeStr)"
    }

    private func resetDateString(from isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: isoString)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: isoString)
        }
        guard let date else { return "—" }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMMM 'at' h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return "Resets \(formatter.string(from: date))"
    }

    private func formatResetTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: date)
    }
}
