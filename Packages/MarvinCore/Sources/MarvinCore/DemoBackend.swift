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
        switch (request.httpMethod ?? "GET", request.url?.path ?? "") {
        case (_, "/status"): (200, #"{"ok":true,"status":"up","uptimeSeconds":4210,"version":"1.0.0"}"#)
        case (_, "/activity"): (200, activity)
        case (_, "/health"): (200, health)
        case (_, "/boards"): (200, boards)
        case (_, "/board/G-Eskayo/marvin"): (200, boardDetail)
        case (_, "/board/G-Eskayo/clarity-captions"): (200, boardDetailCC)
        case (_, "/timeline/G-Eskayo/marvin/272"): (200, timeline)
        case (_, "/relations/G-Eskayo/marvin/272"): (200, relations)
        case (_, "/activity/overview"): (200, activityOverview)
        case (_, "/queue"): (200, queue)
        case (_, "/thread"): (200, thread)
        case ("POST", "/chat"): (200, chat)
        case ("POST", "/reply/G-Eskayo/marvin/272"): (200, replySuccess)
        case ("POST", "/reply/G-Eskayo/marvin/199"): (403, #"{"ok":false,"error":"not allowlisted"}"#)
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

    static let boardDetail = """
    {"ok":true,"data":{"repo":"G-Eskayo/marvin","name":"marvin","columns":[
    {"id":"todo","name":"To Do","cards":[
    {"id":"c1","number":272,"title":"Mobile backend: board endpoints","repo":"G-Eskayo/marvin","assignee":"Gil"}
    ]},
    {"id":"doing","name":"Doing","cards":[
    {"id":"c2","number":261,"title":"Map publishes itself to production","repo":"G-Eskayo/marvin","assignee":"MARVIN"}
    ]},
    {"id":"done","name":"Done","cards":[]}
    ],"other_projects":[
    {"id":"proj-1","repo":"G-Eskayo/clarity-captions","name":"clarity-captions","card_count":3}
    ]}}
    """

    static let boardDetailCC = """
    {"ok":true,"data":{"repo":"G-Eskayo/clarity-captions","name":"clarity-captions","columns":[
    {"id":"todo","name":"To Do","cards":[
    {"id":"c1","number":25,"title":"Latency baseline and 10% budget","repo":"G-Eskayo/clarity-captions","assignee":"Gil"}
    ]},
    {"id":"doing","name":"In Progress","cards":[]},
    {"id":"done","name":"Done","cards":[]}
    ],"other_projects":[
    {"id":"proj-1","repo":"G-Eskayo/marvin","name":"marvin","card_count":8}
    ]}}
    """

    static let timeline = """
    {"ok":true,"data":[
    {"id":"evt-1","type":"comment","actor":"Gil","body":"Looks solid. When does the Face ID gate go live?","created_at":"2026-10-08T18:03:00Z"},
    {"id":"evt-2","type":"state-change","actor":"MARVIN","body":"currentStage: todo → doing","created_at":"2026-10-08T17:57:46Z"},
    {"id":"evt-3","type":"opened","actor":"Gil","body":null,"created_at":"2026-10-08T17:57:30Z"}
    ]}
    """

    static let relations = """
    {"ok":true,"data":{"repo":"G-Eskayo/marvin","number":272,"related_prs":[
    {"id":"pr-1","number":1234,"title":"Implement board detail and timeline read endpoints","repo":"G-Eskayo/marvin-backend","state":"open"}
    ],"related_docs":[
    {"id":"doc-1","path":"docs/adr/0041-mobile-endpoints.md","label":"ADR 0041: Mobile Backend Shape"},
    {"id":"doc-2","path":"docs/adr/0039-mobile-auth.md","label":"ADR 0039: Mobile Face ID Gate"}
    ]}}
    """

    static let activityOverview = """
    {"ok":true,"data":{"projects":[
    {"id":"proj-1","repo":"G-Eskayo/marvin","needs_you":true,"waiting_count":2},
    {"id":"proj-2","repo":"G-Eskayo/clarity-captions","needs_you":true,"waiting_count":1}
    ]}}
    """

    static let queue = """
    {"ok":true,"data":{"entries":[
    {"id":"q1","number":272,"repo":"G-Eskayo/marvin","title":"Mobile backend: board endpoints","stage":"executing"},
    {"id":"q2","number":25,"repo":"G-Eskayo/clarity-captions","title":"Latency baseline and 10% budget","stage":"verifying"},
    {"id":"q3","number":261,"repo":"G-Eskayo/marvin","title":"Map publishes itself to production","stage":"waiting"}
    ],"total_waiting":5}}
    """

    static let replySuccess = """
    {"ok":true,"data":{"success":true,"reply_id":"reply-abc123","message":"Reply posted successfully"}}
    """
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
