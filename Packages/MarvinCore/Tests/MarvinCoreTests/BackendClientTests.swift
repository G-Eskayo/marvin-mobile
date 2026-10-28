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

    // Tests 6–8: MR endpoint methods
    @Test func mrListDecodesArray() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":[
             {"number":315,"repo":"G-Eskayo/marvin","key":"marvin#315","title":"MR Review","status":"readyToMerge",
              "ticket":{"number":3,"repo":"G-Eskayo/marvin-mobile","key":"m-mobile#3","title":"Tab"},
              "author":"user","created_at":"2026-10-23T14:22:11Z","url":"https://github.com/..."}
            ]}
            """.utf8)) }
        let prs = try await client.mrList()
        #expect(prs.count == 1)
        #expect(prs[0].number == 315)
    }

    @Test func mrReviewStatusDecodesOpenCount() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"ok":true,"data":{"open_count":5,"draft_count":1,"ready_count":2}}"#.utf8)) }
        let status = try await client.mrReviewStatus()
        #expect(status.openCount == 5)
    }

    @Test func mrTicketContextFetchesById() async throws {
        StubProtocol.handler = { req in
            #expect(req.url?.path == "/mr/ticket-context/315")
            return (200, Data(#"{"ok":true,"data":{"number":3,"repo":"G-Eskayo/marvin-mobile","key":"m-mobile#3","title":"MR Review tab","description":"","status":"active","stage":"executing"}}"#.utf8))
        }
        let ctx = try await client.mrTicketContext(prNumber: 315)
        #expect(ctx.number == 3)
    }

    // Tests 9–13: MR side-effecting methods
    @Test func mrApprovePostsAndDecodes() async throws {
        StubProtocol.handler = { req in
            #expect(req.httpMethod == "POST")
            #expect(req.url?.path == "/mr/approve")
            if let bodyData = req.httpBody,
               let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                #expect(json["pr_number"] as? Int == 315)
            }
            return (200, Data(#"{"ok":true,"data":{"pr_number":315,"merged":true,"message":"merged"}}"#.utf8))
        }
        let result = try await client.mrApprove(prNumber: 315)
        #expect(result.merged == true)
    }

    @Test func mrDenyPostsActionAndDecodes() async throws {
        StubProtocol.handler = { req in
            #expect(req.httpMethod == "POST")
            #expect(req.url?.path == "/mr/deny")
            return (200, Data(#"{"ok":true,"data":{"pr_number":309,"recorded":true,"message":"recorded"}}"#.utf8))
        }
        let action = MRDenyAction(prNumber: 309, reasons: [.checksNeeded], comment: "feedback")
        let result = try await client.mrDeny(action)
        #expect(result.recorded == true)
    }

    @Test func mrDenyEncodesReasonsArray() async throws {
        StubProtocol.handler = { req in
            if let bodyData = req.httpBody,
               let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
               let reasons = json["reasons"] as? [String] {
                #expect(reasons.count == 2)
                #expect(reasons.contains("checks_needed") == true)
                #expect(reasons.contains("rebasing") == true)
            }
            return (200, Data(#"{"ok":true,"data":{"pr_number":309,"recorded":true,"message":"ok"}}"#.utf8))
        }
        let action = MRDenyAction(prNumber: 309, reasons: [.checksNeeded, .rebasing], comment: "work needed")
        _ = try await client.mrDeny(action)
    }

    @Test func approveFailsOnNot2xx() async throws {
        StubProtocol.handler = { _ in (500, Data(#"{"ok":false,"error":"server error"}"#.utf8)) }
        await #expect(throws: BackendError.server("server error")) {
            try await client.mrApprove(prNumber: 315)
        }
    }

    @Test func denyFailsOn403() async throws {
        StubProtocol.handler = { _ in (403, Data()) }
        let action = MRDenyAction(prNumber: 309, reasons: [], comment: "")
        await #expect(throws: BackendError.notAllowlisted) {
            try await client.mrDeny(action)
        }
    }
}
