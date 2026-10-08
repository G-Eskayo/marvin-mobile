import Foundation
import Testing
@testable import MarvinCore

// Errors reach the screen through localizedDescription; they must read as plain
// sentences, never "MarvinCore.BackendError error 1."
@Suite struct BackendErrorTests {
    @Test func messagesArePlainSentences() {
        #expect(BackendError.notAllowlisted.localizedDescription == "This device isn't on MARVIN's allowlist.")
        #expect(BackendError.server("registry unreadable").localizedDescription == "MARVIN couldn't answer: registry unreadable")
        #expect(BackendError.badResponse.localizedDescription == "MARVIN sent a reply the app didn't understand.")
    }
}
