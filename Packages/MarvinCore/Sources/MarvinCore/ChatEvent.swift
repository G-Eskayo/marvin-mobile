import Foundation

/// One normalised event from the backend's streamed `/chat` reply (one NDJSON line).
public enum ChatEvent: Equatable, Sendable {
    case session(id: String)
    case text(String)
    case toolUse(name: String)
    case result(text: String, sessionId: String?, isError: Bool)
    case error(String)

    /// Nil for blank, malformed or unknown lines: the stream may grow new event
    /// types, and an older app should skip them rather than fail.
    public init?(line: String) {
        guard let data = line.data(using: .utf8),
              let raw = try? JSONDecoder().decode(Raw.self, from: data) else { return nil }
        switch raw.type {
        case "session": self = .session(id: raw.sessionId ?? "")
        case "text": self = .text(raw.text ?? "")
        case "tool_use": self = .toolUse(name: raw.name ?? "")
        case "result": self = .result(text: raw.text ?? "", sessionId: raw.sessionId, isError: raw.isError ?? false)
        case "error": self = .error(raw.message ?? "Unknown error")
        default: return nil
        }
    }

    private struct Raw: Decodable {
        let type: String
        let sessionId: String?
        let text: String?
        let name: String?
        let message: String?
        let isError: Bool?
    }
}

/// Folds a reply's events into what the Thread shows while it streams.
public struct ReplyAccumulator: Sendable {
    public private(set) var text = ""
    public private(set) var isFinished = false
    public private(set) var error: String?

    public init() {}

    public mutating func apply(_ event: ChatEvent) {
        switch event {
        case .text(let chunk):
            text += chunk
        case .result(let final, _, let isError):
            if text.isEmpty { text = final }
            if isError { error = final }
            isFinished = true
        case .error(let message):
            error = message
            isFinished = true
        case .session, .toolUse:
            break
        }
    }
}
