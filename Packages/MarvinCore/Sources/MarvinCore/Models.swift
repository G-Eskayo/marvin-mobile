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

/// The health monitor's traffic light. `grey` = no data yet, or a value this app doesn't know.
public enum Severity: String, Decodable, Sendable, CaseIterable {
    case red, yellow, green, grey

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Severity(rawValue: raw) ?? .grey
    }
}

/// `GET /health`: the health monitor's latest run (ADR 0033, written by health_checks.py).
public struct HealthStatus: Decodable, Equatable, Sendable {
    public let generatedAt: String?
    public let overall: Severity
    public let checks: [Check]

    public struct Check: Decodable, Equatable, Identifiable, Sendable {
        public let id: String
        public let label: String
        public let severity: Severity
        public let detail: String?
    }

    public func count(_ severity: Severity) -> Int {
        checks.count { $0.severity == severity }
    }

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case overall, checks
    }
}

/// `GET /boards`: one project board.
public struct Board: Decodable, Equatable, Identifiable, Sendable {
    public let repo: String
    public let name: String?
    public let due: String?
    public let dueHard: Bool?
    public let status: String?
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

/// `GET /board/<repo>`: one project's board with columns and cards.
public struct BoardDetail: Decodable, Equatable, Sendable {
    public let repo: String
    public let name: String?
    public let columns: [BoardColumn]?
    public let otherProjects: [BoardOtherProject]?

    enum CodingKeys: String, CodingKey {
        case repo, name, columns
        case otherProjects = "other_projects"
    }
}

public struct BoardColumn: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let cards: [BoardCard]?

    enum CodingKeys: String, CodingKey {
        case id, name, cards
    }
}

public struct BoardCard: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let title: String?
    public let repo: String?
    public let assignee: String?

    enum CodingKeys: String, CodingKey {
        case id, number, title, repo, assignee
    }
}

public struct BoardOtherProject: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let repo: String
    public let name: String?
    public let cardCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, repo, name
        case cardCount = "card_count"
    }
}

/// `GET /timeline/<repo>/<number>`: one ticket's event timeline, newest first.
public struct TimelineEvent: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let type: String
    public let actor: String?
    public let body: String?
    public let createdAt: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        type = (try container.decodeIfPresent(String.self, forKey: .type)) ?? "unknown"
        actor = try container.decodeIfPresent(String.self, forKey: .actor)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, type, actor, body
        case createdAt = "created_at"
    }
}

/// `GET /relations/<repo>/<number>`: related PRs and docs for one ticket.
public struct TicketRelations: Decodable, Equatable, Sendable {
    public let repo: String
    public let number: Int
    public let relatedPRs: [RelatedRef]?
    public let relatedDocs: [RelatedDoc]?

    enum CodingKeys: String, CodingKey {
        case repo, number
        case relatedPRs = "related_prs"
        case relatedDocs = "related_docs"
    }
}

public struct RelatedRef: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let title: String?
    public let repo: String?
    public let state: String?

    enum CodingKeys: String, CodingKey {
        case id, number, title, repo, state
    }
}

public struct RelatedDoc: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let path: String
    public let label: String?

    enum CodingKeys: String, CodingKey {
        case id, path, label
    }
}

/// `GET /activity/overview`: summary of projects and their queue states.
public struct ProjectOverview: Decodable, Equatable, Sendable {
    public let projects: [ProjectOverviewItem]?

    enum CodingKeys: String, CodingKey {
        case projects
    }
}

public struct ProjectOverviewItem: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let repo: String
    public let needsYou: Bool?
    public let waitingCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, repo
        case needsYou = "needs_you"
        case waitingCount = "waiting_count"
    }
}

/// `GET /queue`: the dispatch queue's current state.
public struct QueueStatus: Decodable, Equatable, Sendable {
    public let entries: [QueueEntry]?
    public let totalWaiting: Int?

    enum CodingKeys: String, CodingKey {
        case entries
        case totalWaiting = "total_waiting"
    }
}

public struct QueueEntry: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let repo: String?
    public let title: String?
    public let stage: String?

    enum CodingKeys: String, CodingKey {
        case id, number, repo, title, stage
    }
}

/// Result of a successful ticket reply.
public struct TicketReplyResult: Decodable, Equatable, Sendable {
    public let success: Bool
    public let replyId: String?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case replyId = "reply_id"
        case message
    }
}
