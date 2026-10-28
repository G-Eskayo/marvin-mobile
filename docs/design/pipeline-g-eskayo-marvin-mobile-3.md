## North-star fit

- **Reuses before adding anything new:** The backend side of this ticket is already done and merged — `GET /mr/list`, `GET /mr/review-status`, `GET /mr/ticket-context`, `POST /mr/approve`, `POST /mr/deny` all shipped in G-Eskayo/marvin PR #249 (closes #160) and PR #370 (closes #272), with Face ID explicitly scoped to the client ("Face ID authentication lives in the mobile client (iOS) per ADR 0043 — this backend only checks the `confirmed` flag it sets"). On the mobile side I reuse: `BackendClient`'s `Envelope`/`get()` plumbing (`BackendClient.swift:84-107`) for the new read calls and a new sibling `post()` for the writes; `Severity`/`Theme.color`/`StatusDot` (`Models.swift:28-35`, `Theme.swift:17-24,80-87`) for per-PR row status instead of inventing a new color system; the `RunRow` "title first, `repo#number` as a secondary monospace line" pattern (`ActivityView.swift:92-115`) so a PR/ticket is never shown as a bare number; `HealthView`'s list→`NavigationLink`→detail structure (`HealthView.swift:51-63`) for PR list→PR detail; `SettingsView`'s `.sheet` pattern for the deny-reason modal; `AppModel`'s `demoClient`/`isDemo` split (`AppModel.swift:26,33`) for a `demoBiometricGate`; and the existing `-tab`/`UserDefaults` launch-argument convention (`MarvinApp.swift:25`) for deep-linking screenshots into PR detail/deny states. The structured deny reasons reuse G-Eskayo/marvin's ADR 0025 taxonomy verbatim (design/requirements mismatch, insufficient tests, evidence missing, regression/quality; Send feedback vs Drop entirely).
- **Simplest sufficient approach:** No new network layer, no new state-management framework — one new `MRReviewActions` actor in MarvinCore (orchestrates Face ID → network call, with in-flight de-dupe) plus BackendClient method additions, and three new SwiftUI views following the exact shape of the existing ones. I deliberately do **not** model backend fields whose JSON type isn't documented (`checks`, `rework`, `evidence`, `rebase`, `autoMerge`) — declaring them with a guessed type risks a decode crash on real data (this exact kind of mismatch is my leading theory for why the previous two automated attempts failed verification, since no trace of either attempt's diff survived to confirm or rule it out). v1 derives each PR row's status client-side from the three fields whose type is unambiguous from the README (`canMerge`, `conflicts`, `sentBack`: all bool-shaped by name and sibling-field convention), via `Severity`, and defers richer status once someone can confirm the real shapes against a live backend.
- **Where it spends/saves tokens and resources:** The ticket's originating-ticket title is fetched lazily — only when a PR's detail screen is opened (one `GET /mr/ticket-context` call), not eagerly for every row in the list — so the list screen stays a single `GET /mr/list` call regardless of how many PRs are open. Face ID gating and the in-flight guard live in MarvinCore (one `swift test` run), not the simulator, so verifying the gate costs no Xcode/simulator time.
- **More capable, not more passive:** Gil can act on a PR (approve/deny with full structured feedback) from his phone instead of waiting for a laptop — this is the ticket's whole point (PRD story 34/35) — while Face ID still means an unlocked phone in someone else's hands can't merge or drop something on its own.
- **Ticket's own stated fit:** none stated in the ticket body; nothing to correct.

## Patterns reused (file : function)

- `Packages/MarvinCore/Sources/MarvinCore/BackendClient.swift` : `get()`, `Envelope`, `check()` — extended with a sibling `post()`, not duplicated.
- `Packages/MarvinCore/Sources/MarvinCore/Models.swift` : `Severity`, lenient `init(from:)` pattern — reused for per-PR row color.
- `Apps/Marvin/Sources/Theme.swift` : `StatusDot`, `Theme.color(_:)`, `Card`, `SectionLabel`, `Page` — reused verbatim for the new views.
- `Apps/Marvin/Sources/ActivityView.swift` : `RunRow`'s "title, then `repo#number`" layout — reused for PR rows and ticket references (never a bare number).
- `Apps/Marvin/Sources/HealthView.swift` : list → `NavigationLink` → detail screen shape — reused for PR list → PR detail.
- `Apps/Marvin/Sources/AppModel.swift` : `isDemo`/`demoClient` split, `isSending`-style in-flight guard on `send()` — reused as the model for Face-ID-gated actions' in-flight guard.
- `Packages/MarvinCore/Tests/MarvinCoreTests/BackendClientTests.swift` : `StubProtocol` real-network-boundary fake — reused for all new `BackendClient` tests; the same "fake the one true boundary" principle is applied to a *new* boundary (`LAContext`) via a new `BiometricGate` protocol.

