import Foundation

/// `GET /queue`: The ticket dispatch queue state.
public struct QueueResponse: Decodable, Equatable, Sendable {
    public let queue: [QueueRow]
    public let running: [RunningRow]
    public let error: String?
}

/// One ticket waiting in the queue.
public struct QueueRow: Decodable, Equatable, Sendable {
    public let position: Int
    public let repo: String
    public let project: String
    public let number: Int
    public let title: String
    public let priority: Int
    public let score: Double
    public let machines: [String]
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case position, repo, project, number, title, priority, score, machines
        case createdAt = "created_at"
    }
}

/// One ticket currently being executed.
public struct RunningRow: Decodable, Equatable, Sendable {
    public let repo: String
    public let project: String
    public let number: Int
    public let title: String
    public let machine: String
}
