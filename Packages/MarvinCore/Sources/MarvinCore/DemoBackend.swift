import Foundation

/// A built-in fake backend for the app's `-demo` launch mode: realistic sample data and a
/// slowly streamed Chat reply, so simulator screenshots are repeatable and need no Mac,
/// Tailscale or allowlist. Never used unless the app is launched with `-demo`.
public enum DemoBackend {
    public static let baseURL = URL(string: "http://demo.marvin.invalid")!

    /// `replyDelay` paces the streamed Chat reply (long enough to see the typing indicator).
    public static func client(replyDelay: Duration = .seconds(2)) -> BackendClient {
        DemoProtocol.replyDelay = replyDelay
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DemoProtocol.self]
        return BackendClient(baseURL: baseURL, session: URLSession(configuration: config))
    }

    static func response(for request: URLRequest) -> (Int, String) {
        let query = URLComponents(url: request.url ?? URL(fileURLWithPath: ""), resolvingAgainstBaseURL: false)?.queryItems ?? []
        let queryValue: (String) -> String? = { key in query.first { $0.name == key }?.value }

        return switch (request.httpMethod ?? "GET", request.url?.path ?? "") {
        case (_, "/status"): (200, #"{"ok":true,"status":"up","uptimeSeconds":4210,"version":"1.0.0"}"#)
        case (_, "/activity"): (200, activity)
        case (_, "/health"): (200, health)
        case (_, "/boards"): (200, boards)
        case (_, "/boards/load"): (200, boardDetail(for: queryValue("repo") ?? "G-Eskayo/marvin"))
        case (_, "/thread"): (200, thread)
        case (_, "/activity/timeline"): (200, timeline)
        case (_, "/relations/ticket"): (200, relations)
        case (_, "/relations/context"): (200, relationsContext)
        case (_, "/queue"): (200, queue)
        case ("POST", "/boards/ticket/reply"): (200, ticketReplyResult)
        case ("POST", "/chat"): (200, chat)
        default: (404, #"{"ok":false,"error":"not in demo data"}"#)
        }
    }

    // MARK: - Fixtures (shapes match the real mobile backend, 2026-10-08)

    static let activity = """
    {"ok":true,"data":[
     {"repo":"G-Eskayo/marvin","number":272,"key":"G-Eskayo/marvin#272","currentStage":"executing","currentStatus":"started","costUsd":0.42,"failed":false,"title":"Mobile backend: board, overview and MR read endpoints","eventCount":3,"lastEventAt":"2026-10-08T17:57:46Z","isLiveNow":true},
     {"repo":"G-Eskayo/clarity-captions","number":25,"key":"G-Eskayo/clarity-captions#25","currentStage":"verify","currentStatus":"running","costUsd":1.10,"failed":false,"title":"Latency baseline and 10% budget","eventCount":6,"lastEventAt":"2026-10-08T17:40:00Z","isLiveNow":false},
     {"repo":"G-Eskayo/marvin","number":261,"key":"G-Eskayo/marvin#261","currentStage":"done","currentStatus":"passed","costUsd":1.85,"failed":false,"title":"Map publishes itself to production","eventCount":7,"lastEventAt":"2026-10-08T17:39:39Z","isLiveNow":false},
     {"repo":"G-Eskayo/marvin","number":199,"key":"G-Eskayo/marvin#199","currentStage":"merge","currentStatus":"failed","costUsd":2.31,"failed":true,"title":"Parallel dispatch: first live run with two projects at once","eventCount":11,"lastEventAt":"2026-10-08T15:02:11Z","isLiveNow":false}
    ]}
    """

    static let health = """
    {"ok":true,"data":{"generated_at":"2026-10-08T17:54:00Z","overall":"red","coverage":null,"anomaly":null,"checks":[
     {"id":"main:green","label":"The main branch passes its tests","severity":"red","detail":"main @ 8a175b5 is failing: 1 error. Merges are refused until it is fixed"},
     {"id":"cron:code-sync-push","label":"Cron job: code-sync-push","severity":"red","detail":"2 failure indicators since last check: a stash was left over"},
     {"id":"disk:mac-mini-1","label":"Disk headroom: mac-mini-1","severity":"yellow","detail":"38 GB free, forecast 9 days to the 15 GB floor"},
     {"id":"dispatch:parallel","label":"Parallel dispatch keeping up","severity":"green","detail":"2 of 3 slots busy, nothing waiting"},
     {"id":"token:oauth-token","label":"Auth token: oauth-token","severity":"green","detail":"present, 108 chars"},
     {"id":"sync:agents","label":"Code sync: ~/.agents","severity":"green","detail":"both machines at 5a60ea0"}
    ]}}
    """

    static let boards = """
    {"ok":true,"data":[
     {"repo":"G-Eskayo/clarity-captions","name":"clarity-captions","due":"2026-10-25","dueHard":true,"status":"active"},
     {"repo":"G-Eskayo/marvin","name":"marvin","status":"active"},
     {"repo":"G-Eskayo/marvin-mobile","name":"marvin-mobile","status":"active"}
    ]}
    """

    // Newest first, like the real /thread.
    static let thread = """
    {"ok":true,"data":[
     {"id":"d4","source":"chat","role":"assistant","text":"Health is red for two things: main failed one test run this morning, and code-sync refused to push because of a leftover stash. Both are fixed; the next health run should go green.","sessionId":"demo","ts":4000},
     {"id":"d3","source":"chat","role":"user","text":"Why is Health red?","sessionId":"demo","ts":3000},
     {"id":"d2","source":"chat","role":"assistant","text":"Morning, Gil. Two tickets merged overnight, one is executing now (marvin#272), and clarity-captions is 17 days from its hard deadline.","sessionId":"demo","ts":2000},
     {"id":"d1","source":"chat","role":"user","text":"Good morning, what happened overnight?","sessionId":"demo","ts":1000}
    ]}
    """

    static let chat = """
    {"type":"session","sessionId":"demo"}
    {"type":"text","text":"Today: marvin#272 is executing, clarity-captions#25 is in verify, and marvin#199 needs a look: its merge failed. "}
    {"type":"text","text":"Want me to open #199 on the Activity tab?"}
    {"type":"result","text":"","sessionId":"demo","isError":false}

    """

    static func boardDetail(for repo: String) -> String {
        #"{"ok":true,"data":{"repo":"\#(repo)","columns":[{"id":"waiting","label":"Waiting for input","cards":[{"id":"1","number":201,"title":"Set up cross-machine sync","reason":"Needed before we can build distributed indexing","blockedBy":[],"evidence":[],"tags":[],"prLinks":[]},{"id":"2","number":202,"title":"Design the indexing layer","blockedBy":["waiting"],"evidence":[],"tags":[{"id":"blocker","label":"blocker","kind":"blocker"}],"prLinks":[]}]},{"id":"planning","label":"Planning","cards":[{"id":"3","number":203,"title":"Prototype spatial indexing","reason":"Will determine performance ceiling","progress":{"percent":60,"numerator":3,"denominator":5},"blockedBy":[],"evidence":[],"tags":[{"id":"milestone","label":"M1","kind":"milestone"}],"prLinks":[{"id":"1","number":304,"title":"Spatial index prototype","repo":"G-Eskayo/marvin","hasDevEvidence":true}]}]},{"id":"executing","label":"Executing","cards":[{"id":"4","number":272,"title":"Mobile backend: board, overview and MR read endpoints","reason":"Shipping the iPhone app's Activity tab","progress":{"percent":75,"numerator":3,"denominator":4},"blockedBy":[],"evidence":[],"tags":[{"id":"review","label":"code review","kind":"review"}],"prLinks":[{"id":"2","number":308,"title":"Activity board and ticket detail","repo":"G-Eskayo/marvin-mobile","hasDevEvidence":true},{"id":"3","number":309,"title":"MR Review","repo":"G-Eskayo/marvin-mobile","hasDevEvidence":false}]}]},{"id":"done","label":"Done","cards":[{"id":"5","number":261,"title":"Map publishes itself to production","progress":{"percent":100,"numerator":1,"denominator":1},"blockedBy":[],"evidence":[],"tags":[],"prLinks":[{"id":"4","number":307,"title":"Map auto-publish gate","repo":"G-Eskayo/marvin","hasDevEvidence":true}]}]}]}}"#
    }

    static let timeline = #"{"ok":true,"data":[{"id":"1","timestamp":"2026-10-08T10:00:00Z","eventType":"created","description":"Ticket created"},{"id":"2","timestamp":"2026-10-08T11:30:00Z","eventType":"label_added","description":"Added label: executing","costUsd":0},{"id":"3","timestamp":"2026-10-08T14:20:00Z","eventType":"comment","description":"Left a comment: checking progress","costUsd":0.05},{"id":"4","timestamp":"2026-10-08T17:57:46Z","eventType":"status_change","description":"Changed status to running","costUsd":0}]}"#

    static let relations = #"{"ok":true,"data":{"related_tickets":[{"id":"rel1","number":201,"title":"Set up cross-machine sync","repo":"G-Eskayo/marvin","state":"waiting"},{"id":"rel2","number":199,"title":"Parallel dispatch: first live run","repo":"G-Eskayo/marvin","state":"done"}],"related_prs":[{"id":"pr1","number":308,"title":"Activity board and ticket detail","repo":"G-Eskayo/marvin-mobile","state":"open"},{"id":"pr2","number":309,"title":"MR Review","repo":"G-Eskayo/marvin-mobile","state":"draft"}],"related_docs":[{"id":"doc1","path":"docs/adr/0042-mobile-backend-design.md","title":"ADR 0042: Mobile Backend Design"},{"id":"doc2","path":"CONTEXT.md","title":"MARVIN Mobile Context"}]}}"#

    static let relationsContext = #"{"ok":true,"data":{"repo":"G-Eskayo/marvin","name":"MARVIN"}}"#

    static let queue = #"{"ok":true,"data":{"queue":[{"id":"q1","number":261,"title":"Map publishes itself to production","repo":"G-Eskayo/marvin","state":"waiting","waiting_for":"approval"},{"id":"q2","number":199,"title":"Parallel dispatch: first live run","repo":"G-Eskayo/marvin","state":"waiting","waiting_for":"fix"}],"error":null,"running":1}}"#

    static let ticketReplyResult = #"{"ok":true,"data":{"ok":true,"message":"Reply posted successfully","warning":null}}"#
}

/// Serves `DemoBackend`'s fixtures. `/chat` is held back by `replyDelay` so the typing
/// indicator shows, like a real Claude Code turn.
final class DemoProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var replyDelay: Duration = .seconds(2)

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (code, body) = DemoBackend.response(for: request)
        let isChat = request.url?.path == "/chat"
        let deliver: @Sendable () -> Void = { [self] in
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        let delay = isChat ? Self.replyDelay : .zero
        if delay == .zero {
            deliver()
        } else {
            let seconds = Double(delay.components.seconds) + Double(delay.components.attoseconds) / 1e18
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds, execute: deliver)
        }
    }

    override func stopLoading() {}
}
