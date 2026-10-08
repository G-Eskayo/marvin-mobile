import Foundation
import Testing
@testable import MarvinCore

@Suite struct ConnectionStateTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func startsUnknownWithNoLastReached() {
        let state = ConnectionState()
        #expect(state.status == .unknown)
        #expect(state.lastReached == nil)
    }

    @Test func aSuccessfulProbeGoesOnlineAndStampsTheTime() {
        var state = ConnectionState()
        state.record(.reached, at: t0)
        #expect(state.status == .online)
        #expect(state.lastReached == t0)
    }

    @Test func anUnreachableProbeGoesOfflineButKeepsTheLastReachedTime() {
        var state = ConnectionState()
        state.record(.reached, at: t0)
        state.record(.unreachable, at: t0.addingTimeInterval(60))
        #expect(state.status == .offline)
        #expect(state.lastReached == t0)
    }

    // ADR 0043: the backend answers 403 to any device not on the allowlist.
    // That's a setup problem to show plainly, not "offline".
    @Test func aRejectionIsItsOwnState() {
        var state = ConnectionState()
        state.record(.rejected, at: t0)
        #expect(state.status == .notAllowlisted)
        #expect(state.lastReached == nil)
    }
}
