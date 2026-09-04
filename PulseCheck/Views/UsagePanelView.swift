import SwiftUI
import ServiceManagement

struct UsagePanelView: View {
    var store: UsageStore
    @State private var selectedProvider: Provider = .claude

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Provider", selection: $selectedProvider) {
                ForEach(Provider.allCases) { provider in
                    Label(provider.displayName, systemImage: provider.iconName)
                        .tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()

            switch selectedProvider {
            case .claude: claudeTab()
            case .codex: codexTab()
            case .openRouter: openRouterTab()
            }

            Divider()
            timestampAndRefreshRow()
            bottomRow()
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: - Claude

    @ViewBuilder
    private func claudeTab() -> some View {
        if let response = store.usageResponse {
            if let notice = store.usageStaleNotice {
                Label(notice, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            usageSection(title: "Daily (5h window)", period: response.fiveHour, showDate: false, projection: claudeProjection)
            Divider()
            usageSection(title: "Weekly (7-day window)", period: response.effectiveSevenDay, showDate: true)
        } else {
            errorBlock(store.usageError ?? .providerNotAuthenticated("Claude Code"))
        }
    }

    /// Burn-rate caption + projected end-of-window value, when a trend exists.
    private var claudeProjection: (caption: String, projected: Double)? {
        guard let projected = store.projectedFiveHourAtReset() else { return nil }
        let caption = store.burnRateCaption() ?? "on track for ~\(Int(projected.rounded()))% by reset"
        return (caption, projected)
    }

    // MARK: - Codex

    @ViewBuilder
    private func codexTab() -> some View {
        if let usage = store.codexUsage {
            if let primary = usage.primaryWindow {
                codexWindowSection(window: primary)
                Divider()
            }
            if let secondary = usage.secondaryWindow {
                codexWindowSection(window: secondary)
                Divider()
            }
            if usage.primaryWindow == nil && usage.secondaryWindow == nil {
                Text("No usage windows reported yet — run codex first")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            errorBlock(codexErrorOrPlaceholder)
        }
    }

    private var codexErrorOrPlaceholder: AppError {
        if let error = store.codexError, case .apiError(_, let snippet) = error, snippet.isEmpty {
            return .apiError(0, "Error")
        }
        return store.codexError ?? .providerUnavailable("Codex")
    }

    private func codexWindowSection(window: CodexUsage.Window) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(window.windowLabel)
                    .font(.headline)
                Spacer()
                Text(window.displayString)
                    .font(.headline)
                    .monospacedDigit()
            }
            ProgressView(value: Double(window.usedPercent) / 100.0)
                .progressViewStyle(.linear)
                .tint(Self.barTint(for: Double(window.usedPercent)))
            Text(codexResetText(window: window, showDate: window.isWeeklyOrLonger))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func codexResetText(window: CodexUsage.Window, showDate: Bool) -> String {
        let resetDate = Date(timeIntervalSince1970: TimeInterval(window.resetAt))
        let seconds = Int(resetDate.timeIntervalSinceNow)
        let timeStr = formatResetTime(resetDate)
        guard seconds > 0 else { return "Resets soon" }
        if showDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE d MMMM 'at' h:mma"
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
            return "Resets \(formatter.string(from: resetDate))"
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "Resets in \(hours)h \(minutes)m at \(timeStr)" }
        return "Resets in \(minutes)m at \(timeStr)"
    }

    // MARK: - OpenRouter

    @ViewBuilder
    private func openRouterTab() -> some View {
        if let info = store.openRouterUsage {
            spendRow(label: "Today", amount: info.usageDaily)
            spendRow(label: "This week", amount: info.usageWeekly)
            spendRow(label: "This month", amount: info.usageMonthly)
            if let limit = info.key.limit, limit > 0 {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Per-key limit")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "$%.2f left", info.limitRemaining ?? 0))
                            .font(.headline)
                            .monospacedDigit()
                    }
                    ProgressView(value: (info.limitUtilization ?? 0) / 100.0)
                        .progressViewStyle(.linear)
                        .tint(Self.barTint(for: info.limitUtilization ?? 0))
                }
            }
        } else {
            errorBlock(store.openRouterError ?? .providerNotAuthenticated("OpenRouter"))
        }
    }

    private func spendRow(label: String, amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.headline)
            Spacer()
            Text(String(format: "$%.2f", amount))
                .font(.headline)
                .monospacedDigit()
        }
    }

    // MARK: - Shared

    @ViewBuilder
    private func errorBlock(_ error: AppError) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func usageSection(title: String, period: UsagePeriod?, showDate: Bool, projection: (caption: String, projected: Double)? = nil) -> some View {
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
                .tint(Self.barTint(for: projection?.projected ?? period?.utilization ?? 0))
            if let projection {
                Text(projection.caption)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
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

    /// Adaptive bar color: tint reflects the PROJECTED end-of-window value when
    /// available (burn rate can turn the bar amber before the number does).
    static func barTint(for projectedPercent: Double) -> Color {
        switch UsageSeverity.forPercent(projectedPercent) {
        case .normal: return Color(red: 0.35, green: 0.65, blue: 0.40)   // green
        case .elevated: return Color(red: 0.90, green: 0.62, blue: 0.20) // amber
        case .high: return Color(red: 0.85, green: 0.28, blue: 0.25)     // red
        }
    }

    @ViewBuilder
    private func timestampAndRefreshRow() -> some View {
        HStack {
            Text(lastUpdatedText(for: store.lastFetchDate))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { @MainActor in
                    await store.manualRefresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .rotationEffect(.degrees(store.isFetching ? 360 : 0))
                    .animation(
                        store.isFetching
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: store.isFetching
                    )
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .disabled(store.isFetching)
        }
    }

    private func lastUpdatedText(for date: Date?) -> String {
        guard let date else { return "Not yet updated" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return "Updated \(formatter.string(from: date))"
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
