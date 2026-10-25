import Foundation
import Testing
@testable import MarvinCore

@Suite struct BiometricGateTests {
    // 17. FaceIDAuthenticator instantiates and conforms to protocol
    @Test func faceIDAuthenticatorInstantiates() {
        let auth = FaceIDAuthenticator()
        let proto: BiometricAuthenticator = auth
        #expect(proto != nil)
    }

    // 18. ConfirmedAction stores value and confirmation timestamp
    @Test func confirmedActionStoresValueAndTimestamp() {
        let value = "approve"
        let now = Date.now
        let action = ConfirmedAction(value: value, confirmedAt: now)
        #expect(action.value == value)
        #expect(action.confirmedAt == now)
    }

    // 19. ConfirmedAction has default timestamp
    @Test func confirmedActionDefaultsTimestampToNow() {
        let action = ConfirmedAction(value: "test")
        let timeDiff = Date.now.timeIntervalSince(action.confirmedAt)
        #expect(timeDiff >= 0 && timeDiff < 1)
    }

    // 20. DemoAuthenticator always returns true
    @Test func demoAuthenticatorReturnsTrue() async throws {
        let auth = DemoAuthenticator()
        let result = try await auth.authenticate(reason: "Test")
        #expect(result == true)
    }
}
