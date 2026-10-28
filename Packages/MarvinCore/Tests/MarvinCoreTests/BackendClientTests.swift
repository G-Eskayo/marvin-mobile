import Foundation
import Testing
@testable import MarvinCore

// Fakes the one true boundary (the network) with a URLProtocol stub; everything
// else goes through BackendClient's public interface.
final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBody ?? request.httpBodyStream.map(Self.drain)
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let (code, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    static func drain(_ stream: InputStream) -> Data {
        stream.open(); defer { stream.close() }
        var data = Data(); var buf = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buf, maxLength: buf.count)
            if n <= 0 { break }
            data.append(buf, count: n)
        }
        return data
    }
}

// Shared static stub state, so these run one at a time.
@Suite(.serialized) struct BackendClientTests {
    let client: BackendClient

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        client = BackendClient(baseURL: URL(string: "http://100.80.189.85:7880")!, session: URLSession(configuration: config))
        StubProtocol.handler = nil
    }

    @Test func probeReportsReachedOnAnUpStatus() async {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"status":"up","uptimeSeconds":12,"version":"1.0.0"}"#.utf8)) }
        #expect(await client.probe() == .reached)
        #expect(StubProtocol.lastRequest?.url?.path == "/status")
    }

    @Test func probeReportsRejectedOnA403() async {
        StubProtocol.handler = { _ in (403, Data(#"{"ok":false,"error":"not allowlisted"}"#.utf8)) }
        #expect(await client.probe() == .rejected)
    }

    @Test func probeReportsUnreachableWhenTheConnectionFails() async {
        #expect(await client.probe() == .unreachable)
    }

    @Test func activityDecodesTicketRows() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":[{"number":160,"repo":"G-Eskayo/marvin","key":"g-eskayo/marvin#160",
            "currentStage":"merge","currentStatus":"done","costUsd":1.25,"failed":false,
            "title":"Mobile backend: write actions","eventCount":9,"lastEventAt":"2026-10-08T14:54:08Z","isLiveNow":false}]}
            """.utf8)) }
        let rows = try await client.activity()
        #expect(rows.count == 1)
        #expect(rows[0].number == 160)
        #expect(rows[0].title == "Mobile backend: write actions")
        #expect(rows[0].currentStage == "merge")
        #expect(rows[0].isLiveNow == false)
    }

    @Test func activityToleratesMissingOptionalFields() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":[{"number":7,"repo":"G-Eskayo/marvin","key":"k"}]}"#.utf8)) }
        let rows = try await client.activity()
        #expect(rows[0].title == nil)
        #expect(rows[0].failed == false)
    }

    // Shape of ~/.claude/logs/health-status.json as health_checks.py writes it (2026-10-08).
    @Test func healthDecodesOverallAndChecks() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":{"generated_at":"2026-10-08T17:54:00Z","overall":"red","coverage":null,"anomaly":null,
            "checks":[{"id":"cron:code-sync-push","label":"Cron job: code-sync-push","severity":"red",
            "detail":"2 failure indicator(s) since last check","checked_at":"2026-10-08T17:54:00Z","value":null},
            {"id":"token:oauth-token","label":"Auth token: oauth-token","severity":"green","detail":"present"}]}}
            """.utf8)) }
        let health = try await client.health()
        #expect(health.overall == .red)
        #expect(health.checks.first?.label == "Cron job: code-sync-push")
        #expect(health.checks.first?.severity == .red)
        #expect(health.checks.first?.detail == "2 failure indicator(s) since last check")
        #expect(health.count(.red) == 1)
        #expect(health.count(.green) == 1)
    }

    @Test func healthWithNoRunYetIsGrey() async throws {
        // health.js's EMPTY_STATUS when the monitor has never written a file.
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":{"generated_at":null,"overall":"grey","coverage":null,"anomaly":null,"checks":[]}}"#.utf8)) }
        let health = try await client.health()
        #expect(health.overall == .grey)
        #expect(health.checks.isEmpty)
    }

    @Test func anUnknownSeverityDecodesAsGreyRatherThanFailing() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":{"overall":"purple","checks":[{"id":"x","label":"X","severity":"purple"}]}}"#.utf8)) }
        let health = try await client.health()
        #expect(health.overall == .grey)
        #expect(health.checks[0].severity == .grey)
    }

    @Test func aBackendErrorSurfacesItsMessage() async {
        StubProtocol.handler = { _ in (500, Data(#"{"ok":false,"error":"registry unreadable"}"#.utf8)) }
        await #expect(throws: BackendError.server("registry unreadable")) { try await client.boards() }
    }

    @Test func threadDecodesMessagesOldestFirst() async throws {
        // The backend pages newest-first; the app shows oldest-first.
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":[
              {"id":"m2","source":"chat","role":"assistant","text":"Morning, Gil.","sessionId":"s1","ts":2000},
              {"id":"m1","source":"chat","role":"user","text":"Good morning","sessionId":"s1","ts":1000}]}
            """.utf8)) }
        let messages = try await client.thread()
        #expect(messages.map(\.id) == ["m1", "m2"])
        #expect(messages[1].role == .assistant)
    }

    @Test func chatPostsTheMessageAndStreamsEvents() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"type":"session","sessionId":"s1"}
            {"type":"text","text":"Morning"}
            {"type":"result","text":"Morning","sessionId":"s1","isError":false}

            """.utf8)) }
        var events: [ChatEvent] = []
        for try await event in client.chat("Good morning") { events.append(event) }
        #expect(events == [.session(id: "s1"), .text("Morning"), .result(text: "Morning", sessionId: "s1", isError: false)])
        #expect(StubProtocol.lastRequest?.httpMethod == "POST")
        #expect(StubProtocol.lastRequest?.url?.path == "/chat")
        let body = try JSONSerialization.jsonObject(with: StubProtocol.lastBody ?? Data()) as? [String: String]
        #expect(body == ["message": "Good morning"])
    }

    @Test func boardDetailDecodesColumnsAndCards() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":{"repo":"G-Eskayo/marvin","name":"marvin","columns":[
            {"id":"col-1","name":"To Do","cards":[
            {"id":"c1","number":272,"title":"Mobile backend: board endpoints","repo":"G-Eskayo/marvin","assignee":"Gil"}
            ]},
            {"id":"col-2","name":"In Progress","cards":[]}
            ],"other_projects":[
            {"id":"proj-1","repo":"G-Eskayo/clarity-captions","name":"clarity-captions","card_count":3}
            ]}}
            """.utf8)) }
        let detail = try await client.boardDetail(repo: "G-Eskayo/marvin")
        #expect(detail.repo == "G-Eskayo/marvin")
        #expect(detail.columns?.count == 2)
        #expect(detail.columns?[0].name == "To Do")
        #expect(detail.columns?[0].cards?.first?.title == "Mobile backend: board endpoints")
        #expect(detail.otherProjects?.count == 1)
        #expect(detail.otherProjects?.first?.name == "clarity-captions")
    }

    @Test func boardDetailToleratesMissingCards() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":{"repo":"G-Eskayo/marvin","name":"marvin","columns":[{"id":"col-1","name":"To Do"}]}}"#.utf8)) }
        let detail = try await client.boardDetail(repo: "G-Eskayo/marvin")
        #expect(detail.columns?[0].cards == nil)
    }

    @Test func timelineDecodesEvents() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":[
            {"id":"evt-1","type":"comment","actor":"Gil","body":"Looks good","created_at":"2026-10-08T18:00:00Z"},
            {"id":"evt-2","type":"state-change","actor":"MARVIN","body":"stage: executing → done","created_at":"2026-10-08T17:55:00Z"}
            ]}
            """.utf8)) }
        let events = try await client.timeline(repo: "G-Eskayo/marvin", number: 272)
        #expect(events.count == 2)
        #expect(events[0].type == "comment")
        #expect(events[0].body == "Looks good")
        #expect(events[1].type == "state-change")
    }

    @Test func timelineToleratesMissingOptionalFields() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":[{"id":"e1","type":"opened"}]}"#.utf8)) }
        let events = try await client.timeline(repo: "G-Eskayo/marvin", number: 1)
        #expect(events[0].actor == nil)
        #expect(events[0].body == nil)
    }

    @Test func relationsDecodesRelatedPRsAndDocs() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":{"repo":"G-Eskayo/marvin","number":272,"related_prs":[
            {"id":"pr-1","number":1234,"title":"Implement board endpoints","repo":"G-Eskayo/marvin-backend","state":"open"}
            ],"related_docs":[
            {"id":"doc-1","path":"docs/adr/0041-mobile-endpoints.md","label":"ADR 0041"}
            ]}}
            """.utf8)) }
        let relations = try await client.relations(repo: "G-Eskayo/marvin", number: 272)
        #expect(relations.number == 272)
        #expect(relations.relatedPRs?.count == 1)
        #expect(relations.relatedPRs?.first?.title == "Implement board endpoints")
        #expect(relations.relatedDocs?.count == 1)
        #expect(relations.relatedDocs?.first?.label == "ADR 0041")
    }

    @Test func relationsToleratesEmptyLists() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":{"repo":"G-Eskayo/marvin","number":272}}"#.utf8)) }
        let relations = try await client.relations(repo: "G-Eskayo/marvin", number: 272)
        #expect(relations.relatedPRs == nil)
        #expect(relations.relatedDocs == nil)
    }

    @Test func activityOverviewDecodesProjectsWithQueues() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":{"projects":[
            {"id":"proj-1","repo":"G-Eskayo/marvin","needs_you":true,"waiting_count":2},
            {"id":"proj-2","repo":"G-Eskayo/clarity-captions","needs_you":false,"waiting_count":0}
            ]}}
            """.utf8)) }
        let overview = try await client.activityOverview()
        #expect(overview.projects?.count == 2)
        #expect(overview.projects?[0].needsYou == true)
        #expect(overview.projects?[0].waitingCount == 2)
        #expect(overview.projects?[1].needsYou == false)
    }

    @Test func activityOverviewToleratesMissingProjects() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":{}}"#.utf8)) }
        let overview = try await client.activityOverview()
        #expect(overview.projects == nil)
    }

    @Test func queueDecodesEntries() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":{"entries":[
            {"id":"q1","number":272,"repo":"G-Eskayo/marvin","title":"Mobile backend: board endpoints","stage":"executing"},
            {"id":"q2","number":25,"repo":"G-Eskayo/clarity-captions","title":"Latency baseline","stage":"waiting"}
            ],"total_waiting":5}}
            """.utf8)) }
        let queue = try await client.queue()
        #expect(queue.entries?.count == 2)
        #expect(queue.entries?[0].number == 272)
        #expect(queue.entries?[1].stage == "waiting")
        #expect(queue.totalWaiting == 5)
    }

    @Test func queueToleratesEmptyEntries() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":{"entries":[],"total_waiting":0}}"#.utf8)) }
        let queue = try await client.queue()
        #expect(queue.entries?.isEmpty == true)
        #expect(queue.totalWaiting == 0)
    }

    @Test func replyToTicketPostsAndGetsConfirmation() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":{"success":true,"reply_id":"reply-123","message":"Reply posted"}}"#.utf8)) }
        let result = try await client.replyToTicket(repo: "G-Eskayo/marvin", number: 272, body: "Looks good to me")
        #expect(result.success == true)
        #expect(result.replyId == "reply-123")
        #expect(StubProtocol.lastRequest?.httpMethod == "POST")
        #expect(StubProtocol.lastRequest?.url?.path == "/reply/G-Eskayo/marvin/272")
        let body = try JSONSerialization.jsonObject(with: StubProtocol.lastBody ?? Data()) as? [String: String]
        #expect(body?["body"] == "Looks good to me")
    }

    @Test func replyToTicketHandles403() async {
        StubProtocol.handler = { _ in (403, Data(#"{"ok":false,"error":"not allowlisted"}"#.utf8)) }
        await #expect(throws: BackendError.notAllowlisted) { try await client.replyToTicket(repo: "G-Eskayo/marvin", number: 272, body: "test") }
    }

    @Test func replyToTicketHandlesServerError() async {
        StubProtocol.handler = { _ in (500, Data(#"{"ok":false,"error":"database error"}"#.utf8)) }
        await #expect(throws: BackendError.server("database error")) { try await client.replyToTicket(repo: "G-Eskayo/marvin", number: 272, body: "test") }
    }
}
