import Foundation

/// What one attempt to reach the backend found.
public enum ProbeResult: Equatable, Sendable {
    case reached
    case unreachable
    /// The backend answered but refused this device (not on the allowlist, ADR 0043).
    case rejected
}

/// Whether the backend is reachable, and when it last was, for the stale-data banner.
public struct ConnectionState: Equatable, Sendable {
    public enum Status: Equatable, Sendable { case unknown, online, offline, notAllowlisted }

    public private(set) var status: Status = .unknown
    public private(set) var lastReached: Date?

    public init() {}

    public mutating func record(_ result: ProbeResult, at time: Date) {
        switch result {
        case .reached:
            status = .online
            lastReached = time
        case .unreachable:
            status = .offline
        case .rejected:
            status = .notAllowlisted
        }
    }
}
