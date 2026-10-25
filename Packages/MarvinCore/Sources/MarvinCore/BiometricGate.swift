import Foundation
import LocalAuthentication

@preconcurrency import LocalAuthentication

public enum BiometricError: Error, Equatable {
    case notAvailable
    case userCancelled
    case failed(String)
}

/// Wraps a biometric-gated action: authentication check before execution.
public struct BiometricGate: Sendable {
    private let authenticator: any BiometricAuthenticating

    public init(authenticator: any BiometricAuthenticating) {
        self.authenticator = authenticator
    }

    public func authorize<T>(action: @escaping () async throws -> T) async -> Result<T, BiometricError> {
        do {
            try await authenticator.authenticate()
            let result = try await action()
            return .success(result)
        } catch let error as BiometricError {
            return .failure(error)
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }
}

public protocol BiometricAuthenticating: Sendable {
    func authenticate() async throws
}

public final class FaceIDAuthenticator: BiometricAuthenticating {
    nonisolated(unsafe) private let context = LAContext()

    public init() {}

    public func authenticate() async throws {
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        guard available else { throw BiometricError.notAvailable }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Confirm this action with Face ID"
            )
            guard success else { throw BiometricError.userCancelled }
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .userFallback:
                throw BiometricError.userCancelled
            default:
                throw BiometricError.failed(error.localizedDescription)
            }
        }
    }
}
