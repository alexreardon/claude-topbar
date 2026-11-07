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

    static let automaticLimitID = "auto"

    /// `automaticLimitID`, or the `UsageLimit.id` the user pinned to the menu bar.
    var menuBarLimitID: String = UserDefaults.standard.string(forKey: "menuBarLimitID") ?? UsagePoller.automaticLimitID {
        didSet { UserDefaults.standard.set(menuBarLimitID, forKey: "menuBarLimitID") }
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

    /// The one limit that drives the menu bar: its fill, color, pace tick, and
    /// countdown. A pinned limit wins while the API still reports it; otherwise
    /// the automatic rule picks, then the spend limit for spend-only accounts.
    var menuBarLimit: UsageLimit? {
        guard let usage else { return nil }
        if menuBarLimitID != Self.automaticLimitID,
           let pinned = usage.rollingLimits.first(where: { $0.id == menuBarLimitID }) {
            return pinned
        }
        return usage.automaticLimit ?? usage.spendLimit
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
