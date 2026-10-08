import Foundation

/// One ticket row from `GET /activity`. Optional fields stay optional: the
/// dashboard's activity rows are sparse for tickets with few stage events.
public struct ActivityItem: Decodable, Identifiable, Equatable, Sendable {
    public let number: Int
    public let repo: String
    public let key: String
    public let currentStage: String?
    public let currentStatus: String?
    public let costUsd: Double?
    public let title: String?
    public let eventCount: Int?
    public let lastEventAt: String?
    public let isLiveNow: Bool?
    private let failedRaw: Bool?

    public var id: String { key }
    public var failed: Bool { failedRaw ?? false }

    enum CodingKeys: String, CodingKey {
        case number, repo, key, currentStage, currentStatus, costUsd, title, eventCount, lastEventAt, isLiveNow
        case failedRaw = "failed"
    }
}

/// `GET /health`: the health monitor's latest run (ADR 0033).
public struct HealthStatus: Decodable, Equatable, Sendable {
    public let generatedAt: String?
    public let overall: String
    public let checks: [Check]

    public struct Check: Decodable, Equatable, Identifiable, Sendable {
        public let name: String
        public let status: String
        public let detail: String?
        public var id: String { name }
    }

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case overall, checks
    }
}

/// `GET /boards`: one project board.
public struct Board: Decodable, Equatable, Identifiable, Sendable {
    public let repo: String
    public let label: String?
    public let due: String?
    public var id: String { repo }
}

/// One message in the Thread (`GET /thread`).
public struct ThreadMessage: Decodable, Equatable, Identifiable, Sendable {
    public enum Role: String, Decodable, Sendable { case user, assistant }

    public let id: String
    public let source: String
    public let role: Role
    public let text: String
    public let sessionId: String?
    public let ts: Double?

    public init(id: String, source: String, role: Role, text: String, sessionId: String? = nil, ts: Double? = nil) {
        self.id = id
        self.source = source
        self.role = role
        self.text = text
        self.sessionId = sessionId
        self.ts = ts
    }
}
