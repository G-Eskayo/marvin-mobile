import Foundation
import Testing
@testable import MarvinCore

// Tests 1–8: MR models and lenient decoding
@Suite struct MRModelTests {
    @Test func ticketRefDecodesFromJSON() throws {
        let json = #"{"number":3,"repo":"G-Eskayo/marvin-mobile","key":"G-Eskayo/marvin-mobile#3"}"#
        let ref = try JSONDecoder().decode(TicketRef.self, from: Data(json.utf8))
        #expect(ref.number == 3)
        #expect(ref.repo == "G-Eskayo/marvin-mobile")
        #expect(ref.key == "G-Eskayo/marvin-mobile#3")
        #expect(ref.id == "G-Eskayo/marvin-mobile#3")
    }

    @Test func ticketSummaryDecodesWithOptionalTitle() throws {
        let json = #"{"number":25,"repo":"G-Eskayo/clarity-captions","key":"clarity#25","title":"Latency baseline"}"#
        let summary = try JSONDecoder().decode(TicketSummary.self, from: Data(json.utf8))
        #expect(summary.title == "Latency baseline")
    }

    @Test func ticketContextDecodesAllFields() throws {
        let json = #"{"number":3,"repo":"G-Eskayo/marvin-mobile","key":"m-mobile#3","title":"MR Review tab","description":"Build the MR Review tab","status":"active","stage":"executing"}"#
        let ctx = try JSONDecoder().decode(TicketContext.self, from: Data(json.utf8))
        #expect(ctx.stage == "executing")
        #expect(ctx.description == "Build the MR Review tab")
    }

