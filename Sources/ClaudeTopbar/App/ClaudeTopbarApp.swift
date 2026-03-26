import SwiftUI

@main
struct ClaudeTopbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var poller = UsagePoller()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            UsageMenuView(
                poller: poller,
                openSettings: {
                    openWindow(id: "settings")
                },
                openLogin: {
                    openWindow(id: "login")
                }
            )
        } label: {
            MenuBarLabel(poller: poller)
        }
        .menuBarExtraStyle(.window)

        Window("Claude Topbar Settings", id: "settings") {
            SettingsView(poller: poller)
        }
        .windowResizability(.contentSize)

        Window("Sign in to Claude", id: "login") {
            WebLoginView(poller: poller)
        }
        .windowResizability(.contentSize)
    }
}
