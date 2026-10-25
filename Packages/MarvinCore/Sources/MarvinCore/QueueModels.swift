import Foundation

public struct QueueResponse: Decodable, Equatable, Sendable {
    public let queue: [QueueRow]
    public let error: String?
    public let running: Int?

    public init(queue: [QueueRow] = [], error: String? = nil, running: Int? = nil) {
        self.queue = queue
        self.error = error
        self.running = running
    }
}

public struct QueueRow: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let repo: String
    public let state: String
    public let waitingFor: String?

    enum CodingKeys: String, CodingKey {
        case id, number, title, repo, state
        case waitingFor = "waiting_for"
    }

    public init(id: String, number: Int, title: String, repo: String, state: String, waitingFor: String? = nil) {
        self.id = id
        self.number = number
        self.title = title
        self.repo = repo
        self.state = state
        self.waitingFor = waitingFor
    }
}
