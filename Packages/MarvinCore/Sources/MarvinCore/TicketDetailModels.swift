import Foundation

/// `GET /boards/ticket?repo=&number=`: Full detail of a single ticket.
public struct TicketDetail: Decodable, Equatable, Sendable {
    public let number: Int
    public let title: String
    public let body: String
    public let labels: [Label]
    public let url: String
    public let state: String
    public let comments: [Comment]
}

/// A label on a ticket (e.g., "bug", "priority:high", "waiting").
public struct Label: Decodable, Equatable, Identifiable, Sendable {
    public let name: String

    public var id: String { name }
}

/// One comment on a ticket.
public struct Comment: Decodable, Equatable, Identifiable, Sendable {
    public let body: String
    public let author: Author
    public let createdAt: String

    public var id: String { createdAt }

    enum CodingKeys: String, CodingKey {
        case body, author
        case createdAt = "created_at"
    }
}

/// Author of a comment.
public struct Author: Decodable, Equatable, Sendable {
    public let login: String
}

/// `GET /activity/timeline?number=&repo=`: Pipeline execution history for one ticket.
public struct TimelineEvent: Decodable, Equatable, Sendable {
    public let stage: String
    public let status: String
    public let timestamp: String
    public let detail: String?
    public let machine: String?
    public let costUsd: Double?

    enum CodingKeys: String, CodingKey {
        case stage, status, timestamp, detail, machine
        case costUsd = "cost_usd"
    }
}

/// `GET /relations/ticket?repo=&number=`: Related tickets, PRs, and documentation.
public struct TicketRelations: Decodable, Equatable, Sendable {
    public let tickets: [RelatedTicket]
    public let prs: [RelatedPR]
    public let docs: [RelatedDoc]
}

/// A related ticket (from the same or another project).
public struct RelatedTicket: Decodable, Equatable, Identifiable, Sendable {
    public let number: Int
    public let repo: String?
    public let title: String
    public let column: String?

    public var id: Int { number }
}

/// A related pull request.
public struct RelatedPR: Decodable, Equatable, Identifiable, Sendable {
    public let number: Int
    public let repo: String?
    public let title: String
    public let url: String
    public let isDraft: Bool

    public var id: Int { number }

    enum CodingKeys: String, CodingKey {
        case number, repo, title, url
        case isDraft = "is_draft"
    }
}

/// A related document (design, ADR, runbook, etc.).
public struct RelatedDoc: Decodable, Equatable, Identifiable, Sendable {
    public let title: String
    public let url: String?
    public let kind: String?

    public var id: String { title }
}

/// Result of posting a reply to a ticket.
public struct TicketReplyResult: Decodable, Equatable, Sendable {
    public let posted: Bool
    public let requeued: Bool
    public let effect: String?
    public let warning: String?
}

/// Plan for what a reply to a ticket would do (parsed from label and state changes).
public struct ReplyPlan: Equatable, Sendable {
    public let requeue: Bool
    public let add: [String]
    public let remove: [String]
    public let effect: String

    /// Calculates what a reply with the given labels and state would do, based on
    /// the logic from dashboard/src/lib/ticket_input.js's `planInput`.
    public static func planReply(labels: [String], state: String?) -> ReplyPlan {
        var add: [String] = []
        var remove: [String] = []
        var requeue = false
        var effect = "Updates labels"

        // If the user added or removed a "waiting:" label, the ticket requeues.
        let hasWaiting = labels.contains { $0.hasPrefix("waiting:") }
        if hasWaiting { requeue = true }

        // Parse the requested state change.
        if let newState = state {
            switch newState {
            case "open":
                remove.append("done")
                effect = "Reopens the ticket"
            case "done":
                add.append("done")
                effect = "Marks as done"
            default:
                break
            }
        }

        return ReplyPlan(requeue: requeue, add: add, remove: remove, effect: effect)
    }
}
