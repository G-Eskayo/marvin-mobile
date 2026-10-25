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

    @Test func boardDetailDecodesBoardColumns() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":{"repo":"G-Eskayo/marvin","columns":[
             {"id":"waiting","label":"Waiting for input","cards":[
              {"id":"1","number":201,"title":"Set up sync","blockedBy":[],"evidence":[],"tags":[],"prLinks":[]}
             ]},
             {"id":"done","label":"Done","cards":[]}
            ]}}
            """.utf8)) }
        let board = try await client.boardDetail(repo: "G-Eskayo/marvin")
        #expect(board.repo == "G-Eskayo/marvin")
        #expect(board.columns.count == 2)
        #expect(board.columns[0].label == "Waiting for input")
        #expect(board.columns[0].cards[0].number == 201)
    }

    @Test func timelineDecodesEvents() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":[
             {"id":"1","timestamp":"2026-10-08T10:00:00Z","eventType":"created","description":"Created"},
             {"id":"2","timestamp":"2026-10-08T11:00:00Z","eventType":"comment","description":"Commented","cost_usd":0.05}
            ]}
            """.utf8)) }
        let events = try await client.timeline(number: 272, repo: "G-Eskayo/marvin")
        #expect(events.count == 2)
        #expect(events[0].eventType == "created")
        #expect(events[1].costUsd == 0.05)
    }

    @Test func relationsDecodesRelatedItems() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":{"related_tickets":[
             {"id":"r1","number":201,"title":"Setup","repo":"G-Eskayo/marvin","state":"waiting"}
            ],"related_prs":[
             {"id":"p1","number":308,"title":"Activity","repo":"G-Eskayo/marvin-mobile","state":"open"}
            ],"related_docs":[
             {"id":"d1","path":"ADR.md","title":"ADR 0042"}
            ]}}
            """.utf8)) }
        let relations = try await client.relationsForTicket(repo: "G-Eskayo/marvin", number: 272)
        #expect(relations.relatedTickets.count == 1)
        #expect(relations.relatedTickets[0].title == "Setup")
        #expect(relations.relatedPRs[0].state == "open")
        #expect(relations.relatedDocs[0].path == "ADR.md")
    }

    @Test func relationsContextDecodesProject() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":{"repo":"G-Eskayo/marvin","name":"MARVIN"}}"#.utf8)) }
        let context = try await client.relationsContext(project: "G-Eskayo/marvin")
        #expect(context.name == "MARVIN")
        #expect(context.repo == "G-Eskayo/marvin")
    }

    @Test func queueDecodesRows() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":{"queue":[
             {"id":"q1","number":261,"title":"Map publishes","repo":"G-Eskayo/marvin","state":"waiting","waiting_for":"approval"}
            ],"error":null,"running":1}}
            """.utf8)) }
        let response = try await client.queue()
        #expect(response.queue.count == 1)
        #expect(response.queue[0].waitingFor == "approval")
        #expect(response.running == 1)
    }

    @Test func replyToTicketSendsBodyAndConfirmedFlag() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":{"ok":true,"message":"Sent","warning":null}}"#.utf8)) }
        let result = try await client.replyToTicket(repo: "G-Eskayo/marvin", number: 272, body: "Looks good")
        #expect(result.ok == true)
        #expect(result.message == "Sent")
        #expect(StubProtocol.lastRequest?.url?.path == "/boards/ticket/reply")
        #expect(StubProtocol.lastRequest?.httpMethod == "POST")
        let body = try JSONSerialization.jsonObject(with: StubProtocol.lastBody ?? Data()) as? [String: Any]
        #expect(body?["body"] as? String == "Looks good")
        #expect(body?["confirmed"] as? Bool == true)
    }
}
