import Foundation

public struct BoardDetail: Decodable, Equatable, Sendable {
    public let repo: String
    public let columns: [BoardColumn]

    public init(repo: String, columns: [BoardColumn]) {
        self.repo = repo
        self.columns = columns
    }
}

public struct BoardColumn: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let cards: [Card]

    public init(id: String, label: String, cards: [Card]) {
        self.id = id
        self.label = label
        self.cards = cards
    }
}

public struct Card: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let reason: String?
    public let progress: Progress?
    public let evidence: [Evidence]
    public let blockedBy: [String]
    public let tags: [Tag]
    public let prLinks: [PRLink]

    public init(id: String, number: Int, title: String, reason: String? = nil, progress: Progress? = nil,
                evidence: [Evidence] = [], blockedBy: [String] = [], tags: [Tag] = [], prLinks: [PRLink] = []) {
        self.id = id
        self.number = number
        self.title = title
        self.reason = reason
        self.progress = progress
        self.evidence = evidence
        self.blockedBy = blockedBy
        self.tags = tags
        self.prLinks = prLinks
    }

    public struct Progress: Decodable, Equatable, Sendable {
        public let percent: Int
        public let numerator: Int
        public let denominator: Int

        public init(percent: Int, numerator: Int, denominator: Int) {
            self.percent = percent
            self.numerator = numerator
            self.denominator = denominator
        }
    }

    public struct Evidence: Decodable, Equatable, Identifiable, Sendable {
        public let id: String
        public let label: String
        public let url: String?

        public init(id: String, label: String, url: String? = nil) {
            self.id = id
            self.label = label
            self.url = url
        }
    }
}

public struct Tag: Decodable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Decodable, Sendable {
        case blocker, milestone, review, inProgress, done
    }

    public let id: String
    public let label: String
    public let kind: Kind

    public init(id: String, label: String, kind: Kind) {
        self.id = id
        self.label = label
        self.kind = kind
    }
}

public struct PRLink: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let repo: String
    public let hasDevEvidence: Bool

    public init(id: String, number: Int, title: String, repo: String, hasDevEvidence: Bool) {
        self.id = id
        self.number = number
        self.title = title
        self.repo = repo
        self.hasDevEvidence = hasDevEvidence
    }
}
