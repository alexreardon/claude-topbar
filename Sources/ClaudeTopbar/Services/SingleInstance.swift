import Foundation

// Stops a second ClaudeTopbar from running at the same time.
//
// Uses a file lock instead of NSRunningApplication.runningApplications(withBundleIdentifier:)
// because the packaged app and a `swift run` debug binary do not share an identity:
// the debug binary has no bundle identifier at all. A file lock catches every
// combination of the two.
enum SingleInstance {
    private static let lockFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")
        .appendingPathComponent("topbar-instance.lock")

    // Stays open for the lifetime of the process. macOS releases the lock when the
    // process ends, a crash included, so a leftover lock file does not block a restart.
    private static var lockDescriptor: Int32 = -1

    /// Takes the lock. Returns false when another ClaudeTopbar already holds it.
    static func acquire() -> Bool {
        // Already held by this process.
        guard lockDescriptor < 0 else { return true }

        try? FileManager.default.createDirectory(
            at: lockFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let descriptor = open(lockFile.path, O_CREAT | O_RDWR, 0o600)
        // Without a lock file there is no way to tell, so let the app start.
        guard descriptor >= 0 else { return true }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return false
        }

        lockDescriptor = descriptor
        return true
    }
}
