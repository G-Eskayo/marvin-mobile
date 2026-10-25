## North-star fit

- **Reuses before adding anything new:**
  - `AppModel.loadHealth()`/`healthError`/`redCheckCount` + the `.badge(...)` wiring in `MarvinApp.swift:35-36` → mirrored exactly for `loadMrReviewStatus()`/`mrListError`/`mrOpenCount` and the MR Review tab's badge.
  - `ActivityView.swift`'s `RunRow` (status dot derived from booleans, never a bare ticket number) and `HealthView.swift`'s `NavigationLink { CheckDetail(check:) } label: { CheckRow(check:) }` drill-down → reused verbatim for the PR list row → PR detail drill-down.
  - `BackendClient`'s `Envelope<T>`/`get<T>` plumbing and `BackendError` cases → reused for the new GET routes (`mrList`, `mrReviewStatus`, `mrTicketContext`) and extended with one `post<Body: Encodable, T: Decodable>` helper (same envelope/403/error handling, new verb) for `mrApprove`/`mrDeny` — not a parallel client.
  - `Severity`'s custom `init(from:)` fail-safe-decode pattern (BackendClient.swift / Models.swift) → reused for the new `MrReviewTabStatus` enum and for `MrPr.ticketRef`'s lenient decode (the real shape of `ticketRef`/`checks`/`rework`/`evidence` isn't nailed down in the contract I could read — see below — so the model only declares the fields the UI needs and decodes the one ambiguous one leniently; everything else Decodable ignores for free).
  - `DemoBackend.client()` / `DemoProtocol` (URLProtocol substitution) → reused for the new `/mr/*` fixtures, same file.
  - `ThreadView`'s `-demoPrompt` launch-arg pattern (`UserDefaults.standard.string(forKey:)`, demo-only) → reused for two new debug-only entry points (`-mrDetail <number>`, `-mrDeny`) so the pipeline's screenshot script can reach the detail/deny screens without tapping (ios-app playbook's documented trap: the executor can't drive the simulator).
  - `Theme.selected` (blue-600, already the desktop's "selected chip" color) → reused as-is for the new "blue" MR status color; no new hex value invented.
- **Simplest sufficient approach:** no new backend work needed — `G-Eskayo/marvin#272` (mobile read endpoints: `/mr/list`, `/mr/review-status`, `/mr/ticket-context`) and `#160`/`#159` (confirmed-gated `/mr/approve`, `/mr/deny`, the `confirmed` flag contract) are already merged (PRs #370, #249, #210). This ticket is purely a Swift client + SwiftUI tab against an existing, documented contract — one new model file addition, one new gate file, two new views, demo fixtures, screenshots. No backend ticket needed.
- **Scope cut, stated plainly:** the desktop's MR detail view (`MrDetail.jsx`) renders a full structured evidence schema (metrics table, test results, dev-environment evidence — `G-Eskayo/marvin#72`). The mobile ticket's "What to build" only asks for "a PR's summary and originating ticket, and approve/deny" — I'm reading that as the ticket + parent-PRD context (`/mr/ticket-context`) plus a link out to GitHub for the full diff/evidence, **not** a phone-rendered copy of the metrics/test/dev-evidence sections. This is a real scope decision, not just an implementation detail — see Decisions below.
- **Where it spends/saves:** no new network polling loop — `loadMrReviewStatus()` piggybacks on the existing 15s `monitorConnection()` cadence (`AppModel.swift:46-52`), same cost envelope as Health's badge today. PR list/ticket-context are fetched on-demand (`.task`/`.refreshable`), not cached or polled, matching `ActivityView`/`HealthView`.
- **Phone-OS direction:** this closes the last mirrored-tab gap (Activity, Health, now MR Review) with a real side-effecting action gated by on-device biometrics — the first place the phone can *act* on MARVIN's behalf, not just observe it.
- **More capable, not more passive:** Gil can approve/deny a PR from his phone instead of waiting for a laptop; Face ID keeps that power deliberately friction-ful (a real decision, not a reflex tap) — fits the "leaves the user more capable, never more passive" test directly, because the gate is designed to *slow down* an irreversible action, not speed past it.
- **Ticket's own stated fit:** the ticket states no explicit north-star fit — nothing to correct.

## Known gap in my own research

I could not open `docs/adr/0043-*.md` itself (marvin-mobile's allowed read-only tools don't include browsing another repo's arbitrary files, and `gh search`/`gh api` are outside the `view/list/diff` allowlist). I reconstructed ADR 0043's contract from two authoritative secondary sources instead: `ConnectionStateTests.swift:29` ("ADR 0043: the backend answers 403 to any device not on the allowlist") and `G-Eskayo/marvin` PR #249's README diff ("Face ID authentication lives in the mobile client (iOS) per ADR 0043 — this backend only checks the `confirmed` flag it sets"). Both are consistent with the design below (device allowlist *and* client-side Face ID are the same ADR's two halves of the mobile trust model), but if ADR 0043 says anything more specific about *how* the client must gate (e.g. a required re-auth timeout, a specific LAContext policy), I haven't seen it directly.

<!-- marvin:decisions -->
### detail-scope: How much of a PR's evidence should the phone's MR detail view show?
- [ ] Minimal — PR title/number/repo, merge-readiness (canMerge/conflicts), the originating ticket + parent PRD (title, body excerpt) via `/mr/ticket-context`, and a "View full PR on GitHub" link for diffs/metrics/test-results/dev-evidence.
- [ ] Full desktop parity — also render the metrics-comparison table, test-results, and dev-environment-evidence sections inline (requires parsing `evidence` from `/mr/list`, whose exact JSON shape I haven't verified against the live backend).

### drop-friction: Should "Deny → drop entirely" (closes PR + ticket, no re-engagement, not undoable per ADR 0025) get a second confirmation beyond Face ID?
- [ ] Face ID alone is enough friction — same gate as Approve and "send feedback."
- [ ] Add a destructive-style "Drop entirely — closes the PR and ticket, no re-engagement" alert confirmation after Face ID succeeds, before the request is sent.

## Design (for the reviewer, not a question)

- **New MarvinCore models** (`Models.swift`): `MrPr` (number, title, url, repo, key, canMerge, conflicts, sentBack, ticketRef — custom decoder, ticketRef tried as Int then numeric-String then nil, never throws on an unexpected shape), `MrReviewTabStatus` (red/blue/green, unknown string fails *toward* `.red`, not `.grey` — deliberately the opposite bias from `Severity`, since an unknown MR status should read as "go look," not "nothing to see"), `MrReviewStatus` (status + openCount), `MrTicketContext`/`TicketInfo` (ticket/parent, both optional), `DenyAction` (`sendFeedback`/`drop`, raw values `send_feedback`/`drop` matching the backend literally), `MrActionResult` (merged/reengaged/done/reason — all optional, covers both approve's and deny's response shapes).
- **BackendClient**: `mrList()`, `mrReviewStatus()`, `mrTicketContext(ref:repo:)` as new `get<T>` call sites; one new `post<Body: Encodable, T: Decodable>(_:body:)` helper (JSONEncoder, same envelope/403/error handling as `get`) backing `mrApprove(prUrl:)` and `mrDeny(prUrl:ticketNumber:action:reasons:comment:)`. Both request bodies hard-code `confirmed = true` as a non-optional literal in the `Encodable` struct — there is structurally no code path in the Swift client that can send `confirmed: false` or omit it.
- **New `BiometricGate.swift` (MarvinCore)**: `protocol BiometricAuthenticator: Sendable { func authenticate(reason: String) async throws -> Bool }`, `enum BiometricError: Error, Equatable, LocalizedError { case denied }` (mirrors `BackendError`'s style), `struct ConfirmedAction { let authenticator: BiometricAuthenticator; func run<T>(reason:, _ action: () async throws -> T) async throws -> T }` — the one general "gate an async action behind biometric confirmation" primitive, used identically for approve and deny (composability: one primitive, not two bespoke copies). `final class FaceIDAuthenticator: BiometricAuthenticator` wraps `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)`. `DemoBackend` gains `static func authenticator() -> BiometricAuthenticator` returning a trivial always-true fake (mirrors `DemoBackend.client()` placement) so `-demo` never touches real biometrics or a real network write.
- **AppModel**: `authenticator: BiometricAuthenticator` computed property mirroring the existing `client: BackendClient?` demo/real branch; `mrList`/`mrListError`, `mrReviewStatus` (+ `mrOpenCount`) state mirroring `health`/`healthError`/`redCheckCount`; `loadMrList()`/`loadMrReviewStatus()` mirroring `loadHealth()`; `monitorConnection()` preloads `mrReviewStatus` the same way it preloads `health`. `approve(_:)`/`deny(_:action:reasons:comment:)` **throw** (unlike the read-only loaders, which swallow and set an `*Error` property) — these are user-initiated actions where the View needs an immediate alert, not a silently-updated background state.
- **New `MrReviewView.swift`**: list screen (`Page`, `StatCard` row for status/openCount, `ForEach` + `StatusDot` rows using the derived-from-booleans pattern, `NavigationLink` to a nested `MrDetail` private view) replacing the `ComingSoonView` for `"review"` in `MarvinApp.swift`. `MrDetail` shows PR title+number (never bare), ticket/parent context, Approve button and a Deny button opening a nested `DenySheet` (4 checkboxes for the categories from `G-Eskayo/marvin#72` — design/requirements mismatch, insufficient tests, evidence missing, regression/quality — plus free-text comment, plus the two terminal actions). Both buttons call `ConfirmedAction`/`approve`/`deny` and show a `.alert` on success or failure.
- **Debug-only reachability**: `-mrDetail <number>` (UserDefaults string, read in `MrReviewView`'s `.task`, mirrors `-demoPrompt`) auto-navigates to that PR's detail; `-mrDeny` (via `ProcessInfo.processInfo.arguments.contains`, mirrors `-demo`) additionally pops the deny sheet. Both demo-only.
- **Complexity**: list/detail rendering and decoding are O(n) in open-PR count (small, bounded by registered repos, no local accumulation — each load replaces the prior snapshot, same as `health`/`activity` today). `ConfirmedAction.run` is O(1) overhead around the wrapped call. No new persistent storage.

## Tests to write first

No "How we'll try to break it" section exists on this ticket; list derived from the north-star guiding principles (bad/empty/huge/malformed input; each dependency failing; repeats/concurrency; wrong permissions; stale state; a person's mistakes) plus the two explicit acceptance criteria.

**New `MrReviewTests.swift` (MarvinCoreTests) — models + BackendClient, `StubProtocol` pattern from `BackendClientTests.swift`:**
1. `mrList()` decodes a full real-shaped fixture (fields from the README contract) correctly.
2. A PR row with `ticketRef` as a numeric string (not a number) still decodes — lenient decode.
3. A PR row with `ticketRef` missing/null decodes with `ticketRef == nil`, not a throw.
4. Unknown/extra JSON fields in a PR row (`checks`, `rebase`, `evidence`, `rework`) are ignored, not fatal.
5. Empty `/mr/list` array decodes to `[]`.
6. A PR row missing a required field (`number`) throws, surfaced as a decode/`BackendError.badResponse`, not a crash.
7. `MrReviewTabStatus` round-trips `red`/`blue`/`green`.
8. An unknown status string decodes to `.red` (fail toward "needs attention"), not silently green.
9. `mrTicketContext` decodes `{ticket: {...}, parent: {...}}`, `{ticket: null, parent: null}`, and `{ticket: {...}, parent: null}` (parent absent) all without throwing.
10. `mrList()`/`mrReviewStatus()`/`mrTicketContext()` each throw `BackendError.server` on a non-ok envelope, and `BackendError.notAllowlisted` on 403 — same plumbing as existing GET calls, asserted per new call site as a regression guard.
11. `mrApprove(prUrl:)` sends a POST whose body is literally `{"pr_url":"...","confirmed":true}` — asserted via `StubProtocol.lastBody`, for every call, proving there is no code path that omits or falsifies `confirmed`.
12. `mrDeny(...)` sends `action`, `reasons` (including `[]`), `comment` (including `""`), `ticket_number` (including `nil` → JSON `null`), and `confirmed: true` — same body-literal assertion.
13. A 500 from `/mr/approve` or `/mr/deny` (simulated webhook failure) throws `BackendError.server` with the message intact.
14. A 403 from `/mr/approve`/`/mr/deny` throws `BackendError.notAllowlisted` (consistency guard, even though the client never legitimately triggers it).
15. A 50 KB `comment` string round-trips through the JSON body without truncation or crash.
16. `mrApprove`/`mrDeny` surface the webhook's response fields unchanged (`merged`, `reengaged`, `reason`, `done`) rather than collapsing them to a bare success flag.

**New `BiometricGateTests.swift` (MarvinCoreTests):**
17. A fake authenticator returning `true` → the wrapped action runs exactly once and its result is returned.
18. A fake returning `false` → the wrapped action never runs (call-counting fake) and `run` throws `BiometricError.denied`.
19. A fake that throws (hardware/enrollment failure) → the wrapped action never runs, and the original error propagates unmodified.
20. Two concurrent `run` calls against the same fake (double-tap on Approve) → each gets its own independent authenticate-then-act cycle; the wrapped action never fires more than once per successful authenticate.

**Extended `DemoBackendTests.swift`:**
21. New `/mr/list`, `/mr/review-status`, `/mr/ticket-context` fixtures decode through the exact same `MrPr`/`MrReviewStatus`/`MrTicketContext` models the real backend uses (parity, not a hand-waved shape).
22. `DemoBackend.authenticator()` always returns `true` without prompting — asserted directly against the protocol, confirming demo mode can never block on real biometrics.
23. Demo fixture PR list includes at least one row with a title (never a bare number), consistent with the existing activity-fixture test's convention.

**Explicitly untested / stated plainly for the PR:** the live `LAContext` Face ID prompt itself (success, user-cancel, lockout, not-enrolled) against real biometric hardware/simulator enrollment — the test suite only exercises `ConfirmedAction` against fakes. This matches the acceptance criterion's own wording ("covered by a test with a faked LocalAuthentication boundary"), and the executor cannot drive the simulator to exercise the real prompt either way.

## Task List

1. Add `MrPr`, `MrReviewTabStatus`, `MrReviewStatus`, `MrTicketContext`/`TicketInfo`, `DenyAction`, `MrActionResult` to `Packages/MarvinCore/Sources/MarvinCore/Models.swift`.
2. Add `get`-based `mrList()`, `mrReviewStatus()`, `mrTicketContext(ref:repo:)` and the new `post<Body,T>` helper + `mrApprove(prUrl:)`/`mrDeny(...)` to `BackendClient.swift`.
3. Write `Tests/MarvinCoreTests/MrReviewTests.swift` (items 1–16) against the above — red first.
4. Create `Packages/MarvinCore/Sources/MarvinCore/BiometricGate.swift` (`BiometricAuthenticator`, `BiometricError`, `ConfirmedAction`, `FaceIDAuthenticator`); add `DemoBackend.authenticator()`.
5. Write `Tests/MarvinCoreTests/BiometricGateTests.swift` (items 17–20) — red first.
6. Add `/mr/list`, `/mr/review-status`, `/mr/ticket-context`, `/mr/approve`, `/mr/deny` fixtures to `DemoBackend.swift`; extend `DemoBackendTests.swift` (items 21–23).
7. Run `swift test --package-path Packages/MarvinCore`; confirm every new test went red-then-green against real implementations (no test skipped by a passing no-op).
8. Add `mrList`/`mrListError`, `mrReviewStatus`/`mrOpenCount`, `authenticator`, `loadMrList()`, `loadMrReviewStatus()`, `approve(_:)`, `deny(_:action:reasons:comment:)` to `Apps/Marvin/Sources/AppModel.swift`; wire `loadMrReviewStatus()` into `monitorConnection()`.
9. Build `Apps/Marvin/Sources/MrReviewView.swift` (list, `MrDetail`, `DenySheet`) per the decided detail-scope option; wire `-mrDetail`/`-mrDeny` debug launch args.
10. Replace the `ComingSoonView` "review" tab in `MarvinApp.swift` with `MrReviewView()`; add `.badge(model.mrOpenCount)`.
11. Update `scripts/screenshots.sh`: replace the single `6-mr-review` shot with `6-mr-review`, `6-mr-detail` (`-tab review -mrDetail <n>`), `6-mr-deny` (`-tab review -mrDetail <n> -mrDeny`).
12. `scripts/generate-project.sh` + `xcodebuild` (App build gate) against the regenerated project; fix any compile issues.
13. Draft the closing comment: screenshots (once captured by the pipeline) + "You want X → tap Y → you see Z" for list, detail, approve, and deny — per `docs/agents/pr-requirements.md`.