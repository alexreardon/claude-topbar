import Foundation

// TODO: Move session key storage back to macOS Keychain once the app is stable.
// Currently using a file (~/.claude/topbar-session-key) to avoid repeated Keychain
// authorization prompts that occur on every rebuild (ad-hoc signing changes the binary hash).
// The file has 0600 permissions but is readable by any process running as the current user.
enum KeychainService {
    private static let configDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")
    private static let credFile = configDir.appendingPathComponent("topbar-session-key")

    static func save(sessionKey: String) throws {
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        // File permissions: owner read/write only (0600)
        let data = Data(sessionKey.utf8)
        FileManager.default.createFile(atPath: credFile.path, contents: data, attributes: [.posixPermissions: 0o600])
    }

    static func load() -> String? {
        guard let data = try? Data(contentsOf: credFile) else { return nil }
        let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return key?.isEmpty == false ? key : nil
    }

    static func delete() {
        try? FileManager.default.removeItem(at: credFile)
    }
}
