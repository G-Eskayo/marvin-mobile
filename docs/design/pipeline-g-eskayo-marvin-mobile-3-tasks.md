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