## Design

**MarvinCore additions**

- `Models.swift`: `PullRequest` (number, title, url, repo, key, canMerge: Bool?, conflicts: Bool?, sentBack: Bool?, ticketClosed: Bool?, ticketRef: TicketRef?) with a **custom** `init(from:)` — required identity fields (number/title/url/repo) decode normally; every status flag decodes via `try?` so one unexpected JSON type on a single field degrades that field to `nil` instead of crashing the whole row (mirrors the backend's own "one repo's failure doesn't hide the others" principle, applied client-side per-field). `TicketRef { number: Int, repo: String }`. `PullRequest.severity: Severity` computed property: `conflicts == true || canMerge == false → .red`; `sentBack == true → .yellow`; `canMerge == true → .green`; else `.grey`. `MRReviewStatus { status: MRStatus, openCount: Int }`, `MRStatus` (red/blue/green, unknown string → `.blue` as the neutral default, never throws). `TicketSummary { number, title, body }`, `TicketContext { ticket: TicketSummary?, parent: TicketSummary? }`. `DenyReason` (4 ADR-0025 cases with human-readable `label`/wire value) and `MRDenyAction` (`sendFeedback`/`drop`). `MRApproveResult { merged: Bool? }`, `MRDenyResult { done: Bool? }`.
- `BackendClient.swift`: generic `post<T: Decodable>(_:body:)` factored out of `get()`'s existing envelope/403 logic (shared private decode helper, no duplication). New calls: `mrList()`, `mrReviewStatus()`, `mrTicketContext(ref:repo:)`, `mrApprove(prURL:)`, `mrDeny(prURL:ticketNumber:action:reasons:comment:)` — the latter two always send `"confirmed": true` (never a parameter), since by construction they're only reachable after `MRReviewActions` gates on Face ID. `mrList()` decodes the array as `[FailableDecodable<PullRequest>]` and compacts, so one malformed row never drops the rest of the list (new tiny reusable `FailableDecodable<T: Decodable>` wrapper).
- New `Biometrics.swift`: `BiometricOutcome` (approved/denied/unavailable), `BiometricGate` protocol (`authenticate(reason:) async -> BiometricOutcome`), `LAContextBiometricGate: BiometricGate` (wraps `LAContext.evaluatePolicy`, `.deviceOwnerAuthenticationWithBiometrics` or `.deviceOwnerAuthentication` per Decision 1 below).
- New `MRReviewActions.swift`: `public actor MRReviewActions` holding `client: BackendClient`, `biometrics: BiometricGate`, and an `inFlight: Set<String>` keyed by PR URL. `approve(_ pr:)` / `deny(_ pr:action:reasons:comment:)`: if the PR's URL is already `inFlight`, throw immediately (no double-submit); else gate on `biometrics.authenticate(reason:)`, and only on `.approved` call the matching `BackendClient` method, clearing `inFlight` in all paths.

**App layer additions**

- `AppModel.swift`: `biometricGate: BiometricGate` (real `LAContextBiometricGate()` or a demo-always-approves fake, same split as `demoClient`), `mrActions: MRReviewActions?` (built from `client`+`biometricGate`), `mrReviewStatus: MRReviewStatus?`, `mrOpenCount`, `loadMRReviewStatus()` called from `monitorConnection()` alongside `loadHealth()` so the tab badge stays live while open (PRD story 37).
- `MarvinApp.swift`: replace the `ComingSoonView` for `"review"` with a real `MRReviewView()`; add `.badge(model.mrOpenCount)` on the MR Review tab, mirroring the Health tab's `.badge(model.redCheckCount)`.
- New `MRReviewView.swift`: list screen (`Page`, `.task`/`.refreshable` exactly like `ActivityView`/`HealthView`, no polling loop — consistent with existing precedent) showing PR rows (`StatusDot(severity: pr.severity)`, title, `repo#number`). Reads `-demoMRDetail <number>` / `-demoMRDeny 1` launch args (same `UserDefaults` convention as `-tab`) to deep-link into detail/deny-sheet for screenshots.
- New `MRDetailView.swift`: PR summary (title, `repo#number`, canMerge/conflicts/sentBack as plain-language status lines, never raw booleans), ticket section (`.task` loads `mrTicketContext` only here, lazily; shows the ticket's title + `repo#number`, never a bare number; "No linked ticket" if `ticketRef` is nil), Approve button, Deny button (opens the reason sheet). Buttons disabled while an action for this PR is in flight (mirrors `AppModel.isSending` guarding `send()`).
- New `DenyReasonSheet.swift`: the 4 `DenyReason` checkboxes + optional free-text comment + "Send feedback" / "Drop entirely" buttons (each requires ≥1 reason or a non-empty comment before being enabled — client-side guard against a contentless deny).
- `Apps/Marvin/Info/Info.plist`: add `NSFaceIDUsageDescription` (required or Face ID calls crash at runtime).
- `Packages/MarvinCore/Sources/MarvinCore/DemoBackend.swift`: add fixtures for `/mr/list` (one green/mergeable PR, one red/conflicted PR, one yellow/sentBack PR — covers all three dot colors for screenshots), `/mr/review-status`, `/mr/ticket-context`, and `POST /mr/approve` / `POST /mr/deny` (canned success responses) so demo mode and screenshots can show the full flow.
- `scripts/screenshots.sh`: keep `6-mr-review` (now the real list), add `6b-mr-review-detail -demoMRDetail <n>` and `6c-mr-review-deny -demoMRDetail <n> -demoMRDeny 1`.

## Tests to write first

The ticket has no "How we'll try to break it" section, so this list is derived from the north-star guiding principles (bad/empty/huge/malformed input; each dependency failing; repeats/concurrency; wrong permissions; stale state; a person's mistakes), per route/unit, plus the ticket's one explicit AC ("Face ID gate covered by a test with a faked LocalAuthentication boundary").

**`BackendClient` — read calls**
1. `mrList()` decodes a full PR row with every documented scalar field present.
2. `mrList()` tolerates missing optional fields (`canMerge`/`conflicts`/`sentBack`/`ticketRef` absent → `nil`, no throw).
3. `mrList()` tolerates one malformed entry in the array (e.g. missing `number`) without losing the other valid rows (`FailableDecodable`).
4. `mrList()` tolerates an unexpected JSON type on a known optional field (e.g. `conflicts` as a string, not bool) — that field decodes to `nil`, the rest of the row still decodes.
5. `mrList()` on an empty array → `[]`, not an error.
6. `mrReviewStatus()` decodes `red`/`blue`/`green` correctly; an unrecognized status string decodes to `.blue` rather than throwing.
7. `mrTicketContext()` decodes `{ticket, parent}` both present, both `null`, and ticket-present/parent-`null`.
8. Any of the above on a 500/`{ok:false,error}` → `BackendError.server(message)`; on 403 → `BackendError.notAllowlisted` (matches `get()`'s existing contract).

**`BackendClient` — write calls**
9. `mrApprove(prURL:)` always sends `{"pr_url":..., "confirmed": true}` — regression guard, since nothing else should ever be able to set `confirmed: false`.
10. `mrApprove` surfaces `.server(message)` on a webhook 500.
11. `mrDeny(...)` sends the correct `action` string, `reasons` array, optional `comment` only when non-empty, `ticket_number` omitted/null when the PR has no linked ticket, and always `confirmed: true`.
12. `mrDeny` with `action: .drop` and no reasons still encodes a valid request (server owns reason-requirement validation, not the client's wire format).
13. A very long `comment` string and an empty `reasons` array both encode and send without truncation or crash (huge/empty input).

**`MRReviewActions` — the Face ID gate (the ticket's required AC)**
14. Biometrics `.denied` → `approve()` throws, **no** network request is made (assert the fake network boundary saw nothing).
15. Biometrics `.unavailable` → same as denied.
16. Biometrics `.approved` → the matching `BackendClient` call fires with the right PR URL.
17. Biometrics `.approved` but the network call fails → the failure surfaces, not swallowed.
18. Same four cases repeated for `deny()`, asserting the deny payload (action/reasons/comment) reaches the request body correctly only on approval.
19. Two concurrent `approve()` calls for the **same** PR URL → only one network request fires; the second call throws an "already in progress" error rather than double-submitting (a person's mistake: double-tap on an irreversible action).
20. Two concurrent `approve()`/`deny()` calls for **different** PR URLs → both proceed independently (concurrency shouldn't serialize unrelated PRs).

**`PullRequest.severity` (pure logic)**
21. `conflicts: true` → `.red` regardless of other flags.
22. `canMerge: false`, no conflicts → `.red`.
23. `sentBack: true`, `canMerge: true`, no conflicts → `.yellow`.
24. `canMerge: true`, no conflicts, no sentBack → `.green`.
25. All flags `nil` (unknown) → `.grey`, not a crash.

**Demo backend**
26. `DemoBackend` serves `/mr/list` with at least one PR of each severity color; every PR row's title is non-empty (never-bare-number guard, mirroring the existing `servesActivityWithTitlesNeverBareNumbers` test).
27. `DemoBackend`'s `/mr/approve` and `/mr/deny` return success envelopes the real `BackendClient` methods can decode.

## Decisions

<!-- marvin:decisions -->
### faceid-policy: Should the Face ID gate allow passcode fallback if Face ID fails or isn't available?
- [ ] Biometrics only (`.deviceOwnerAuthenticationWithBiometrics`) — if Face ID fails (bad lighting, mask, not enrolled), the action simply can't be confirmed from the phone at all; strictest reading of "any action with side effects requires Face ID."
- [ ] Biometrics with passcode fallback (`.deviceOwnerAuthentication`) — Face ID is tried first, but a failed/unavailable Face ID degrades to the device passcode, same as LAContext's normal default; more forgiving in practice, still requires the phone's passcode (not nothing).

### drop-entirely-confirmation: "Drop entirely" closes the PR and ticket with no undo (ADR 0025 flagged this as an unresolved gap). Does it need a confirmation step beyond Face ID?
- [ ] Face ID alone is enough friction, same as Approve and Send feedback.
- [ ] Add a native "This can't be undone" confirmation dialog before the Face ID prompt specifically for Drop entirely.
<!-- /marvin:decisions -->

## Task List

1. MarvinCore: add `TicketRef`, `TicketSummary`, `TicketContext`, `MRStatus`, `MRReviewStatus`, `DenyReason`, `MRDenyAction`, `MRApproveResult`, `MRDenyResult`, and `FailableDecodable<T>` to `Models.swift` (or a new `MRModels.swift`), with tests 1–8, 26 covering decode behavior.
2. MarvinCore: add `PullRequest` with its lenient custom decoder and `severity` computed property; tests 1–5, 21–25.
3. MarvinCore: factor `BackendClient.get()`'s envelope/403 logic into a shared helper and add `post<T>()`; add `mrList()`, `mrReviewStatus()`, `mrTicketContext()`; tests 6–8.
4. MarvinCore: add `mrApprove()`, `mrDeny()`; tests 9–13.
5. MarvinCore: add `Biometrics.swift` (`BiometricOutcome`, `BiometricGate`, `LAContextBiometricGate`) per the chosen Face ID policy (Decision `faceid-policy`).
6. MarvinCore: add `MRReviewActions` actor with the in-flight guard; tests 14–20 (using a `FakeBiometricGate` test double alongside the existing `StubProtocol`).
7. MarvinCore: extend `DemoBackend` with `/mr/list`, `/mr/review-status`, `/mr/ticket-context`, `POST /mr/approve`, `POST /mr/deny` fixtures; test 27 + extend `DemoBackendTests`.
8. App: add `NSFaceIDUsageDescription` to `Apps/Marvin/Info/Info.plist`.
9. App: extend `AppModel` with `biometricGate`, `mrActions`, `mrReviewStatus`, `mrOpenCount`, `loadMRReviewStatus()`, wired into `monitorConnection()`.
10. App: build `MRReviewView` (list) and wire it into `MarvinApp.swift`'s `RootView`, replacing the `ComingSoonView` for `"review"`, with the `.badge(model.mrOpenCount)`.
11. App: build `MRDetailView` (summary, lazy ticket-context load, Approve/Deny, in-flight-disabled buttons) and `DenyReasonSheet` (checkboxes + comment + Send feedback/Drop entirely, with the Decision `drop-entirely-confirmation` outcome applied), plus `-demoMRDetail`/`-demoMRDeny` launch-arg deep links.
12. App: update `scripts/screenshots.sh` with the `6b-mr-review-detail` and `6c-mr-review-deny` shots.
13. Run `swift test --package-path Packages/MarvinCore`, confirm all new and existing tests pass.
14. Write the PR body: screenshots from the three new shots, "how to use it" with concrete use cases ("You want to approve a ready PR → open MR Review, tap it, tap Approve, Face ID → it merges"; "You want to deny with feedback → tap Deny, pick reasons, Send feedback"), and state plainly that live Face ID behavior and the real `/mr/list` field shapes (`checks`/`rework`/`evidence`/`rebase`/`autoMerge`, intentionally not decoded) are untested against the real backend since this environment can't run the app against it.