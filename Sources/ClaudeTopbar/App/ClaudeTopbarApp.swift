import SwiftUI

@main
struct ClaudeTopbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var poller = UsagePoller()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            UsageMenuView(poller: poller, openSettings: {
                openWindow(id: "settings")
            })
        } label: {
            MenuBarLabel(poller: poller)
        }
        .menuBarExtraStyle(.window)

        Window("Claude Topbar Settings", id: "settings") {
            SettingsView(poller: poller)
        }
        .windowResizability(.contentSize)
    }
}
