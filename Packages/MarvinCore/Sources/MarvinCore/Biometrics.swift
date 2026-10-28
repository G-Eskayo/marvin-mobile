import Foundation
import LocalAuthentication

/// Result of a biometric authentication attempt.
public enum BiometricOutcome: Equatable, Sendable {
    case success
    case userCancelled
    case notAvailable
    case failed(String)
}

/// Protocol for biometric authentication (testable, mockable).
public protocol BiometricGate: Sendable {
    /// Request Face ID authentication for MR Review actions.
    func authenticate() async -> BiometricOutcome
}

/// Actual Face ID implementation using LAContext.
public actor LAContextBiometricGate: BiometricGate {
    private let context = LAContext()

    public init() {}

    public func authenticate() async -> BiometricOutcome {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return error != nil ? .failed("Face ID unavailable") : .notAvailable
        }

        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Approve or deny this merge request"
            )
            return result ? .success : .userCancelled
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .invalidContext:
                return .userCancelled
            default:
                return .failed(error.localizedDescription)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
