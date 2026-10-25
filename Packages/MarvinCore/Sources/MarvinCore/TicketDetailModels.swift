import Foundation

public struct TimelineEvent: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let timestamp: String
    public let eventType: String
    public let description: String
    public let costUsd: Double?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, eventType, description
        case costUsd = "cost_usd"
    }

    public init(id: String, timestamp: String, eventType: String, description: String, costUsd: Double? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.description = description
        self.costUsd = costUsd
    }
}

public struct TicketRelations: Decodable, Equatable, Sendable {
    public let relatedTickets: [RelatedItem]
    public let relatedPRs: [RelatedItem]
    public let relatedDocs: [RelatedDoc]

    public init(relatedTickets: [RelatedItem]? = nil, relatedPRs: [RelatedItem]? = nil, relatedDocs: [RelatedDoc]? = nil) {
        self.relatedTickets = relatedTickets ?? []
        self.relatedPRs = relatedPRs ?? []
        self.relatedDocs = relatedDocs ?? []
    }

    enum CodingKeys: String, CodingKey {
        case relatedTickets = "related_tickets"
        case relatedPRs = "related_prs"
        case relatedDocs = "related_docs"
    }
}

public struct RelatedItem: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let repo: String
    public let state: String?

    public init(id: String, number: Int, title: String, repo: String, state: String? = nil) {
        self.id = id
        self.number = number
        self.title = title
        self.repo = repo
        self.state = state
    }
}

public struct RelatedDoc: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let path: String
    public let title: String

    public init(id: String, path: String, title: String) {
        self.id = id
        self.path = path
        self.title = title
    }
}

public struct ProjectContext: Decodable, Equatable, Sendable {
    public let repo: String
    public let name: String

    public init(repo: String, name: String) {
        self.repo = repo
        self.name = name
    }
}

public struct TicketReplyResult: Decodable, Equatable, Sendable {
    public let ok: Bool
    public let message: String?
    public let warning: String?

    public init(ok: Bool, message: String? = nil, warning: String? = nil) {
        self.ok = ok
        self.message = message
        self.warning = warning
    }
}

public struct ReplyPlan: Equatable, Sendable {
    public let labels: [String]
    public let state: String?
    public let effectText: String

    public init(labels: [String], state: String?, effectText: String) {
        self.labels = labels
        self.state = state
        self.effectText = effectText
    }
}

extension ReplyPlan {
    public static func planReply(labels: [String], state: String?) -> ReplyPlan {
        var effects: [String] = []
        if !labels.isEmpty {
            effects.append("add labels: \(labels.joined(separator: ", "))")
        }
        if let state {
            effects.append("set state to \(state)")
        }
        let effectText = effects.isEmpty ? "no changes" : effects.joined(separator: "; ")
        return ReplyPlan(labels: labels, state: state, effectText: effectText)
    }
}
