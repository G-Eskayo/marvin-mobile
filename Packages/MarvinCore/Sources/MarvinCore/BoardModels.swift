import Foundation

/// `GET /boards/load?repo=`: A project's full board state with columns, cards, and related projects.
public struct BoardDetail: Decodable, Equatable, Sendable {
    public let repo: String
    public let columns: [BoardColumn]
    public let otherProjects: [OtherProjectSummary]
    public let fetchedAt: String

    enum CodingKeys: String, CodingKey {
        case repo, columns, otherProjects = "other_projects", fetchedAt = "fetched_at"
    }
}

/// One column in a board (represents a workflow stage or state).
public struct BoardColumn: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let cards: [Card]
    public let archive: Bool?

    public init(id: String, label: String, cards: [Card], archive: Bool? = nil) {
        self.id = id
        self.label = label
        self.cards = cards
        self.archive = archive
    }
}

/// One ticket card on a board (contains full detail for the board view).
public struct Card: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let repo: String?
    public let title: String
    public let reason: String?
    public let progress: Progress?
    public let evidence: Evidence?
    public let blockedBy: [BlockerInfo]?
    public let tags: [Tag]?
    public let prLinks: [PRLink]?

    enum CodingKeys: String, CodingKey {
        case id, number, repo, title, reason, progress, evidence
        case blockedBy = "blocked_by"
        case tags, prLinks = "pr_links"
    }

    /// Represents task completion: how many items are done out of the total.
    public struct Progress: Decodable, Equatable, Sendable {
        public let done: Int
        public let total: Int
    }

    /// Evidence verdict and linked items (test results, status checks, manual approvals).
    public struct Evidence: Decodable, Equatable, Sendable {
        public let verdict: String
        public let items: [EvidenceItem]?

        public struct EvidenceItem: Decodable, Equatable, Sendable {
            public let ref: String
            public let detail: String?
        }
    }
}

/// Blocker reference: another ticket blocking this card.
public struct BlockerInfo: Decodable, Equatable, Sendable {
    public let number: Int
    public let repo: String?
    public let title: String?
}

/// A tag on a card, with optional kind (used for coloring and filtering).
public struct Tag: Decodable, Equatable, Identifiable, Sendable {
    public let name: String
    public let kind: Kind

    public var id: String { name }

    public enum Kind: String, Decodable, Sendable {
        case priority, severity, status, other

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .other
        }
    }
}

/// A pull request linked to a card, with metadata about review status.
public struct PRLink: Decodable, Equatable, Identifiable, Sendable {
    public let number: Int
    public let title: String
    public let url: String
    public let isDraft: Bool
    public let hasDevEvidence: Bool

    public var id: Int { number }

    enum CodingKeys: String, CodingKey {
        case number, title, url
        case isDraft = "is_draft"
        case hasDevEvidence = "has_dev_evidence"
    }
}

/// Summary of related tickets in another project (shown in the "other projects" section).
public struct OtherProjectSummary: Decodable, Equatable, Identifiable, Sendable {
    public let projectId: String
    public let count: Int
    public let repo: String?
    public let name: String?

    public var id: String { projectId }

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case count, repo, name
    }
}
