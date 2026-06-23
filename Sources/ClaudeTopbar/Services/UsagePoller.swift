import Foundation
import SwiftUI

@Observable
@MainActor
final class UsagePoller {
    var usage: UsageResponse?
    var error: ClaudeAPIError?
    var isLoading: Bool = false
    var lastUpdated: Date?

    var showTimeInMenuBar: Bool = UserDefaults.standard.bool(forKey: "showTimeInMenuBar") {
        didSet { UserDefaults.standard.set(showTimeInMenuBar, forKey: "showTimeInMenuBar") }
    }

    private var pollTimer: Timer?
    private var cachedOrgId: String?
    private let pollInterval: TimeInterval = 60

    init() {
        // Defer start to next run loop tick so @Observable is ready
        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    /// True when this account is governed by a dollar spend limit instead of
    /// rolling-session buckets (e.g. Enterprise spend limits).
    var isSpendLimitAccount: Bool {
        guard let usage else { return false }
        return usage.fiveHour == nil && usage.sevenDay == nil && usage.spend != nil
    }

    var displayPercentage: Int {
        guard let usage else { return 0 }
        let session = usage.fiveHour?.percentage
        let weekly = usage.sevenDay?.percentage
        if session != nil || weekly != nil {
            return max(session ?? 0, weekly ?? 0)
        }
        return usage.spend?.percentage ?? 0
    }

    /// Normalized 0.0-1.0 for the menu bar progress bar
    var sessionFraction: Double {
        if let fraction = usage?.fiveHour?.fraction { return fraction }
        return usage?.spend?.fraction ?? 0
    }

    var sessionResetsAt: Date? {
        usage?.fiveHour?.resetsAtDate
    }

    /// How far through the 5h window we are (0.0 to 1.0)
    var windowProgress: Double {
        usage?.fiveHour?.windowProgress(windowHours: 5) ?? 0
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
