## North-star fit

**Reuses before adding anything new:**
- `BackendClient`'s `Envelope<T>`/`get<T>` plumbing and `BackendError` cases (`Packages/MarvinCore/Sources/MarvinCore/BackendClient.swift:84-107`) — extended with one `post<Body: Encodable, T: Decodable>` helper, same envelope/403/error handling, for the two write calls. Not a parallel client.
- `Severity`'s fail-safe `init(from:)` decode pattern (`Models.swift:28-35`) — reused for a new small 3-case status enum (the tab's red/blue/green), and for `MrPr`'s lenient decode of its one ambiguous field.
- `ActivityView.RunRow`'s boolean-derived `StatusDot` (`ActivityView.swift:97`) — reused verbatim for each PR row's dot (derived from `canMerge`/`conflicts`/`sentBack`, not an invented per-PR enum the backend doesn't send).
- `HealthView.summary()`'s `StatusDot` + `StatCard` pair (`HealthView.swift:32-49`) and `AppModel.redCheckCount` + `.badge(...)` wiring (`AppModel.swift:38`, `MarvinApp.swift:35-36`) — reused for the MR tab's aggregate status + `openCount` badge.
- `DemoBackend.client()` / `DemoProtocol` (URLProtocol substitution) — reused for new `/mr/*` fixtures, same file, same mechanism.
- `ThreadView`'s `-demoPrompt` debug-launch-arg pattern — reused for two new debug-only entry points (`-mrDetail <number>`, `-mrDeny`), the ios-app playbook's documented way around "the executor can't drive the simulator."
- `Theme.selected` (already blue-600) — reused as-is for the tab's "blue" status color; no new hex value.

**Simplest sufficient approach, and a correction to the ticket's premise:** the ticket's "Blocked by" (`G-Eskayo/marvin#272`) is stale — **that backend work is already merged** (PR #370 for the read endpoints, PR #249 for confirmed-gated `/mr/approve`/`/mr/deny`). This is purely a Swift client + SwiftUI tab against an existing, documented contract (`dashboard/mobile-backend/README.md` in `G-Eskayo/marvin`, read via PR #370/#249's diffs since I can't browse that repo's files directly — only `gh view/list/diff` is available to me). No backend ticket needed.

**A prior attempt exists and must not be repeated.** This worktree carries a dangling WIP commit (`033eb1e`, "WIP preserved before redispatch") that is almost certainly the attempt the retry-after comment refers to. Its design doc (`docs/design/pipeline-g-eskayo-marvin-mobile-3.md` in that commit) is actually sound and describes the *same* approach as this plan — but the code it committed diverges from its own design in ways that would fail review on correctness alone:
- `GET /mr/review-status` real shape is `{status, openCount}` (camelCase, three values red/blue/green). The WIP decoded `{open_count, approved_count, changes_requested_count}` — fields that don't exist on the real backend.
- `GET /mr/ticket-context` real shape is `{ticket, parent}` (either nullable). The WIP decoded a flat `{number, title, current_stage, current_status}` — wrong shape entirely, and called it with `ref` = the **PR number** (parsed from the PR's GitHub URL) when the real parameter is the **ticket number** (`ticketRef`).
- `POST /mr/approve`/`POST /mr/deny` require `confirmed: true` in the body or the backend refuses with 403 — the WIP's request bodies never include `confirmed` at all.
- `BiometricGate.swift`'s `BiometricAuthenticator`/`FaceIDAuthenticator` were defined but **never called** — `MrDetail`'s Approve button and `DenySheet`'s Deny button call `model.approve`/`model.deny` directly, so Face ID never actually gates the side-effecting call, and the acceptance criterion silently fails. `ConfirmedAction` was reduced to an inert value+timestamp struct with no `run`/gating method.
- The deny UI used an invented `DenyAction` (`changesRequested`/`noDecision`) and always sent `reasons: []`, instead of the desktop's real taxonomy (`send_feedback`/`drop` with four checkbox reasons).
- Several catch blocks are `// Handle error` / `// Silently fail` no-ops.
- `Info.plist` was never given `NSFaceIDUsageDescription` — calling `LAContext.evaluatePolicy` for biometrics without it crashes on real Face ID hardware.

I verified the real contracts against `G-Eskayo/marvin` PR #370 (`GET /mr/list`, `/mr/review-status`, `/mr/ticket-context`), PR #249 (`POST /mr/approve`, `/mr/deny`, the `confirmed` gate), and PR #87 (the desktop's actual `DenyModal` — the real `DENY_REASONS` list and the two real actions). This plan is built against those, not against the WIP's guesses.

**Where it spends/saves tokens:** no new polling loop — the tab's aggregate status piggybacks on the existing 15s `monitorConnection()` cadence (same cost envelope as Health's badge today); the PR list/ticket-context/approve/deny calls are on-demand (`.task`/`.refreshable`/button-triggered), not cached or polled, matching `ActivityView`/`HealthView`.

**Phone-OS direction:** this closes the last mirrored-tab gap (Activity, Health, now MR Review) with the phone's first side-effecting action, gated by on-device biometrics rather than just a backend 403.

**More capable, not more passive:** Gil can approve/deny a PR from his phone instead of waiting for a laptop; Face ID keeps that friction deliberate on an irreversible action (merge, or "drop entirely" which per ADR 0025 isn't undoable) — matches "leaves the user more capable... never more passive" directly, because the gate exists to slow the action down, not speed past it.

**Scope decision (not parked as a question):** the ticket's "What to build" says "a PR's summary and originating ticket" — I'm reading that as title/number/repo, merge-readiness (`canMerge`/`conflicts`/`sentBack`), the originating ticket + parent PRD via `/mr/ticket-context`, and a "View on GitHub" link for the full diff — **not** a phone-rendered copy of the metrics/test/dev-evidence sections (`marvin#72`'s schema), since the backend itself doesn't nail down `checks`/`evidence`/`rework`'s shapes (documented as "..." in the README). This is a plain reading of the ticket text, not a coin-flip, so I'm not blocking on it.

## Known gap in my own research

Same gap the prior attempt hit: I can't open `docs/adr/0043-*.md` directly — `gh search`/`gh api` are outside this ticket's `view/list/diff` allowlist, and the ADR lives in `G-Eskayo/marvin`, not this repo. I reconstructed ADR 0043's client-side half from `ConnectionStateTests.swift:29` and PR #249's README diff ("Face ID authentication lives in the mobile client (iOS) per ADR 0043 — this backend only checks the `confirmed` flag it sets"). If ADR 0043 specifies something more exact (a required re-auth timeout, a specific `LAContext` policy beyond `.deviceOwnerAuthenticationWithBiometrics`), I haven't seen it directly.

## Tests to write first

No "How we'll try to break it" section exists on this ticket. List derived from the acceptance criteria plus the general guiding principles (bad/empty/huge/malformed input; each dependency failing; repeats/concurrency; wrong permissions; stale state; a person's mistakes), and from the real contract gaps the prior attempt got wrong.

**New `MrReviewTests.swift` (MarvinCoreTests), `StubProtocol` pattern from `BackendClientTests.swift`:**
1. `mrList()` decodes a full real-shaped fixture (`number, title, url, repo, key, canMerge, conflicts, sentBack, ticketClosed, ticketRef`).
2. `MrPr` tolerates missing optionals (only `number/title/url/repo/key` present) — no throw.
3. `ticketRef` decodes from an Int.
4. `ticketRef` decodes from a numeric String without throwing (lenient; real shape is undocumented).
5. `ticketRef` is `nil` when absent or JSON `null` — never throws.
6. Unknown/extra fields in a PR row (`checks`, `rebase`, `autoMerge`, `rework`, `evidence`, of unspecified shape) are ignored, not fatal.
7. A PR row missing a required field (`number`) throws a decode error surfaced as `BackendError`, not a crash.
8. An empty `/mr/list` array decodes to `[]`.
9. The tab status enum round-trips `red`/`blue`/`green`.
10. An unknown status string decodes to `.red` (fail toward "needs attention"), not silently green/blue.
11. `mrReviewStatus()` decodes `{status, openCount}` **camelCase**, regression-guarding against the snake_case shape the prior attempt wrongly assumed.
12. `mrTicketContext()` decodes `{ticket:{...}, parent:{...}}`, `{ticket:null, parent:null}`, and `{ticket:{...}, parent:null}` without throwing.
13. `mrList()`/`mrReviewStatus()`/`mrTicketContext()` each throw `BackendError.server` on a non-ok envelope and `BackendError.notAllowlisted` on 403.
14. `mrApprove(prUrl:)` POSTs a body that is literally `{"pr_url":"...","confirmed":true}` (asserted via `StubProtocol.lastBody`) — proves no path omits or falsifies `confirmed`.
15. `mrDeny(...)` POSTs `pr_url`, `ticket_number` (including `nil` → JSON `null`), `action` as the raw strings `"send_feedback"`/`"drop"` (not Swift case names), `reasons` (including `[]`), `comment` (including `""`), and `confirmed: true` always — same body-literal assertion.
16. A 500 from `/mr/approve` or `/mr/deny` (simulated webhook failure) throws `BackendError.server` with the message intact.
17. A 403 from `/mr/approve`/`/mr/deny` throws `BackendError.notAllowlisted`.
18. `mrApprove`/`mrDeny` surface the webhook's passthrough fields (`merged`/`reengaged`/`done`/`reason`) rather than collapsing to a bare bool.
19. A 20 KB `comment` string round-trips through the JSON body without truncation or crash.
20. A `comment`/reason string containing newlines, quotes, and emoji round-trips through JSON encoding without corruption.

**New `BiometricGateTests.swift` (MarvinCoreTests) — this is what the prior attempt's own tests failed to cover, and what acceptance criterion 2 requires:**
21. A fake authenticator returning `true` → the wrapped action runs exactly once and its result is returned.
22. A fake returning `false` → the wrapped action **never runs** (call-counting fake) and `run` throws `BiometricError.denied`.
23. A fake that throws (hardware/enrollment failure) → the wrapped action never runs, and the original error propagates unmodified.
24. Two concurrent `run` calls against the same fake (double-tap Approve) → each gets its own independent authenticate-then-act cycle; the action never fires more than once per successful authenticate.
25. `DemoAuthenticator` always returns `true` without touching real `LocalAuthentication`, repeatably — confirms demo mode can never prompt or block on real biometrics.

**Extended `DemoBackendTests.swift`:**
26. New `/mr/list`, `/mr/review-status`, `/mr/ticket-context` fixtures decode through the exact same models the real client uses (parity, not hand-waved).
27. `POST /mr/approve` and `/mr/deny` against the demo backend succeed and return an `MrActionResult` without hitting any real network.
28. The demo PR fixtures include at least one row with `conflicts`/`sentBack` true (renders red) and one clean row (renders green) — and every row has a non-empty `title` (never a bare number).

**Explicitly untested, stated plainly for the PR:** the live `LAContext` Face ID prompt itself (success, user-cancel, lockout, not-enrolled) against real biometric hardware/enrollment. The suite only exercises the gate against fakes, which matches the acceptance criterion's own wording ("a faked LocalAuthentication boundary"), and this executor cannot drive the simulator to exercise the real prompt either way.

<!-- marvin:decisions -->
### drop-friction: Should "Deny → Drop Entirely" get a second confirmation beyond Face ID?
Drop Entirely closes the PR and ticket with no re-engagement, and per ADR 0025 is not undoable — stricter than "Send Feedback" or Approve.
- [ ] Face ID alone is enough — same single gate as Approve and Send Feedback.
- [ ] Add a destructive-style alert ("Drop entirely — closes the PR and ticket, no re-engagement") after Face ID succeeds, before the request is sent.

## Design (for the reviewer, not a question)

- **`Models.swift`**: `MrPr` (`number, title, url, repo, key, canMerge, conflicts, sentBack, ticketClosed, ticketRef` — custom `init(from:)` only for `ticketRef`'s lenient Int-or-numeric-String-or-nil decode; `checks`/`rebase`/`autoMerge`/`rework`/`evidence` deliberately undeclared since their shapes aren't documented and the UI doesn't need them — Decodable ignores unknown keys for free); `MrTabStatus` (`red`/`blue`/`green`, unknown → `.red`); `MrReviewStatus` (`status`, `openCount`, camelCase, no `CodingKeys`); `MrTicketContext` (`ticket`/`parent`, both optional, nested `TicketRef{number, title, body}`); `MrDenyReason` (the four exact desktop strings: "Design/requirements mismatch", "Insufficient tests", "Evidence missing", "Regression/quality"); `MrDenyAction` (`sendFeedback`/`drop`, raw values `send_feedback`/`drop` matching the backend literally); `MrActionResult` (`merged`, `reengaged`, `done`, `reason`, all optional — covers both approve's and deny's response shapes).
- **`BackendClient`**: `mrList()`, `mrReviewStatus()`, `mrTicketContext(ref:repo:)` as new `get<T>` call sites; one new `post<Body: Encodable, T: Decodable>(_:body:)` helper (same envelope/403/error handling as `get`) backing `mrApprove(prUrl:)` and `mrDeny(prUrl:ticketNumber:action:reasons:comment:)`. Both request body structs declare `let confirmed = true` as a non-optional literal — there is structurally no code path that can send `confirmed: false` or omit it.
- **New `BiometricGate.swift` (MarvinCore)**: `protocol BiometricAuthenticator: Sendable { func authenticate(reason: String) async throws -> Bool }`; `enum BiometricError: Error, Equatable, LocalizedError { case denied }`; `struct BiometricGate: Sendable { let authenticator: BiometricAuthenticator; func run<T: Sendable>(reason: String, action: @Sendable () async throws -> T) async throws -> T }` — authenticates, then runs the action only on `true`, else throws `.denied` without running it. One primitive, reused identically for approve and deny (composability — this is the piece the prior attempt defined but never actually wired in). `FaceIDAuthenticator: BiometricAuthenticator` wraps `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)`. `DemoBackend.authenticator() -> BiometricAuthenticator` returns a trivial always-true fake, mirroring `DemoBackend.client()`'s placement.
- **`Info.plist`**: add `NSFaceIDUsageDescription` — missing today, and required before `LAContext.evaluatePolicy` can be called for biometrics without crashing on real hardware.
- **`AppModel`** (thin — logic stays in MarvinCore): `authenticator`/`gate: BiometricGate` mirroring the existing `client: BackendClient?` demo/real branch; `mrList`/`mrListError`, `mrReviewStatus`/`mrOpenCount` mirroring `health`/`healthError`/`redCheckCount`; `loadMrList()`/`loadMrReviewStatus()` mirroring `loadHealth()`; `monitorConnection()` preloads `mrReviewStatus` the same way it preloads `health`. `approve(_:) async throws` / `deny(_:action:reasons:comment:) async throws` call `gate.run(reason:) { try await client.mrApprove/mrDeny(...) }` — the gating happens here, provably, because the network call only exists inside the closure passed to `run`.
- **New `MrReviewView.swift`**: list screen (`Page`, `StatusDot`+`StatCard` summary row for the tab's red/blue/green + `openCount`, reusing `HealthView.summary()`'s shape) replacing the `"review"` tab's `ComingSoonView` in `MarvinApp.swift`; `ForEach` rows reusing `ActivityView.RunRow`'s boolean-derived `StatusDot` (`conflicts || sentBack` → red, `canMerge == false` → yellow, `canMerge == true` → green, else grey), title+number never bare. Row tap opens a detail sheet: PR title/number/repo, ticket + parent context (via `mrTicketContext`, only called when `ticketRef != nil`, using the **ticket number**, not the PR number — the bug in the prior attempt), an "Open on GitHub" link, an Approve button, and a Deny button opening a reason-checkbox sheet (the four `MrDenyReason` cases + free-text comment + "Send Feedback"/"Drop Entirely" buttons, Drop Entirely styled destructively per Theme). Both buttons route through `model.approve`/`model.deny` and show a `.alert` on success or failure — no silent `// Handle error` catches.
- **Debug-only reachability**: `-mrDetail <number>` (PR number, read via `ProcessInfo`, mirrors `-demoPrompt`) auto-opens that PR's detail sheet; `-mrDeny` additionally opens the deny sheet. Demo-only, so the pipeline's screenshot step can reach every screen without tapping.
- **Complexity**: list/detail rendering and decoding are O(n) in open-PR count (small, bounded by registered repos), no local accumulation — each load replaces the prior snapshot, same as `health`/`activity` today. `BiometricGate.run` is O(1) overhead around the wrapped call. No new persistent storage.

## Task List

1. Add `MrPr`, `MrTabStatus`, `MrReviewStatus`, `MrTicketContext`, `MrDenyReason`, `MrDenyAction`, `MrActionResult` to `Packages/MarvinCore/Sources/MarvinCore/Models.swift`.
2. Add `mrList()`, `mrReviewStatus()`, `mrTicketContext(ref:repo:)`, the new `post<Body,T>` helper, `mrApprove(prUrl:)`, `mrDeny(...)` to `BackendClient.swift`.
3. Write `Tests/MarvinCoreTests/MrReviewTests.swift` (items 1–20) against the above — red first.
4. Create `Packages/MarvinCore/Sources/MarvinCore/BiometricGate.swift` (`BiometricAuthenticator`, `BiometricError`, `BiometricGate`, `FaceIDAuthenticator`); add `DemoBackend.authenticator()`.
5. Write `Tests/MarvinCoreTests/BiometricGateTests.swift` (items 21–25) — red first, proving the gate actually blocks the wrapped action.
6. Add `/mr/list`, `/mr/review-status`, `/mr/ticket-context`, `POST /mr/approve`, `POST /mr/deny` fixtures to `DemoBackend.swift`; extend `DemoBackendTests.swift` (items 26–28).
7. Run `swift test --package-path Packages/MarvinCore`; confirm every new test went red-then-green against real implementations.
8. Add `NSFaceIDUsageDescription` to `Apps/Marvin/Info/Info.plist`.
9. Add `mrList`/`mrListError`, `mrReviewStatus`/`mrOpenCount`, `gate`, `loadMrList()`, `loadMrReviewStatus()`, `approve(_:)`, `deny(_:action:reasons:comment:)` to `Apps/Marvin/Sources/AppModel.swift`; wire `loadMrReviewStatus()` into `monitorConnection()`.
10. Build `Apps/Marvin/Sources/MrReviewView.swift` (list, detail sheet, deny sheet) per the Design section, honoring the drop-friction decision once answered (default to "Face ID alone" if unanswered at build time, noted plainly in the PR).
11. Replace the `ComingSoonView` "review" tab in `MarvinApp.swift` with `MrReviewView()`; add `.badge(model.mrOpenCount)`.
12. Update `scripts/screenshots.sh`: keep `6-mr-review` (list), add `7-mr-detail` (`-tab review -mrDetail <n>`), `8-mr-deny` (`-tab review -mrDetail <n> -mrDeny`); renumber the existing `7-docs` to `9-docs`.
13. Regenerate the Xcode project (`scripts/generate-project.sh`) and build (`xcodebuild`, the App-build gate); fix any compile issues.
14. Draft the closing comment: screenshots (captured by the pipeline) + "You want X → tap Y → you see Z" for the list, detail, approve, and deny flows, per `docs/agents/pr-requirements.md`; state plainly that the real Face ID prompt itself is untested.