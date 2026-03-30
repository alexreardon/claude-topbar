import Foundation

enum ClaudeAPIError: Error, LocalizedError {
    case noSessionKey
    case authFailed
    case rateLimited
    case invalidResponse(Int)
    case decodingError(Error, body: Data? = nil)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noSessionKey: return "No session key configured"
        case .authFailed: return "Session key expired or invalid"
        case .rateLimited: return "Rate limited — try again shortly"
        case .invalidResponse(let code): return "Server returned HTTP \(code)"
        case .decodingError(let err, let body):
            let preview = body.flatMap { String(data: $0.prefix(200), encoding: .utf8) } ?? ""
            return "Failed to parse response: \(err.localizedDescription)" +
                   (preview.isEmpty ? "" : "\n\nResponse preview: \(preview)")
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        }
    }
}

enum ClaudeAPIService {
    private static let baseURL = "https://claude.ai/api"

    private static func makeRequest(url: URL, sessionKey: String) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("1.0.0", forHTTPHeaderField: "anthropic-client-version")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            forHTTPHeaderField: "user-agent"
        )
        request.setValue("https://claude.ai", forHTTPHeaderField: "origin")
        request.setValue("https://claude.ai/settings/usage", forHTTPHeaderField: "referer")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        return request
    }

    static func fetchOrganizations(sessionKey: String) async throws -> [Organization] {
        guard let url = URL(string: "\(baseURL)/organizations") else {
            throw ClaudeAPIError.networkError(URLError(.badURL))
        }
        let request = makeRequest(url: url, sessionKey: sessionKey)
        let (data, response) = try await perform(request)
        try checkResponse(response)
        do {
            return try JSONDecoder().decode([Organization].self, from: data)
        } catch {
            throw ClaudeAPIError.decodingError(error, body: data)
        }
    }

    static func fetchUsage(sessionKey: String, orgId: String) async throws -> UsageResponse {
        guard let url = URL(string: "\(baseURL)/organizations/\(orgId)/usage") else {
            throw ClaudeAPIError.networkError(URLError(.badURL))
        }
        let request = makeRequest(url: url, sessionKey: sessionKey)
        let (data, response) = try await perform(request)
        try checkResponse(response)
        do {
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            throw ClaudeAPIError.decodingError(error, body: data)
        }
    }

    private static func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeAPIError.networkError(error)
        }
    }

    private static func checkResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 401, 403: throw ClaudeAPIError.authFailed
        case 429: throw ClaudeAPIError.rateLimited
        default: throw ClaudeAPIError.invalidResponse(http.statusCode)
        }
    }
}
