import SwiftUI

struct UsageMenuView: View {
    let poller: UsagePoller
    let openSettings: () -> Void
    let openLogin: () -> Void

    private var needsSignIn: Bool {
        if case .noSessionKey = poller.error { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ClaudeLogo()
                    .fill(ClaudeLogo.terracotta)
                    .frame(width: 16, height: 16)
                Text("Claude usage")
                    .font(.headline)
            }

            if needsSignIn {
                signInSection
            } else {
                if let error = poller.error {
                    errorSection(error)
                }

                if let usage = poller.usage {
                    usageSection(usage)
                } else if poller.error == nil {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading...")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            if let lastUpdated = poller.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if !needsSignIn {
                    Button { Task { await poller.pollNow() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(poller.isLoading)
                    .help("Refresh")
                }

                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")

                Spacer()

                Button("Usage page") {
                    NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!)
                }

                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 280)
        .task {
            if poller.usage == nil && poller.error == nil {
                await poller.pollNow()
            }
        }
    }

    @ViewBuilder
    private var signInSection: some View {
        VStack(spacing: 8) {
            Text("Sign in to see your usage")
                .foregroundStyle(.secondary)
            Button("Sign in with Claude...") {
                openLogin()
                NSApp.activate(ignoringOtherApps: true)
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func usageSection(_ usage: UsageResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let bucket = usage.fiveHour {
                usageLine(label: "Session (5h)", bucket: bucket, windowHours: 5)
            }
            if let bucket = usage.sevenDay {
                usageLine(label: "Weekly (7d)", bucket: bucket, windowHours: 7 * 24)
            }
            if let bucket = usage.sevenDayOpus {
                usageLine(label: "Opus (7d)", bucket: bucket, windowHours: 7 * 24)
            }
            if let bucket = usage.sevenDaySonnet {
                usageLine(label: "Sonnet (7d)", bucket: bucket, windowHours: 7 * 24)
            }

            if let extra = usage.extraUsage, extra.isEnabled == true, extra.percentage != nil {
                Divider()
                extraUsageLine(extra)
            }
        }
    }

    private func usageLine(label: String, bucket: UsageBucket, windowHours: Double) -> some View {
        let wp = bucket.windowProgress(windowHours: windowHours)
        let color = usageColor(fraction: bucket.fraction, percentage: bucket.percentage, windowProgress: wp)
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(.body, weight: .medium))
                Spacer()
                Text("\(bucket.percentage)% used")
                    .font(.system(.body, weight: .semibold).monospacedDigit())
                    .foregroundStyle(color)
            }

            UsageBar(
                fraction: bucket.fraction,
                windowProgress: wp,
                tint: color
            )

            if let resetsAt = bucket.resetsAtDate {
                Text("Resets \(resetsAt, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func errorSection(_ error: ClaudeAPIError) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(error.errorDescription ?? "Unknown error")
                .font(.caption)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    private func extraUsageLine(_ extra: ExtraUsage) -> some View {
        let pct = extra.percentage ?? 0
        let frac = extra.fraction ?? 0
        let color: Color = pct >= 95 ? .red : pct >= 80 ? .orange : .blue
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Extra usage")
                    .font(.system(.body, weight: .medium))
                Spacer()
                Text("\(pct)% used")
                    .font(.system(.body, weight: .semibold).monospacedDigit())
                    .foregroundStyle(color)
            }

            UsageBar(
                fraction: frac,
                windowProgress: 0,
                tint: color
            )

            if let spent = extra.spentFormatted {
                Text("\(spent) spent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func usageColor(fraction: Double, percentage: Int, windowProgress: Double) -> Color {
        if percentage >= 95 { return .red }
        if percentage >= 80 { return .orange }
        if fraction < windowProgress { return .green }
        return .orange
    }
}

private struct UsageBar: View {
    let fraction: Double
    let windowProgress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(.gray.opacity(0.2))

                // Fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(tint)
                    .frame(width: geo.size.width * CGFloat(min(fraction, 1.0)))

                // Tick marker
                if windowProgress > 0 && windowProgress < 1 {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white)
                        .frame(width: 2.5)
                        .offset(x: geo.size.width * CGFloat(windowProgress) - 1.25)
                }
            }
        }
        .frame(height: 6)
    }
}
