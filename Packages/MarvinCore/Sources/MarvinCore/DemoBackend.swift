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
        let path = request.url?.path ?? ""
        switch (request.httpMethod ?? "GET", path) {
        case (_, "/status"): return (200, #"{"ok":true,"status":"up","uptimeSeconds":4210,"version":"1.0.0"}"#)
        case (_, "/activity"): return (200, activity)
        case (_, "/health"): return (200, health)
        case (_, "/boards"): return (200, boards)
        case (_, "/boards/load"): return (200, boardDetail)
        case (_, "/boards/ticket"): return (200, ticketDetail)
        case (_, "/activity/timeline"): return (200, timeline)
        case (_, "/relations/ticket"): return (200, relations)
        case (_, "/queue"): return (200, queue)
        case (_, "/thread"): return (200, thread)
        case ("POST", "/chat"): return (200, chat)
        case ("POST", "/boards/ticket/reply"): return (200, replyResult)
        default: return (404, #"{"ok":false,"error":"not in demo data"}"#)
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
    {"ok":true,"data":{"repo":"G-Eskayo/marvin","columns":[
     {"id":"todo","label":"To do","cards":[
      {"id":"c1","number":300,"title":"Mobile backend: board, overview and MR read endpoints","reason":"Needed for the app","progress":{"done":3,"total":4},"tags":[{"name":"priority:high","kind":"priority"}]},
      {"id":"c2","number":298,"title":"Debug launch args for demo","reason":"Testing aid"}
     ],"archive":false},
     {"id":"review","label":"Review","cards":[
      {"id":"c3","number":272,"title":"Mobile backend: board, overview and MR read endpoints","progress":{"done":3,"total":3},"evidence":{"verdict":"pass","items":[{"ref":"test-suite","detail":"All tests pass"}]},"pr_links":[{"number":450,"title":"Add board endpoints","url":"https://github.com/G-Eskayo/marvin/pull/450","is_draft":false,"has_dev_evidence":true}],"blocked_by":[]}
     ],"archive":false},
     {"id":"done","label":"Done","cards":[
      {"id":"c4","number":261,"title":"Map publishes itself to production","evidence":{"verdict":"pass","items":[{"ref":"deployment","detail":"Deployed at 2026-10-08T17:39:39Z"}]},"tags":[{"name":"status:shipped","kind":"status"}]}
     ],"archive":false}
    ],"other_projects":[
     {"project_id":"clarity-captions","count":2,"repo":"G-Eskayo/clarity-captions","name":"clarity-captions"}
    ],"fetched_at":"2026-10-25T14:45:00Z"}}
    """

    static let ticketDetail = """
    {"ok":true,"data":{"number":300,"title":"Mobile backend: board, overview and MR read endpoints","body":"Implement endpoints for:\n- GET /boards/load?repo= (full board with columns and cards)\n- GET /boards/ticket?repo=&number= (ticket detail)\n- GET /activity/timeline?number=&repo= (history)\n- GET /relations/ticket?repo=&number= (related tickets/PRs/docs)\n- GET /queue (dispatch queue state)\n- POST /boards/ticket/reply (post comment)","labels":[{"name":"enhancement"},{"name":"mobile"},{"name":"priority:high"}],"url":"https://github.com/G-Eskayo/marvin/issues/300","state":"open","comments":[{"body":"This should be the next step after the thread tab is live.","author":{"login":"gil"},"created_at":"2026-10-08T10:00:00Z"},{"body":"Ready to start when you are.","author":{"login":"claude-haiku"},"created_at":"2026-10-08T12:30:00Z"}]}}
    """

    static let timeline = """
    {"ok":true,"data":[
     {"stage":"plan","status":"completed","timestamp":"2026-10-08T08:00:00Z","detail":"Plan reviewed and approved","machine":null,"cost_usd":0.05},
     {"stage":"executing","status":"running","timestamp":"2026-10-08T14:45:00Z","detail":"Building and testing","machine":"mac-mini-1","cost_usd":0.30}
    ]}
    """

    static let relations = """
    {"ok":true,"data":{"tickets":[
     {"number":298,"repo":"G-Eskayo/marvin","title":"Debug launch args for demo","column":"todo"},
     {"number":272,"repo":"G-Eskayo/marvin","title":"Mobile backend endpoints","column":"review"}
    ],"prs":[
     {"number":450,"repo":"G-Eskayo/marvin","title":"Add board endpoints","url":"https://github.com/G-Eskayo/marvin/pull/450","is_draft":false}
    ],"docs":[
     {"title":"PRD #152: Mobile app for MARVIN","url":"https://github.com/G-Eskayo/marvin/issues/152","kind":"prd"}
    ]}}
    """

    static let queue = """
    {"ok":true,"data":{"queue":[
     {"position":1,"repo":"G-Eskayo/marvin","project":"marvin","number":300,"title":"Mobile backend endpoints","priority":10,"score":95.5,"machines":["mac-mini-1"],"created_at":"2026-10-25T10:00:00Z"},
     {"position":2,"repo":"G-Eskayo/clarity-captions","project":"clarity-captions","number":26,"title":"Optimize inference latency","priority":9,"score":87.2,"machines":["mac-mini-1","laptop"],"created_at":"2026-10-24T14:00:00Z"}
    ],"running":[
     {"repo":"G-Eskayo/clarity-captions","project":"clarity-captions","number":25,"title":"Latency baseline and 10% budget","machine":"mac-mini-1"}
    ],"error":null}}
    """

    static let replyResult = """
    {"ok":true,"data":{"posted":true,"requeued":false,"effect":"Updated labels: +testing -waiting:review","warning":null}}
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
