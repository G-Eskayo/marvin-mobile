import Foundation

public enum BackendError: Error, Equatable {
    /// The backend answered `{ ok: false, error }`.
    case server(String)
    /// This device isn't on the backend's allowlist (403).
    case notAllowlisted
    case badResponse
}

extension BackendError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .server(let message): "MARVIN couldn't answer: \(message)"
        case .notAllowlisted: "This device isn't on MARVIN's allowlist."
        case .badResponse: "MARVIN sent a reply the app didn't understand."
        }
    }
}

/// Talks to the mobile backend over Tailscale (marvin/dashboard/mobile-backend).
/// Read-only calls plus Chat; side-effecting calls arrive with the Face ID gate.
public struct BackendClient: Sendable {
    public let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// `GET /status`, short timeout: drives the online/offline banner.
    public func probe() async -> ProbeResult {
        var request = URLRequest(url: baseURL.appending(path: "status"))
        request.timeoutInterval = 5
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { return .unreachable }
        switch http.statusCode {
        case 200: return .reached
        case 403: return .rejected
        default: return .unreachable
        }
    }

    public func activity() async throws -> [ActivityItem] { try await get("activity") }
    public func health() async throws -> HealthStatus { try await get("health") }
    public func boards() async throws -> [Board] { try await get("boards") }
    public func boardDetail(repo: String) async throws -> BoardDetail {
        try await get("boards/load", query: [URLQueryItem(name: "repo", value: repo)])
    }
    public func ticketDetail(repo: String, number: Int) async throws -> TicketDetail {
        try await get("boards/ticket", query: [
            URLQueryItem(name: "repo", value: repo),
            URLQueryItem(name: "number", value: String(number))
        ])
    }
    public func timeline(repo: String, number: Int) async throws -> [TimelineEvent] {
        try await get("activity/timeline", query: [
            URLQueryItem(name: "repo", value: repo),
            URLQueryItem(name: "number", value: String(number))
        ])
    }
    public func relationsForTicket(repo: String, number: Int) async throws -> TicketRelations {
        try await get("relations/ticket", query: [
            URLQueryItem(name: "repo", value: repo),
            URLQueryItem(name: "number", value: String(number))
        ])
    }
    public func queue() async throws -> QueueResponse { try await get("queue") }

    /// The Thread, oldest first (the backend pages newest first).
    public func thread(limit: Int = 50) async throws -> [ThreadMessage] {
        let page: [ThreadMessage] = try await get("thread", query: [URLQueryItem(name: "limit", value: String(limit))])
        return page.reversed()
    }

    /// `POST /boards/ticket/reply`: post a comment/action to a ticket and get the result.
    public func replyToTicket(repo: String, number: Int, body: String) async throws -> TicketReplyResult {
        var request = URLRequest(url: baseURL.appending(path: "boards/ticket/reply"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct ReplyPayload: Encodable { let repo: String; let number: Int; let body: String; let confirmed: Bool }
        request.httpBody = try JSONEncoder().encode(ReplyPayload(repo: repo, number: number, body: body, confirmed: true))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.badResponse }
        if http.statusCode == 403 { throw BackendError.notAllowlisted }
        if !(200..<300).contains(http.statusCode) {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error
            throw BackendError.server(message ?? "HTTP \(http.statusCode)")
        }
        let envelope = try JSONDecoder().decode(Envelope<TicketReplyResult>.self, from: data)
        guard envelope.ok, let value = envelope.data else {
            throw BackendError.server(envelope.error ?? "empty response")
        }
        return value
    }

    /// `POST /chat`: streams the reply's events as they arrive.
    public func chat(_ message: String) -> AsyncThrowingStream<ChatEvent, Error> {
        var request = URLRequest(url: baseURL.appending(path: "chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["message": message])
        // A Claude Code turn can run for minutes; don't cut it off at the default 60s.
        request.timeoutInterval = 600
        let session = self.session
        let finalRequest = request
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: finalRequest)
                    try Self.check(response)
                    for try await line in bytes.lines {
                        if let event = ChatEvent(line: line) { continuation.yield(event) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Plumbing

    public struct Envelope<T: Decodable>: Decodable {
        public let ok: Bool
        public let data: T?
        public let error: String?
    }

    private struct ErrorEnvelope: Decodable { let error: String? }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var url = baseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw BackendError.badResponse }
        if http.statusCode == 403 { throw BackendError.notAllowlisted }
        if !(200..<300).contains(http.statusCode) {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error
            throw BackendError.server(message ?? "HTTP \(http.statusCode)")
        }
        let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
        guard envelope.ok, let value = envelope.data else {
            throw BackendError.server(envelope.error ?? "empty response")
        }
        return value
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw BackendError.badResponse }
        if http.statusCode == 403 { throw BackendError.notAllowlisted }
        if !(200..<300).contains(http.statusCode) { throw BackendError.server("HTTP \(http.statusCode)") }
    }
}
