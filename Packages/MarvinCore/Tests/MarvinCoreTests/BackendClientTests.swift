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

    @Test func healthDecodesOverallAndChecks() async throws {
        StubProtocol.handler = { _ in (200, Data("""
            {"ok":true,"data":{"generated_at":"2026-10-08T15:00:00Z","overall":"amber","coverage":null,"anomaly":null,
            "checks":[{"name":"code-sync","status":"red","detail":"conflict in ~/.agents"}]}}
            """.utf8)) }
        let health = try await client.health()
        #expect(health.overall == "amber")
        #expect(health.checks.first?.name == "code-sync")
        #expect(health.checks.first?.status == "red")
        #expect(health.checks.first?.detail == "conflict in ~/.agents")
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
}
