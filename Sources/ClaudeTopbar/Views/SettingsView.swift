import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let poller: UsagePoller
    @State private var showManualEntry = false
    @State private var sessionKeyInput: String = ""
    @State private var saveState: SaveState = .idle
    @Environment(\.openWindow) private var openWindow

    private enum SaveState {
        case idle, saved, error(String)
    }

    private var isSignedIn: Bool {
        KeychainService.load() != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Claude Topbar")
                .font(.headline)

            if isSignedIn {
                signedInSection
                Divider()
                displaySection
            } else {
                signedOutSection
            }

            if showManualEntry {
                manualEntrySection
            }

            Divider()

            HStack {
                Spacer()
                Text("Made by ")
                    .foregroundStyle(.tertiary)
                +
                Text("Alex Reardon")
                    .foregroundStyle(.tertiary)
                    .underline()
                Spacer()
            }
            .font(.caption)
            .onTapGesture {
                NSWorkspace.shared.open(URL(string: "https://x.com/alexandereardon")!)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    @ViewBuilder
    private var signedInSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Signed in")
                .font(.subheadline)
            Spacer()
            Button("Sign out") {
                KeychainService.delete()
                sessionKeyInput = ""
                showManualEntry = false
                poller.stop()
                poller.usage = nil
                poller.error = .noSessionKey
                saveState = .idle
            }
        }
    }

    @ViewBuilder
    private var displaySection: some View {
        Toggle("Start on login", isOn: $startOnLogin)
        Toggle("Show time remaining in menu bar", isOn: Bindable(poller).showTimeInMenuBar)
    }

    @State private var startOnLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                if startOnLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                startOnLogin = !startOnLogin
            }
        }
    }

    @ViewBuilder
    private var signedOutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Sign in with Claude...") {
                openWindow(id: "login")
                NSApp.activate(ignoringOtherApps: true)
            }
            .controlSize(.large)

            Button(showManualEntry ? "Hide manual entry" : "Enter session key manually") {
                showManualEntry.toggle()
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var manualEntrySection: some View {
        Divider()

        VStack(alignment: .leading, spacing: 6) {
            Text("Session key")
                .font(.subheadline.weight(.medium))

            SecureField("sk-ant-sid01-...", text: $sessionKeyInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            Text("Browser → DevTools (F12) → Application → Cookies → sessionKey")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        HStack {
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
                .disabled(sessionKeyInput.isEmpty)

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
        }
    }

    private func save() {
        let key = sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try KeychainService.save(sessionKey: key)
            saveState = .saved
            showManualEntry = false
            poller.restart()
            Task {
                try? await Task.sleep(for: .seconds(3))
                if case .saved = saveState { saveState = .idle }
            }
        } catch {
            saveState = .error("Failed to save session key")
        }
    }
}
