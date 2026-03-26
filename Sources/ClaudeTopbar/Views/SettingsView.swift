import SwiftUI

struct SettingsView: View {
    let poller: UsagePoller
    @State private var sessionKeyInput: String = ""
    @State private var saveState: SaveState = .idle
    @Environment(\.dismiss) private var dismiss

    private enum SaveState {
        case idle, saved, error(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Claude Topbar Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Session Key")
                    .font(.subheadline.weight(.medium))

                SecureField("sk-ant-sid01-...", text: $sessionKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Text("Find this in your browser: claude.ai → DevTools (F12) → Application → Cookies → sessionKey")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(sessionKeyInput.isEmpty || sessionKeyInput.hasPrefix("sk-ant-sid••"))

                switch saveState {
                case .idle: EmptyView()
                case .saved:
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                case .error(let msg):
                    Label(msg, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Spacer()

                if KeychainService.load() != nil {
                    Button("Clear Key") {
                        KeychainService.delete()
                        sessionKeyInput = ""
                        poller.stop()
                        poller.usage = nil
                        poller.error = .noSessionKey
                        saveState = .idle
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            if KeychainService.load() != nil {
                sessionKeyInput = "sk-ant-sid••••••••••••"
            }
        }
    }

    private func save() {
        let key = sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.hasPrefix("sk-ant-sid••") else { return }

        do {
            try KeychainService.save(sessionKey: key)
            saveState = .saved
            poller.restart()
            Task {
                try? await Task.sleep(for: .seconds(3))
                if case .saved = saveState { saveState = .idle }
            }
        } catch {
            saveState = .error("Failed to save to Keychain")
        }
    }
}
