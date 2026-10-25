## North-star fit

- **Reuses before adding anything new:** the SwiftUI shell (`Theme.swift`'s `Page`/`Card`/`SectionLabel`/`StatusDot`, `ActivityView.swift`'s client-call-from-view pattern, `HealthView.swift`'s `NavigationLink` drill-down, `ThreadView.swift`'s `-demoPrompt` debug-launch-arg pattern, `AppModel.swift`'s `backendURLString`/`client` pattern), the desktop's exact data contracts (`dashboard/mobile-backend/README.md` + `dashboard_gh_api.js`/`actions_api.js` from PR #370 and #249, already merged — nothing new needed server-side), and the desktop's own pure logic ported 1:1 rather than redesigned: `board.js`'s column/card shape (verified against source, not the README prose — see note below), ADR 0037's `planInput` (ported as `planReply`), ADR 0053's queue row shape, `relations.js`'s relation-item shape. Nothing server-side is touched; this ticket is 100% client (MarvinCore models/client methods + SwiftUI).
- **Simplest sufficient approach:** one column at a time via a `TabView(.page)` that is simultaneously a segmented picker (satisfies "swipe or segmented" literally, no extra control needed); ticket body as plain selectable `Text` (not a markdown/linkify renderer — the desktop's `Markdown.jsx`+`linkify` round-trip is real complexity with no second consumer yet, so it stays a documented simplification, not a silent gap); dormant boards shown dimmed inline rather than reproducing the desktop's `<select>`; `/mr/*` and `/activity/overview` ("Waiting on you") are explicitly **not** called — the ticket's own "Scope update" list names only `boards:load`, `activity:timeline`, `relations.ticket`/`.context`, `boards:input`, and `queue:list`; pulling in MR-review data belongs to marvin-mobile#3.
- **Where it spends tokens:** none — this is Swift/SwiftUI, no model calls. It spends *build* complexity on the one piece that's genuinely new infra: lifting tab selection into `AppModel` so a card's PR chip can jump tabs (reused immediately by #3 when MR Review is built for real, not just this ticket).
- **More capable, not more passive:** Gil can browse every project's board, read a ticket's full history and relations, and answer a waiting ticket from his phone instead of waiting for a laptop — directly serving PRD #152 stories 30–36.
- **Ticket's stated fit:** the ticket doesn't state one itself; nothing to correct.
- **Correction to the ticket's own backend reference:** `dashboard/mobile-backend/README.md` (added in PR #370) describes board columns as `{ id, title, cards, archive }`, but the actual implementing code (`board.js`'s `COLUMNS` constant and `buildBoard`) uses `{ id, label, cards, archive }` — `label`, not `title`. Verified against source, not assumed from the doc. The Swift model decodes `label`.

## Tests to write first

Issue #2 has no "How we'll try to break it" section (same situation PR #370's own design doc hit), so this list is derived from the north-star guiding principles, per surface, new `MarvinCoreTests` files unless noted:

**`planReply` (ports ADR 0037's `planInput`, `BoardModelsTests.swift` or similar)**
1. `needs-info` label → `requeue: true`, "back to ready" effect text (desktop's own wording).
2. `needs-reengagement` → `requeue: false`, "already queued" text.
3. `ready-for-human` and, separately, `wontfix` → `requeue: false`, "stays with you" text.
4. A `claimed:*` label with no `ready-for-agent` → `requeue: true`, "parked after repeated failures" text.
5. A `claimed:*` label **with** `ready-for-agent` already present → falls through to the default (claim alone isn't enough once it's already ready — matches the JS `&& !has('ready-for-agent')` guard).
6. `state != "OPEN"` (closed) wins over every label, including `needs-info` → "ticket is closed" text, `requeue: false`.
7. Empty label list, default `state` → default "agent reads the comments" text, `requeue: false`.
8. Branch precedence: a ticket with both `needs-info` **and** `claimed:mac-mini` → `needs-info` wins (same order as the JS `if` chain).

**`BackendClient` new methods (`BackendClientTests.swift`, same `StubProtocol` boundary fake)**
9. `boardDetail(repo:)` decodes columns/cards/tags/prs/evidence/progress/blockedBy correctly from a realistic fixture.
10. `boardDetail` tolerates a card missing every optional field (no evidence, no progress, no prs, no blockedBy) — matches `activity`'s existing "tolerates missing optional fields" pattern.
11. `boardDetail` on a 400 (`No board registered for …`) surfaces that message via `BackendError.server`.
12. `timeline(number:repo:)` decodes a realistic event list including `cost_usd` → `costUsd` key remapping.
13. `timeline` on an untracked ticket → empty array, not an error (matches `getTicketTimeline`'s contract).
14. `relationsForTicket` decodes the normal `{tickets,prs,docs}` shape.
15. `relationsForTicket` decodes the degraded non-numeric-number shape (`{state,title,tickets,prs}`, **no `docs` key**) without throwing — defensive `docs ?? []`.
16. `relationsContext(project:)` decodes `adrs` as a `[String:String]` dictionary.
17. `queue()` decodes a normal queue and, separately, the degraded `{queue:[],error:"…"}` shape (never treated as an envelope-level failure, since the backend always answers `ok:true` here).
18. `replyToTicket` on success: decodes `{posted,requeued,effect}`, and the request body always contains literal `"confirmed":true` (regression guard against ever sending `false`/omitting it).
19. `replyToTicket` on a 403 ("Confirmed action required") surfaces that exact message via `BackendError.server`, not a generic error.
20. `replyToTicket` on a 400 (bad repo) and a 500 (webhook/gh failure) each surface the server's message.
21. `replyToTicket` with an empty `body` string still sends normally (server owns validation; client doesn't invent a second rule) — a person's mistake (empty reply) is the server's 400 to catch, verified it round-trips.
22. Network failure (no stub handler, mirrors the existing `probeReportsUnreachable` pattern) on each of the 5 new GET methods and the POST method each throw rather than hang or crash.
23. Two concurrent `timeline` calls on the same (stateless, `Sendable`) client both complete with their own correct data (no shared-state bleed between calls).
24. Malformed/huge JSON (truncated body, a huge `columns` array) decodes-or-throws cleanly, never crashes — same `JSONDecoder` boundary the existing tests already exercise.

**`DemoBackend` (`DemoBackendTests.swift`)**
25. `/boards/load` demo fixture round-trips through `boardDetail` for every demo repo, each board has at least one card per column type the UI renders (so the swipe/segment picker has something in each page in demo mode).
26. The demo board includes at least one card in each `planReply` branch (`needs-info`, a stale `claimed:`, `ready-for-human`) so the Reply box's effect text is exercised by a screenshot, not just a unit test.
27. `/activity/timeline` demo fixture decodes to a non-empty event list for the ticket the detail-screen screenshot opens.
28. `/relations/ticket` and `/relations/context` demo fixtures decode and are non-trivial (at least one related ticket, PR and doc) so the Related section isn't empty in the screenshot.
29. `/queue` demo fixture decodes to a non-empty, ordered list.
30. `replyToTicket` against the demo backend returns success without any real side effect (stub, not a passthrough).

No UI test target exists in this repo today (SwiftUI views are explicitly "light checks only" per PRD #152 Testing Decisions, and `CLAUDE.md`), so `BoardColumnsView`, `TicketDetailView`, `NextUpQueueView` and the `FaceIDGate` wrapper get no new automated test, consistent with every existing view in the app (`ActivityView`, `HealthView`, etc. have none either) — not a gap introduced by this ticket.

## Decisions

None needed. Everything that looked like a choice was already settled by an ADR, the ticket's own scope list, or the existing app's precedent (see North-star fit): PR-chip → MR Review tab (ticket's literal wording, even though #3 isn't built yet — this just lands the tab-switch plumbing), `.deviceOwnerAuthentication` (biometric-with-passcode-fallback, so a transient Face ID failure never locks Gil out — ADR 0043's threat model is an unlocked phone in a stranger's hands, which passcode fallback doesn't weaken), plain-text ticket body (no markdown/linkify renderer — real complexity with no second consumer), dormant boards shown inline-dimmed instead of a second control.

## Task List

1. **MarvinCore models** — `Packages/MarvinCore/Sources/MarvinCore/BoardModels.swift`: `BoardDetail`, `BoardColumn` (`label`, not `title`), `Card`, `Card.Progress`, `Card.Evidence`, `Tag`/`Tag.Kind`, `PRLink`.
2. **MarvinCore models** — `TicketDetailModels.swift`: `TimelineEvent` (`cost_usd` → `costUsd`), `TicketRelations` (defensive `docs ?? []`), `RelatedItem`, `RelatedDoc`, `ProjectContext`, `TicketReplyResult`, `ReplyPlan` + `planReply(labels:state:)`.
3. **MarvinCore models** — `QueueModels.swift`: `QueueResponse` (decode `queue`/`error`, ignore `running`), `QueueRow`.
4. **`BackendClient`** — add `boardDetail(repo:)`, `timeline(number:repo:)`, `relationsForTicket(repo:number:)`, `relationsContext(project:)`, `queue()` (all via the existing private `get` helper), and `replyToTicket(repo:number:body:)` (new POST path, reusing the existing private `Envelope<T>`, always sends `confirmed: true`).
5. **`DemoBackend`** — extend `response(for:)` to parse query params (`repo`, `number`, `project`) and serve `/boards/load`, `/activity/timeline`, `/relations/ticket`, `/relations/context`, `/queue`, and `POST /boards/ticket/reply` fixtures; design the board fixture so every `planReply` branch and every column has at least one representative card.
6. **Write all tests from the list above**, confirm red, then make them pass (`swift test --package-path Packages/MarvinCore`).
7. **`AppModel`** — replace `RootView`'s local `selection` `@State` with `AppModel.activeTab` (same initial-value-from-`-tab` behavior, no new persistence) so a card's PR chip can switch tabs; update `MarvinApp.swift`'s `RootView` to bind to it via `@Bindable`.
8. **`Apps/Marvin/Sources/FaceIDGate.swift`** — small `FaceIDAuthenticating` protocol + `LAContext`-backed implementation using `.deviceOwnerAuthentication`, fails closed (returns `false`) if biometrics/passcode aren't available rather than throwing or silently succeeding.
9. **`Apps/Marvin/Sources/BoardColumnsView.swift`** — project switcher (tappable chips with due dates, dormant dimmed), `NextUpQueueView` (collapsible "Next up" strip from `queue()`), the `TabView(.page)` column picker with tag-filter chips and the Done column's archive toggle, each card rendered per the ported `board.js` shape (reason, progress, evidence, blockedBy, PR chips with `hasDevEvidence`).
10. **`Apps/Marvin/Sources/TicketDetailView.swift`** — ticket header + labels + PR chips (tap → `model.activeTab = "review"`), plain-text body, `PipelineHistory`-equivalent timeline list, `Related`-equivalent tickets/PRs/docs list (ticket tap → same-project card select or cross-project no-op with a plain label; doc tap → no-op, Docs tab isn't built yet), and the Reply box: shows `planReply`'s effect text before sending, Send button calls `FaceIDGate.authenticate` then `client.replyToTicket`, shows the result/warning/error exactly like the desktop's `TicketReply`.
11. **Rewrite `ActivityView.swift`** as the thin orchestrator: `NextUpQueueView` + `BoardColumnsView` + `NavigationLink`/push to `TicketDetailView` on card tap, replacing the current placeholder project-chip row.
12. **Debug launch args** (mirrors `-tab`/`-demoPrompt`): `-demoTicket <number>` (+ `-demoTicketRepo <repo>`, default to the auto-selected board) to open `TicketDetailView` directly on launch for a reliable screenshot.
13. **`scripts/screenshots.sh`** — add `shot 8-ticket-detail … -tab activity -demoTicket <n> -demoTicketRepo <repo>` for the ticket-detail/reply/timeline/relations screen; the existing `4-activity` shot now shows the real board instead of the placeholder, no line change needed there.
14. **Run `scripts/screenshots.sh issue-2`**, commit the PNGs under `docs/screenshots/issue-2/`, and write the ticket's closing comment with "You want X → tap Y → you see Z" for: browsing a project's board, swiping/filtering columns, opening a ticket's history and relations, jumping from a PR chip to the MR Review tab, answering a waiting ticket behind Face ID. State plainly that the Face ID confirmation flow and all new SwiftUI rendering/navigation are untested beyond compilation (no UI test target exists in this repo; the executor cannot drive the simulator interactively).