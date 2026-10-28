import Foundation
import LocalAuthentication

/// Error from ticket reply operations.
public enum TicketActionError: Error, Equatable {
    case biometricFailed(String)
    case networkError(String)
    case cancelled
}

extension TicketActionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .biometricFailed(let msg): "Face ID failed: \(msg)"
        case .networkError(let msg): "Couldn't post reply: \(msg)"
        case .cancelled: "Reply cancelled"
        }
    }
}

/// Authenticates ticket actions (replies) with Face ID / Touch ID.
public protocol BiometricAuthenticator: Sendable {
    func authenticateAndReply(repo: String, number: Int, body: String, using client: BackendClient) async throws -> TicketReplyResult
}

/// Live biometric authenticator using LocalAuthentication (Face ID / Touch ID).
public actor LAContextAuthenticator: BiometricAuthenticator {
    private let context = LAContext()

    public init() {}

    public func authenticateAndReply(repo: String, number: Int, body: String, using client: BackendClient) async throws -> TicketReplyResult {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw TicketActionError.biometricFailed(error?.localizedDescription ?? "Biometrics unavailable")
        }

        let reason = "Approve your reply to \(repo)#\(number)"
        guard (try? await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)) == true else {
            throw TicketActionError.cancelled
        }

        do {
            return try await client.replyToTicket(repo: repo, number: number, body: body)
        } catch let error as BackendError {
            throw TicketActionError.networkError(error.localizedDescription)
        }
    }
}

/// Demo authenticator that always succeeds (for simulator screenshots).
public actor DemoAuthenticator: BiometricAuthenticator {
    public init() {}

    public func authenticateAndReply(repo: String, number: Int, body: String, using client: BackendClient) async throws -> TicketReplyResult {
        try await Task.sleep(nanoseconds: 600_000_000)
        do {
            return try await client.replyToTicket(repo: repo, number: number, body: body)
        } catch let error as BackendError {
            throw TicketActionError.networkError(error.localizedDescription)
        }
    }
}
