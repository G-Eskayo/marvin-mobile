## North-star fit

**Reuses:** `ActivityView`'s existing `boards`/`activity` loading pattern and horizontal project-chip switcher (`Apps/Marvin/Sources/ActivityView.swift:40-62`), `BackendClient`'s `get()` envelope/error decoding (`BackendClient.swift:92-107`), the `Page`/`Card`/`SectionLabel`/`StatCard`/`StatusDot` components (`Theme.swift`), the `HealthView` list→`NavigationLink`→detail pattern (`HealthView.swift:51-63`, `72-108`), `AppModel.send()`'s trim-guard/`isSending` pattern (`AppModel.swift:74-91`), and `DemoBackend`'s `URLProtocol` fixture style for every new read route plus the new write route. The backend side needs **nothing new**: `GET /boards/load`, `/activity/timeline`, `/relations/ticket`, `/relations/context`, `/activity/overview`, `/queue` all shipped in `G-Eskayo/marvin#272` (merged, PR #370), and the write route `POST /boards/ticket/reply` (body `{repo, number, body, confirmed}`, 403 `Confirmed action required` without it) shipped in `G-Eskayo/marvin#160` (merged, PR #249) — both closed before this ticket was ever blocked, so the "Blocked by #272" note is stale.

**Why simplest sufficient:** no new tab, no new AppModel globals — board/ticket state stays view-local exactly like `ActivityView.boards` today. Skips ADR-linkifying ticket bodies (`relations/context`) and in-app PR/Doc navigation, since the Docs and MR Review tabs (#4, #3) are still `ComingSoonView` placeholders — building a tap target with nowhere to land fails the Watts check. Related PRs get a plain `Link` out to Safari instead.

**Tokens:** spends a little upfront reading two already-merged backend PRs' README diffs (`#370`, `#249`) to pin exact request/response shapes instead of guessing against a running server; saves a rebuild cycle that two prior autonomous attempts already lost to a "mixed" verdict with no recoverable detail (no PR was ever raised for either attempt).

**Phone-OS fit / user capability:** this is the pipeline becoming answerable from a phone instead of requiring a desk — directly serves PRD story 33. Face ID gate (new, shared pattern for #3 later) keeps Gil in control rather than passive.

## New Face ID gate design (first side-effecting action in this app)

Per PRD, "Action confirm" is listed as iOS-side but marked `(deep)`/TDD-tested, and `AppModel`/SwiftUI views get light checks only (CLAUDE.md). So the gate logic goes in **MarvinCore**, not `AppModel`:

```swift
public protocol BiometricAuthenticator: Sendable {
    func authenticate(reason: String) async throws -> Bool
}
public enum TicketActionError: Error, Equatable { case emptyReply, notConfirmed, alreadyInFlight }
public actor TicketReplyGate {
    public func reply(repo:, number:, body:, client: BackendClient, authenticator: BiometricAuthenticator) async throws -> TicketReplyResult
}
```

The `actor` gives a real (non-mocked) single-flight guarantee for the concurrency test, not just a disabled button. A thin `LAContextAuthenticator` (System LocalAuthentication wrapper) lives in MarvinCore too but gets light checks only, per PRD's own testing split. In `-demo` mode, `AppModel` wires a `DemoAuthenticator` that resolves `true` instantly — same spirit as `DemoBackend`, and necessary because the pipeline can't drive a real Face ID prompt in the simulator.

## Backend write-route 403 handling (new `post()` helper)

`get()` today treats *any* 403 as `.notAllowlisted` (device-gate rejection). The new write route's 403 means something different (`Confirmed action required`) and carries a decodable `{ok:false, error}` body. New `post<T>()` helper: decode the envelope first; if it parses with `ok:false`, surface `.server(error)` regardless of status code (covers both 400 bad input and 403 confirmed-required); only fall back to `.notAllowlisted` when the body isn't decodable at all on a 403 (true device-gate rejection upstream of the app route).

## Decisions
<!-- marvin:decisions -->
### board-nav: How to move between a board's stage columns on the phone?
- [ ] A: Segmented control (tap a stage name to switch)
- [ ] B: Horizontal swipe between columns (paging)
- [ ] C: Both — a segmented control that also tracks swipe gestures

Gil's own scope-update text poses this as "one column at a time (swipe **or** segmented stages)" — an explicit either/or, and any look change needs his call per the repo's owner gates.

## Tests (written first)

MarvinCore has no ticket "How we'll try to break it" section, so these come from `docs/north-stars.md`'s "Tests try to break it" principle, applied to the real collaborator (the `URLProtocol` stub boundary already used throughout this codebase, per PRD Testing Decisions — "fake only true system boundaries").

**BackendClient / Models (`BackendClientTests.swift` additions):**
1. `boardDetail` decodes columns/cards/`otherProjects`, tolerating missing `archive` and empty `otherProjects`.
2. `boardDetail` on a malformed/empty envelope throws, doesn't crash.
3. `timeline` decodes a list of stage events; tolerates an empty array (ticket with no events yet).
4. `timeline` on malformed JSON surfaces a `BackendError`, not a crash.
5. `relations` decodes `tickets`/`prs`/`docs`, tolerating `state: "UNKNOWN"` and all-empty arrays.
6. `activityOverview` decodes the `{"owner/repo": {review, needsYou, blocked}}` dictionary shape.
7. `queue()` decodes the degraded shape `{queue:[], running:[], error:"<msg>"}` without throwing — the error must surface as readable text, not fail silently as a false "empty queue."
8. `replyToTicket` success: request body always contains literally `"confirmed":true`, plus `repo`/`number`/`body`; decodes `{posted, requeued, effect}`.
9. `replyToTicket` on 403 `{ok:false,error:"Confirmed action required"}` maps to `.server("Confirmed action required")`, not `.notAllowlisted`.
10. `replyToTicket` on a bare 403 with no decodable body maps to `.notAllowlisted` (true device-gate case).
11. `replyToTicket` with a huge body (~50k chars) round-trips through the stub unmodified — no silent truncation.

**TicketReplyGate (new `TicketReplyGateTests.swift`):**
12. Authenticator returns `true` → client's reply call fires exactly once with the exact repo/number/trimmed body.
13. Authenticator returns `false` → client is **never** called (no network call on a failed/cancelled Face ID) — the actual auth-bypass boundary.
14. Authenticator throws (`LAError`-style) → same as failure: no call, and a clear `TicketActionError` surfaces rather than hanging.
15. Empty / whitespace-only draft → refused before even prompting biometrics (`emptyReply`), mirroring `AppModel.send()`'s guard.
16. Two concurrent `reply()` calls on the same gate → the second throws `.alreadyInFlight`; the client is called exactly once (real concurrency via the `actor`, not a UI-level flag).
17. Backend returns `ok:true` but missing `data` → surfaces `BackendError.server`, doesn't crash; drafted text is **not** cleared by the caller on failure (never silently lose what Gil typed).

**Board/card helpers (new `BoardDetailTests.swift` or similar, pure logic in MarvinCore):**
18. Tag filter: multiple selected tags intersect (AND) against a card's labels; a card with none of the selected tags is excluded.
19. Archive toggle: archived cards hidden by default, shown once toggled.
20. "Waiting on owner" detection: true for the designated label/state value, false for everything else, and **false (not a crash)** when the label/state field is absent entirely — same tolerance philosophy as `Severity`'s unknown→`.grey`.
21. Never-a-bare-number: a card/detail display-title helper falls back to `"<repo>#<number>"` when `title` is nil, mirroring `RunRow`'s existing `item.title ?? item.key`; verify the post-reply confirmation string also names the ticket, never a bare number.

**DemoBackend (extend `DemoBackendTests.swift`):**
22. New fixtures exist and decode for `/boards/load`, `/activity/timeline`, `/relations/ticket`, `/activity/overview`, `/queue`.
23. The demo fixture POST to `/boards/ticket/reply` with `confirmed:true` succeeds; the same demo protocol also serves the `confirmed`-missing 403 case so the error path is exercisable in demo mode.

## Task List

1. MarvinCore `Models.swift`: add `BoardCard`, `BoardColumn`, `BoardOtherProject`, `BoardDetail`, `TimelineEvent`, `TicketRelations` (+ `RelatedRef`, `RelatedDoc`), `ProjectOverview`, `QueueEntry`, `QueueStatus`, `TicketReplyResult` — all tolerant-decoding like `ActivityItem`.
2. MarvinCore `BackendClient.swift`: add `boardDetail(repo:)`, `timeline(repo:number:)`, `relations(repo:number:)`, `activityOverview()`, `queue()` (all via `get`), and a new `post<T>()` helper + `replyToTicket(repo:number:body:)`.
3. MarvinCore: new `BiometricAuthenticator.swift` — protocol, `LAContextAuthenticator`, `TicketReplyGate` actor, `TicketActionError`.
4. Write tests 1–23 above (red first), confirming each fails for the right reason before implementation.
5. Implement `Models`/`BackendClient`/`TicketReplyGate` to pass the MarvinCore tests; run `swift test --package-path Packages/MarvinCore` green.
6. `DemoBackend.swift`: add fixtures for the five new read routes plus the write route's success/403 cases; wire a `DemoAuthenticator` always-succeeds path for `-demo`.
7. `AppModel.swift`: add a `biometricAuthenticator` (real `LAContextAuthenticator` normally, `DemoAuthenticator` under `-demo`) and a `reply(to ticket:, body:)` method delegating to `TicketReplyGate`; preserve the draft on failure.
8. New `BoardView.swift` (Apps/Marvin/Sources): project detail — columns per the chosen `board-nav` option, tag filter chips, archived toggle, "needs you" badges sourced from `/activity/overview`.
9. New `TicketDetailView.swift`: body, timeline list, related PRs (`Link` out to GitHub) and related docs (inert list rows), and — only when the ticket is flagged waiting-on-owner — a reply composer wired through `TicketReplyGate` with the Face ID prompt.
10. Extend `ActivityView.swift`: tapping a project chip opens `BoardView`; tapping a card opens `TicketDetailView`; add a small "Next up" section sourced from `/queue`.
11. `Info.plist`: add `NSFaceIDUsageDescription`.
12. `scripts/screenshots.sh`: add shot lines for the board view, a normal ticket detail, a waiting-on-owner ticket detail with the reply composer, and (via a new `-demoTicket <key>` launch arg, mirroring `-demoPrompt`) a post-reply confirmation state.
13. `xcodebuild` app-build verify; capture screenshots into `docs/screenshots/issue-2/`; write the "You want X → tap Y → you see Z" use cases for the closing comment, stating plainly that the real Face ID prompt itself is untestable from this pipeline (known trap) and was verified only via the demo auto-success path.