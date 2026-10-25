import Foundation
import Testing
@testable import MarvinCore

final class MrReviewStubProtocol: URLProtocol, @unchecked Sendable {
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

@Suite(.serialized) struct MrReviewTests {
    let client: BackendClient

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MrReviewStubProtocol.self]
        client = BackendClient(baseURL: URL(string: "http://100.80.189.85:7880")!, session: URLSession(configuration: config))
    }

    static func setHandler(_ code: Int, _ data: String) {
        MrReviewStubProtocol.handler = { _ in (code, Data(data.utf8)) }
        MrReviewStubProtocol.lastRequest = nil
        MrReviewStubProtocol.lastBody = nil
    }

    // MARK: - MR List (1-5)

    @Test func mrListDecodesPRs() async throws {
        Self.setHandler(200, """
            {"ok":true,"data":[
              {"number":42,"repo":"G-Eskayo/marvin","url":"https://github.com/G-Eskayo/marvin/pull/42","title":"Add MR Review feature","author":"Gil"},
              {"number":43,"repo":"G-Eskayo/clarity-captions","url":"https://github.com/G-Eskayo/clarity-captions/pull/43","title":"Latency baseline","author":"Claude"}
            ]}
            """)
        let prs = try await client.mrList()
        #expect(prs.count == 2)
        #expect(prs[0].number == 42)
        #expect(prs[0].title == "Add MR Review feature")
        #expect(prs[0].repo == "G-Eskayo/marvin")
    }

    @Test func mrListReturnsEmptyWhenNoPRs() async throws {
        Self.setHandler(200, #"{"ok":true,"data":[]}"#)
        let prs = try await client.mrList()
        #expect(prs.isEmpty)
    }

    @Test func mrPrIdMatchesUrl() async throws {
        let pr = MrPr(number: 1, repo: "G-Eskayo/marvin", url: "https://github.com/G-Eskayo/marvin/pull/1", title: "Test", author: "Gil")
        #expect(pr.id == "https://github.com/G-Eskayo/marvin/pull/1")
    }

    @Test func mrListRequestsCorrectPath() async throws {
        Self.setHandler(200, #"{"ok":true,"data":[]}"#)
        _ = try await client.mrList()
        #expect(MrReviewStubProtocol.lastRequest?.url?.path == "/mr/list")
    }

    @Test func mrListThrowsOnServerError() async {
        Self.setHandler(500, #"{"ok":false,"error":"database down"}"#)
        await #expect(throws: BackendError.server("database down")) { try await client.mrList() }
    }

    // MARK: - MR Review Status (6-10)

    @Test func mrReviewStatusDecodesOpenStatus() async throws {
        Self.setHandler(200, #"{"ok":true,"data":{"status":"open","denied_reasons":null,"denied_comment":null}}"#)
        let status = try await client.mrReviewStatus(url: "https://github.com/G-Eskayo/marvin/pull/42")
        #expect(status.status == .open)
        #expect(status.deniedReasons == nil)
        #expect(status.deniedComment == nil)
    }

    @Test func mrReviewStatusDecodesApprovedStatus() async throws {
        Self.setHandler(200, #"{"ok":true,"data":{"status":"approved","denied_reasons":null,"denied_comment":null}}"#)
        let status = try await client.mrReviewStatus(url: "https://github.com/G-Eskayo/marvin/pull/42")
        #expect(status.status == .approved)
    }

    @Test func mrReviewStatusDecodesDeniedWithReasons() async throws {
        Self.setHandler(200, #"{"ok":true,"data":{"status":"denied","denied_reasons":["testing","latency"],"denied_comment":"Needs more coverage"}}"#)
        let status = try await client.mrReviewStatus(url: "https://github.com/G-Eskayo/marvin/pull/42")
        #expect(status.status == .denied)
        #expect(status.deniedReasons == ["testing", "latency"])
        #expect(status.deniedComment == "Needs more coverage")
    }

    @Test func mrReviewStatusIncludesUrlInQuery() async throws {
        Self.setHandler(200, #"{"ok":true,"data":{"status":"open"}}"#)
        _ = try await client.mrReviewStatus(url: "https://github.com/G-Eskayo/marvin/pull/42")
        let query = MrReviewStubProtocol.lastRequest?.url?.query ?? ""
        #expect(query.contains("url="))
        #expect(query.contains("42"))
    }

    @Test func mrReviewStatusThrowsOn403() async {
        Self.setHandler(403, #"{"ok":false,"error":"not allowlisted"}"#)
        await #expect(throws: BackendError.notAllowlisted) { try await client.mrReviewStatus(url: "https://example.com") }
    }

    // MARK: - MR Ticket Context (11-15)

    @Test func mrTicketContextDecodesTicketInfo() async throws {
        Self.setHandler(200, #"{"ok":true,"data":{"number":152,"title":"Mobile: MR Review feature","repo":"G-Eskayo/marvin"}}"#)
        let context = try await client.mrTicketContext(ref: "marvin#152", repo: "G-Eskayo/marvin")
        #expect(context.number == 152)
        #expect(context.title == "Mobile: MR Review feature")
        #expect(context.repo == "G-Eskayo/marvin")
    }

    @Test func mrTicketContextIncludesRefAndRepoInQuery() async throws {
        Self.setHandler(200, #"{"ok":true,"data":{"number":1,"title":"Test","repo":"X"}}"#)
        _ = try await client.mrTicketContext(ref: "marvin#152", repo: "G-Eskayo/marvin")
        let query = MrReviewStubProtocol.lastRequest?.url?.query ?? ""
        #expect(query.contains("ref="))
        #expect(query.contains("repo="))
    }

    @Test func mrTicketContextRequestsCorrectPath() async throws {
        Self.setHandler(200, #"{"ok":true,"data":{"number":1,"title":"Test","repo":"X"}}"#)
        _ = try await client.mrTicketContext(ref: "marvin#152", repo: "G-Eskayo/marvin")
        #expect(MrReviewStubProtocol.lastRequest?.url?.path == "/mr/ticket-context")
    }

    @Test func mrTicketContextThrowsOnMissingTicket() async {
        Self.setHandler(500, #"{"ok":false,"error":"ticket not found"}"#)
        await #expect(throws: BackendError.server("ticket not found")) { try await client.mrTicketContext(ref: "marvin#999", repo: "G-Eskayo/marvin") }
    }

    @Test func mrTicketContextEqualsComparison() {
        let c1 = MrTicketContext(number: 152, title: "Test", repo: "G-Eskayo/marvin")
        let c2 = MrTicketContext(number: 152, title: "Test", repo: "G-Eskayo/marvin")
        #expect(c1 == c2)
    }

    // MARK: - MR Approve (16-18)

    @Test func mrApprovePostsToCorrectPath() async throws {
        Self.setHandler(200, #"{"ok":true,"data":{"ok":true,"message":"approved"}}"#)
        let result = try await client.mrApprove(prUrl: "https://github.com/G-Eskayo/marvin/pull/42")
        #expect(MrReviewStubProtocol.lastRequest?.httpMethod == "POST")
        #expect(MrReviewStubProtocol.lastRequest?.url?.path == "/mr/approve")
        #expect(result.ok == true)
    }

    @Test func mrApproveIncludesUrlInBody() async throws {
        Self.setHandler(200, #"{"ok":true,"data":{"ok":true}}"#)
        _ = try await client.mrApprove(prUrl: "https://github.com/G-Eskayo/marvin/pull/42")
        let body = try JSONSerialization.jsonObject(with: MrReviewStubProtocol.lastBody ?? Data()) as? [String: String]
        #expect(body?["url"] == "https://github.com/G-Eskayo/marvin/pull/42")
    }

    @Test func mrApproveThrowsOnServerError() async {
        Self.setHandler(500, #"{"ok":false,"error":"cannot approve"}"#)
        await #expect(throws: BackendError.server("cannot approve")) { try await client.mrApprove(prUrl: "https://example.com") }
    }

    // MARK: - MR Deny (19-20)

    @Test func mrDenyPostsWithReasonsAndComment() async throws {
        Self.setHandler(200, #"{"ok":true,"data":{"ok":true,"message":"denied"}}"#)
        let result = try await client.mrDeny(
            prUrl: "https://github.com/G-Eskayo/marvin/pull/42",
            reasons: [.testing, .latency],
            comment: "Needs more work",
            action: .requestChanges
        )
        #expect(MrReviewStubProtocol.lastRequest?.httpMethod == "POST")
        #expect(MrReviewStubProtocol.lastRequest?.url?.path == "/mr/deny")
        #expect(result.ok == true)
        let body = try JSONSerialization.jsonObject(with: MrReviewStubProtocol.lastBody ?? Data()) as? [String: Any]
        #expect(body?["url"] as? String == "https://github.com/G-Eskayo/marvin/pull/42")
        #expect(body?["action"] as? String == "requestChanges")
    }

    @Test func mrDenyThrowsOnServerError() async {
        Self.setHandler(500, #"{"ok":false,"error":"cannot deny"}"#)
        await #expect(throws: BackendError.server("cannot deny")) {
            try await client.mrDeny(
                prUrl: "https://example.com",
                reasons: [.testing],
                comment: nil,
                action: .escalate
            )
        }
    }
}
