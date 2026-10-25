import Foundation
import LocalAuthentication

public enum BiometricError: Error, Equatable {
    case notAvailable
    case userCancelled
    case authenticationFailed(String)
}

public struct ConfirmedAction<T: Sendable>: Sendable, Equatable where T: Equatable {
    public let value: T
    public let confirmedAt: Date

    public init(value: T, confirmedAt: Date = .now) {
        self.value = value
        self.confirmedAt = confirmedAt
    }
}

public protocol BiometricAuthenticator: Sendable {
    func authenticate(reason: String) async throws -> Bool
}

public struct FaceIDAuthenticator: BiometricAuthenticator {
    public init() {}

    public func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error {
                throw BiometricError.authenticationFailed(error.localizedDescription)
            }
            throw BiometricError.notAvailable
        }

        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .userFallback:
                throw BiometricError.userCancelled
            default:
                throw BiometricError.authenticationFailed(error.localizedDescription)
            }
        }
    }
}

public struct DemoAuthenticator: BiometricAuthenticator {
    public static let shared = DemoAuthenticator()

    public init() {}

    public func authenticate(reason: String) async throws -> Bool {
        try? await Task.sleep(for: .milliseconds(500))
        return true
    }
}
