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

    @Test func servesOpenPRsInMrList() async throws {
        let prs = try await client.mrList()
        #expect(prs.count == 2)
        #expect(prs[0].number == 42)
        #expect(prs[0].title == "Add MR Review to mobile")
        #expect(prs.allSatisfy { !$0.url.isEmpty })
    }

    @Test func servesMrReviewStatus() async throws {
        let status = try await client.mrReviewStatus(url: "https://github.com/G-Eskayo/marvin/pull/42")
        #expect(status.status == .open)
    }

    @Test func servesMrTicketContext() async throws {
        let context = try await client.mrTicketContext(ref: "marvin#152", repo: "G-Eskayo/marvin")
        #expect(context.number == 152)
        #expect(context.title == "Mobile: MR Review feature")
    }
}
