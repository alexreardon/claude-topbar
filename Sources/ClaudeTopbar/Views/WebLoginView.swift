import SwiftUI
import WebKit

struct WebLoginView: View {
    let poller: UsagePoller
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var loginSucceeded = false

    var body: some View {
        VStack(spacing: 0) {
            if loginSucceeded {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("Signed in successfully!")
                        .font(.headline)
                    Text("You can close this window.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if isLoading {
                    ProgressView("Loading claude.ai...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                WebLoginWebView(
                    onSessionKeyFound: { key in
                        try? KeychainService.save(sessionKey: key)
                        loginSucceeded = true
                        poller.restart()
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            dismiss()
                        }
                    },
                    onLoadingChanged: { loading in
                        isLoading = loading
                    }
                )
                .opacity(isLoading ? 0 : 1)
            }
        }
        .frame(width: 500, height: 650)
    }
}

struct WebLoginWebView: NSViewRepresentable {
    let onSessionKeyFound: (String) -> Void
    let onLoadingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        let url = URL(string: "https://claude.ai/login")!
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionKeyFound: onSessionKeyFound, onLoadingChanged: onLoadingChanged)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onSessionKeyFound: (String) -> Void
        let onLoadingChanged: (Bool) -> Void
        private var foundKey = false

        init(onSessionKeyFound: @escaping (String) -> Void, onLoadingChanged: @escaping (Bool) -> Void) {
            self.onSessionKeyFound = onSessionKeyFound
            self.onLoadingChanged = onLoadingChanged
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadingChanged(false)
            checkForSessionKey(in: webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if !foundKey {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    self.checkForSessionKey(in: webView)
                }
            }
            return .allow
        }

        private func checkForSessionKey(in webView: WKWebView) {
            guard !foundKey else { return }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.foundKey else { return }
                if let sessionCookie = cookies.first(where: { $0.name == "sessionKey" && $0.domain.contains("claude.ai") }) {
                    self.foundKey = true
                    Task { @MainActor in
                        self.onSessionKeyFound(sessionCookie.value)
                    }
                }
            }
        }
    }
}