    @Test func mrStatusDecodesEnumValues() throws {
        let ready = try JSONDecoder().decode(MRStatus.self, from: Data(#""readyToMerge""#.utf8))
        let draft = try JSONDecoder().decode(MRStatus.self, from: Data(#""draft""#.utf8))
        #expect(ready == .readyToMerge)
        #expect(draft == .draft)
    }

    @Test func mrReviewStatusDecodesCounts() throws {
        let json = #"{"open_count":5,"draft_count":1,"ready_count":2}"#
        let status = try JSONDecoder().decode(MRReviewStatus.self, from: Data(json.utf8))
        #expect(status.openCount == 5)
        #expect(status.draftCount == 1)
        #expect(status.readyCount == 2)
    }

    @Test func denyReasonEnumHasLabels() {
        #expect(DenyReason.checksNeeded.label == "Checks needed")
        #expect(DenyReason.needsRework.label == "Needs rework")
        #expect(DenyReason.rebasing.label == "Rebasing")
        #expect(DenyReason.missingContext.label == "Missing context")
    }

    @Test func denyActionEncodesWithSnakeCaseKeys() throws {
        let action = MRDenyAction(prNumber: 315, reasons: [.checksNeeded, .rebasing], comment: "Needs work")
        let encoded = try JSONEncoder().encode(action)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        #expect(json?["pr_number"] as? Int == 315)
        #expect((json?["reasons"] as? [String])?.count == 2)
        #expect(json?["comment"] as? String == "Needs work")
    }

    @Test func failableDecodableWrapsSuccessfulDecode() throws {
        let json = #"3"#
        let failable = try JSONDecoder().decode(FailableDecodable<Int>.self, from: Data(json.utf8))
        #expect(failable.value == 3)
    }
}

// Tests 21–25: PullRequest custom decoder and severity
@Suite struct PullRequestTests {
    @Test func pullRequestDecodesWithTicket() throws {
        let json = """
        {"number":315,"repo":"G-Eskayo/marvin","key":"marvin#315","title":"MR Review",
         "status":"readyToMerge","ticket":{"number":3,"repo":"G-Eskayo/marvin-mobile","key":"m-mobile#3","title":"MR Review tab"},
         "author":"claude-code","created_at":"2026-10-23T14:22:11Z","url":"https://github.com/..."}
        """
        let pr = try JSONDecoder().decode(PullRequest.self, from: Data(json.utf8))
        #expect(pr.number == 315)
        #expect(pr.ticket?.number == 3)
        #expect(pr.ticket?.title == "MR Review tab")
    }

    @Test func pullRequestToleratesNullTicket() throws {
        let json = #"{"number":300,"repo":"G-Eskayo/marvin","key":"m#300","status":"draft","ticket":null,"title":null,"author":null,"created_at":null,"url":null}"#
        let pr = try JSONDecoder().decode(PullRequest.self, from: Data(json.utf8))
        #expect(pr.ticket == nil)
        #expect(pr.title == nil)
    }

    @Test func severityIsGreenForReady() {
        let pr = PullRequest(number: 1, repo: "R", key: "R#1", title: nil, status: .readyToMerge, ticket: nil, author: nil, createdAt: nil, url: nil)
        #expect(pr.severity == .green)
    }

    @Test func severityIsRedForChecksRequired() {
        let pr = PullRequest(number: 1, repo: "R", key: "R#1", title: nil, status: .checksRequired, ticket: nil, author: nil, createdAt: nil, url: nil)
        #expect(pr.severity == .red)
    }

    @Test func severityIsYellowForChecksRunning() {
        let pr = PullRequest(number: 1, repo: "R", key: "R#1", title: nil, status: .checksRunning, ticket: nil, author: nil, createdAt: nil, url: nil)
        #expect(pr.severity == .yellow)
    }
}

// Tests 6–13: MR endpoint methods on BackendClient
// (see BackendClientTests.swift for all GET/POST method tests)

// Tests 14–20: MRReviewActions actor with in-flight guard
@Suite struct MRReviewActionsTests {
    @Test func inFlightGuardPreventsDoubleSubmit() async {
        let gate = FakeBiometricGate(outcome: .success)
        let client = makeFakeClient(approveResult: MRApproveResult(prNumber: 315, merged: true, message: nil))
        let actions = MRReviewActions(client: client, biometricGate: gate)

        let task1 = Task { await actions.approve(prNumber: 315) }
        let task2 = Task { await actions.approve(prNumber: 315) }

        let r1 = await task1.value
        let r2 = await task2.value

        #expect(r1?.merged == true)
        #expect(r2 == nil)
    }

    @Test func biometricAuthIsRequested() async {
        let gate = FakeBiometricGate(outcome: .success)
        let client = makeFakeClient(approveResult: MRApproveResult(prNumber: 315, merged: true, message: nil))
        let actions = MRReviewActions(client: client, biometricGate: gate)

        _ = await actions.approve(prNumber: 315)
        #expect(gate.authCalled)
    }

    @Test func cancelledAuthReturnsNil() async {
        let gate = FakeBiometricGate(outcome: .userCancelled)
        let client = makeFakeClient(approveResult: MRApproveResult(prNumber: 315, merged: true, message: nil))
        let actions = MRReviewActions(client: client, biometricGate: gate)

        let result = await actions.approve(prNumber: 315)
        #expect(result == nil)
    }

    @Test func denyWithAuthAndFails() async {
        let gate = FakeBiometricGate(outcome: .userCancelled)
        let client = makeFakeClient(denyResult: MRDenyResult(prNumber: 309, recorded: true, message: nil))
        let actions = MRReviewActions(client: client, biometricGate: gate)

        let action = MRDenyAction(prNumber: 309, reasons: [.checksNeeded], comment: "feedback")
        let result = await actions.deny(action: action)
        // Deny returns nil when authentication is cancelled
        #expect(result == nil)
        #expect(gate.authCalled)
    }

    @Test func isInFlightTracksState() async {
        let gate = FakeBiometricGate(outcome: .success)
        let client = makeFakeClient(approveResult: MRApproveResult(prNumber: 315, merged: true, message: nil))
        let actions = MRReviewActions(client: client, biometricGate: gate)

        #expect(await actions.isInFlight(315) == false)
        let result = await actions.approve(prNumber: 315)
        #expect(await actions.isInFlight(315) == false)
        #expect(result?.merged == true)
    }
}

// Test 27: DemoBackend extends with MR fixtures
@Suite struct DemoBackendMRTests {
    @Test func demoMrListMatches() throws {
        let json = DemoBackend.mrList
        let data = Data(json.utf8)
        struct Envelope: Decodable { let ok: Bool; let data: [PullRequest]? }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        #expect(envelope.ok == true)
        #expect(envelope.data?.first?.number == 315)
    }

    @Test func demoMrReviewStatusIsValid() throws {
        let json = DemoBackend.mrReviewStatus
        struct Envelope: Decodable { let ok: Bool; let data: MRReviewStatus? }
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(json.utf8))
        #expect(envelope.ok == true)
        #expect(envelope.data?.openCount == 5)
    }
}

// Test doubles
final class FakeBiometricGate: @unchecked Sendable, BiometricGate {
    let outcome: BiometricOutcome
    private let lock = NSLock()
    private var _authCalled = false

    init(outcome: BiometricOutcome) {
        self.outcome = outcome
    }

    var authCalled: Bool {
        lock.withLock { _authCalled }
    }

    nonisolated func authenticate() async -> BiometricOutcome {
        lock.withLock { _authCalled = true }
        return outcome
    }
}

func makeFakeClient(approveResult: MRApproveResult? = nil, denyResult: MRDenyResult? = nil) -> BackendClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [FakeProtocol.self]
    FakeProtocol.approveResult = approveResult
    FakeProtocol.denyResult = denyResult
    return BackendClient(baseURL: URL(string: "http://fake")!, session: URLSession(configuration: config))
}

final class FakeProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var approveResult: MRApproveResult?
    nonisolated(unsafe) static var denyResult: MRDenyResult?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body: String
        if request.url?.path == "/mr/approve", let result = Self.approveResult {
            let encoded = try! JSONEncoder().encode(result)
            let innerBody = String(data: encoded, encoding: .utf8)!
            body = #"{"ok":true,"data":\#(innerBody)}"#
        } else if request.url?.path == "/mr/deny", let result = Self.denyResult {
            let encoded = try! JSONEncoder().encode(result)
            let innerBody = String(data: encoded, encoding: .utf8)!
            body = #"{"ok":true,"data":\#(innerBody)}"#
        } else {
            body = #"{"ok":false}"#
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
