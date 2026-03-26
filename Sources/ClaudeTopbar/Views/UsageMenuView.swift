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
            Text("Claude Usage")
                .font(.headline)

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

            HStack(spacing: 12) {
                if !needsSignIn {
                    Button("Refresh") {
                        Task { await poller.pollNow() }
                    }
                    .disabled(poller.isLoading)
                }

                Button("Settings...") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }

                Spacer()

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
                usageLine(label: "Session (5h)", bucket: bucket)
            }
            if let bucket = usage.sevenDay {
                usageLine(label: "Weekly (7d)", bucket: bucket)
            }
            if let bucket = usage.sevenDayOpus {
                usageLine(label: "Opus (7d)", bucket: bucket)
            }
            if let bucket = usage.sevenDaySonnet {
                usageLine(label: "Sonnet (7d)", bucket: bucket)
            }
        }
    }

    private func usageLine(label: String, bucket: UsageBucket) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(.body, weight: .medium))
                Spacer()
                Text("\(bucket.percentage)%")
                    .font(.system(.body, weight: .semibold).monospacedDigit())
                    .foregroundStyle(colorForPercentage(bucket.percentage))
            }

            ProgressView(value: bucket.fraction)
                .tint(colorForPercentage(bucket.percentage))

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

    private func colorForPercentage(_ pct: Int) -> Color {
        if pct >= 95 { return .red }
        if pct >= 80 { return .orange }
        return .blue
    }
}
