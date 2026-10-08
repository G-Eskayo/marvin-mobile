import Foundation
import Testing
@testable import MarvinCore

// Demo mode: the app's `-demo` launch flag points BackendClient at a built-in fake
// backend, so simulator screenshots are repeatable and need no Mac or allowlist.
@Suite struct DemoBackendTests {
    let client = DemoBackend.client(replyDelay: .zero)

    @Test func isReachable() async {
        #expect(await client.probe() == .reached)
    }

    @Test func servesActivityWithTitlesNeverBareNumbers() async throws {
        let rows = try await client.activity()
        #expect(!rows.isEmpty)
        #expect(rows.allSatisfy { ($0.title ?? "").isEmpty == false })
    }

    @Test func servesHealthWithEverySeverity() async throws {
        let health = try await client.health()
        #expect(health.count(.red) > 0)
        #expect(health.count(.yellow) > 0)
        #expect(health.count(.green) > 0)
    }

    @Test func servesBoardsAndAThread() async throws {
        #expect(try await client.boards().isEmpty == false)
        let thread = try await client.thread()
        #expect(thread.count >= 2)
        #expect(thread.first?.role == .user)
    }

    @Test func streamsAChatReplyEndingInAResult() async throws {
        var reply = ReplyAccumulator()
        for try await event in client.chat("What's going on today?") { reply.apply(event) }
        #expect(reply.isFinished)
        #expect(reply.error == nil)
        #expect(!reply.text.isEmpty)
    }
}
