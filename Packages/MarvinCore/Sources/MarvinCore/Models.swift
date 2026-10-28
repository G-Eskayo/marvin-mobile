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

// MARK: - MR Review Models

/// Lenient decoder wrapper: if decoding fails, return nil instead of throwing.
public struct FailableDecodable<T: Decodable & Sendable>: Decodable, Sendable {
    public let value: T?

    public init(from decoder: Decoder) throws {
        do {
            value = try T(from: decoder)
        } catch {
            value = nil
        }
    }
}

/// A reference to a ticket (repo#number).
public struct TicketRef: Decodable, Identifiable, Equatable, Sendable {
    public let number: Int
    public let repo: String
    public let key: String

    public var id: String { key }

    enum CodingKeys: String, CodingKey { case number, repo, key }
}

/// Summary of a ticket used in MR listings.
public struct TicketSummary: Decodable, Identifiable, Equatable, Sendable {
    public let number: Int
    public let repo: String
    public let key: String
    public let title: String?

    public var id: String { key }

    enum CodingKeys: String, CodingKey { case number, repo, key, title }
}

/// Full context for a ticket fetched on demand by MRDetailView.
public struct TicketContext: Decodable, Equatable, Sendable {
    public let number: Int
    public let repo: String
    public let key: String
    public let title: String?
    public let description: String?
    public let status: String?
    public let stage: String?

    enum CodingKeys: String, CodingKey {
        case number, repo, key, title, description, status, stage
    }
}

/// Status of a merge request from the backend.
public enum MRStatus: String, Decodable, Sendable {
    case draft, readyToMerge, checksRunning, checksRequired, needsRework, waitingForAutomerge
}

/// Review status summary for the tab badge.
public struct MRReviewStatus: Decodable, Equatable, Sendable {
    public let openCount: Int
    public let draftCount: Int
    public let readyCount: Int

    enum CodingKeys: String, CodingKey {
        case openCount = "open_count"
        case draftCount = "draft_count"
        case readyCount = "ready_count"
    }
}

/// Reason for denying an MR.
public enum DenyReason: String, Codable, Sendable, CaseIterable {
    case checksNeeded = "checks_needed"
    case needsRework = "needs_rework"
    case rebasing = "rebasing"
    case missingContext = "missing_context"

    public var label: String {
        switch self {
        case .checksNeeded: "Checks needed"
        case .needsRework: "Needs rework"
        case .rebasing: "Rebasing"
        case .missingContext: "Missing context"
        }
    }
}

/// Action payload for denying an MR.
public struct MRDenyAction: Codable, Sendable {
    public let prNumber: Int
    public let reasons: [DenyReason]
    public let comment: String

    enum CodingKeys: String, CodingKey {
        case prNumber = "pr_number"
        case reasons, comment
    }

    public init(prNumber: Int, reasons: [DenyReason], comment: String) {
        self.prNumber = prNumber
        self.reasons = reasons
        self.comment = comment
    }
}

/// Result of approving an MR.
public struct MRApproveResult: Codable, Equatable, Sendable {
    public let prNumber: Int
    public let merged: Bool
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case prNumber = "pr_number"
        case merged, message
    }
}

/// Result of denying an MR.
public struct MRDenyResult: Codable, Equatable, Sendable {
    public let prNumber: Int
    public let recorded: Bool
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case prNumber = "pr_number"
        case recorded, message
    }
}

/// A pull request in the MR Review list. `severity` is computed from status;
/// raw check/rework/evidence/rebase/autoMerge fields are kept as-is (not decoded to avoid
/// brittleness against future backend changes).
public struct PullRequest: Decodable, Identifiable, Equatable, Sendable {
    public let number: Int
    public let repo: String
    public let key: String
    public let title: String?
    public let status: MRStatus
    public let ticket: TicketSummary?
    public let author: String?
    public let createdAt: String?
    public let url: String?

    public var id: String { key }

    public var severity: Severity {
        switch status {
        case .draft: .grey
        case .readyToMerge: .green
        case .checksRunning: .yellow
        case .checksRequired, .needsRework: .red
        case .waitingForAutomerge: .yellow
        }
    }

    public init(
        number: Int, repo: String, key: String, title: String?, status: MRStatus,
        ticket: TicketSummary?, author: String?, createdAt: String?, url: String?
    ) {
        self.number = number
        self.repo = repo
        self.key = key
        self.title = title
        self.status = status
        self.ticket = ticket
        self.author = author
        self.createdAt = createdAt
        self.url = url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decode(Int.self, forKey: .number)
        repo = try container.decode(String.self, forKey: .repo)
        key = try container.decode(String.self, forKey: .key)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        status = try container.decode(MRStatus.self, forKey: .status)
        ticket = try container.decodeIfPresent(TicketSummary.self, forKey: .ticket)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        url = try container.decodeIfPresent(String.self, forKey: .url)
    }

    enum CodingKeys: String, CodingKey {
        case number, repo, key, title, status, ticket, author, url
        case createdAt = "created_at"
    }
}
