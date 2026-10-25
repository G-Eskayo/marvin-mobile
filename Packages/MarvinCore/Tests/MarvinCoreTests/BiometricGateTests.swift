import Foundation
import Testing
@testable import MarvinCore

final class MockBiometricAuthenticator: BiometricAuthenticating {
    nonisolated(unsafe) var shouldSucceed = true
    nonisolated(unsafe) var shouldThrow: BiometricError?

    nonisolated func authenticate() async throws {
        if let error = shouldThrow {
            throw error
        }
        guard shouldSucceed else {
            throw BiometricError.userCancelled
        }
    }
}

@Suite struct BiometricGateTests {
    let gate: BiometricGate
    let authenticator = MockBiometricAuthenticator()

    init() {
        self.gate = BiometricGate(authenticator: authenticator)
    }

    @Test func gateExecutesActionWhenAuthSucceeds() async {
        var executed = false
        authenticator.shouldSucceed = true
        let result = await gate.authorize(action: { executed = true; return "ok" })
        #expect(executed)
        #expect(result == .success("ok"))
    }

    @Test func gateBlocksActionWhenAuthFails() async {
        authenticator.shouldThrow = .userCancelled
        var executed = false
        let result = await gate.authorize(action: {
            executed = true
            return "ok"
        })
        #expect(!executed)
        #expect(result == .failure(.userCancelled))
    }

    @Test func gateReturnsNotAvailableWhenBiometricUnavailable() async {
        authenticator.shouldThrow = .notAvailable
        let result = await gate.authorize(action: { "ok" })
        #expect(result == .failure(.notAvailable))
    }

    @Test func gateConvertsCatchedErrorsToFailure() async {
        let error = BiometricError.failed("something broke")
        authenticator.shouldThrow = error
        let result = await gate.authorize(action: { "ok" })
        #expect(result == .failure(.failed("something broke")))
    }

    @Test func gatePreservesActionReturnValue() async {
        authenticator.shouldSucceed = true
        let result = await gate.authorize(action: { 42 })
        #expect(result == .success(42))
    }
}
