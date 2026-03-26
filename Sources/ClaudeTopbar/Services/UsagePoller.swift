import Foundation
import SwiftUI

@Observable
@MainActor
final class UsagePoller {
    var usage: UsageResponse?
    var error: ClaudeAPIError?
    var isLoading: Bool = false
    var lastUpdated: Date?

    private var pollTimer: Timer?
    private var cachedOrgId: String?
    private let pollInterval: TimeInterval = 60

    init() {
        // Defer start to next run loop tick so @Observable is ready
        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    enum StatusLevel {
        case normal, warning, critical, unknown
    }

    var displayPercentage: Int {
        guard let usage else { return 0 }
        let session = usage.fiveHour?.percentage ?? 0
        let weekly = usage.sevenDay?.percentage ?? 0
        return max(session, weekly)
    }

    var statusLevel: StatusLevel {
        guard usage != nil else { return .unknown }
        let pct = displayPercentage
        if pct >= 95 { return .critical }
        if pct >= 80 { return .warning }
        return .normal
    }

    /// Normalized 0.0-1.0 for the menu bar progress bar
    var sessionFraction: Double {
        usage?.fiveHour?.fraction ?? 0
    }

    var sessionResetsAt: Date? {
        usage?.fiveHour?.resetsAtDate
    }

    /// How far through the 5h window we are (0.0 to 1.0)
    var windowProgress: Double {
        guard let resetsAt = sessionResetsAt else { return 0 }
        let windowDuration: TimeInterval = 5 * 60 * 60
        let windowStart = resetsAt.addingTimeInterval(-windowDuration)
        let now = Date()
        guard now >= windowStart else { return 0 }
        guard now < resetsAt else { return 1 }
        return now.timeIntervalSince(windowStart) / windowDuration
    }

    var hasSessionKey: Bool {
        KeychainService.load() != nil
    }

    func start() {
        guard KeychainService.load() != nil else {
            error = .noSessionKey
            return
        }
        error = nil
        Task { await pollNow() }
        schedulePoll()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func restart() {
        stop()
        cachedOrgId = nil
        usage = nil
        error = nil
        start()
    }

    func pollNow() async {
        guard let sessionKey = KeychainService.load() else {
            error = .noSessionKey
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if cachedOrgId == nil {
                let orgs = try await ClaudeAPIService.fetchOrganizations(sessionKey: sessionKey)
                cachedOrgId = orgs.first?.uuid
            }
            guard let orgId = cachedOrgId else {
                error = .invalidResponse(0)
                return
            }
            usage = try await ClaudeAPIService.fetchUsage(sessionKey: sessionKey, orgId: orgId)
            error = nil
            lastUpdated = Date()
        } catch let apiError as ClaudeAPIError {
            error = apiError
            if case .authFailed = apiError {
                stop()
            }
        } catch {
            self.error = .networkError(error)
        }
    }

    private func schedulePoll() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.pollNow()
            }
        }
        pollTimer?.tolerance = 10
    }
}
