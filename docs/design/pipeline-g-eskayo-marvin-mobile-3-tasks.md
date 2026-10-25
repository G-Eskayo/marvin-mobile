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