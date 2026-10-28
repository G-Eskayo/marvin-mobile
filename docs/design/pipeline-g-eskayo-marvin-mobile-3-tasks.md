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