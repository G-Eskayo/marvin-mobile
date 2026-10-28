## North-star fit

**Reuses before adding anything new:**
- **Drill-down pattern**: `HealthView.swift`'s `NavigationLink { CheckDetail(check:) } label: { CheckRow(check:) }` list→detail push is the exact shape for repos→tree→file. `ActivityView.swift`'s `error`/`loaded` state-and-empty-state convention is reused verbatim for all three Docs screens.
- **API plumbing**: `BackendClient.swift`'s generic `get<T: Decodable>(_:query:)` (`BackendClient.swift:92`) already handles the `{ok,data,error}` envelope, 403→`.notAllowlisted`, and percent-encoded query items. `/docs/repos`, `/docs/tree?id=`, `/docs/content?id=&path=` need **zero new plumbing** — just three one-line methods, mirroring `activity()`/`health()`/`boards()` (`BackendClient.swift:45-47`). Confirmed exact response shapes by reading `G-Eskayo/marvin` PR #201 (introduced these three routes) rather than guessing.
- **Demo data**: `DemoBackend.swift`'s `response(for:)` switch (method, path) and the `-demoPrompt`-style UserDefaults launch-arg convention (`ThreadView.swift:44`) are reused as-is for a new `-demoDocsId`/`-demoDocsPath` pair.
- **Theme**: `Page`, `SectionLabel`, `Theme.card`/`.border`/`.muted` — no new visual primitives.
- **Logic-in-MarvinCore, views-thin**: markdown rendering is pure `Foundation` (no SwiftUI), so it belongs in MarvinCore as a tested pure function, not inline in the view — same split already used for `ChatEvent` parsing.

**Simplest sufficient approach:** render markdown with Foundation's native `AttributedString(markdown:, options:)` (inline formatting only — bold/italic/links/code spans), not a third-party Markdown package. A new dependency is an explicit owner gate (ADR 0007/CLAUDE.md); native parsing needs none and is enough for a read-only v1. I deliberately reject `Text(LocalizedStringKey(dynamicString))` — it runs doc content through `%`-format-specifier and localization-key lookup, which is a real correctness risk for text containing literal `%` (common in docs: percentages, URL-encoded paths). `AttributedString(markdown:)` has no such risk.

**Where it spends/saves:** spends nothing new on dependencies or backend work (the three endpoints already exist and are already proven against the desktop). Saves tokens/complexity by matching only what issue #4 actually asks for — not the later desktop iterations (Files-tab fold, search, PDF viewer, deliverables from marvin PRs #561/#571/#573/#618) which are out of scope for this ticket's three named endpoints.

**More capable, not more passive:** gives Gil the same "where things are" map on his phone that he has on the desktop, read-only — no behavior change, pure access.

**Ticket's stated fit:** issue #4 doesn't state a north-star fit itself — nothing to correct.

**Owner-gate note (my own call, flagging it rather than silently assuming):** "Any look change" nominally wants a mock-up on the ticket; #4 carries none, but it's `ready-for-agent` with an explicit "What to build" naming the exact three endpoints, the same authorization level the already-shipped Activity/Health tabs were built under. I'm treating the ticket text itself as the mock-up substitute and shipping screenshots on the PR, consistent with existing precedent in this repo — not inventing new scope.

## Tests to write first

Issue #4 has no "How we'll try to break it" section, so this is derived from the north-star guiding principles, applied per boundary:

**MarvinCore — `DocsModelsTests.swift` (new, decoding, mirrors `BackendClientTests.swift` style)**
1. `/docs/repos` decodes `generated_at` + `repos[]`, including the `__master__` ("Where things are") entry.
2. `/docs/repos` tolerates a repo row missing optional fields (`name`/`kind`/`status`/`local` all absent) — only `id` is required.
3. `/docs/tree?id=` decodes `source`/`dir`/`tree[]` into `entries`.
4. `/docs/tree` with an empty `tree: []` decodes to zero entries, not an error.
5. `/docs/content` decodes a plain string `data` payload (reusing `get<String>` — proves no special-casing was needed).
6. A 403 from any of the three routes surfaces `BackendError.notAllowlisted` (same as existing routes) — dependency (backend) failing.
7. A 500 with `{ok:false,error:"..."}` surfaces `BackendError.server(message)` — dependency failing, matches `aBackendErrorSurfacesItsMessage`.
8. Malformed JSON body (truncated/garbage) surfaces `BackendError.badResponse` rather than crashing — malformed input.

**MarvinCore — `DocsMarkdownTests.swift` (new, pure function, no network)**
9. Plain text with no markdown renders verbatim (no characters dropped or added).
10. `**bold**`/`*italic*`/`` `code` ``/`[text](url)` render as styled runs, not literal asterisks/brackets — the actual feature.
11. Unbalanced/malformed markdown (e.g. a dangling `**`) does not throw out to the caller — falls back to verbatim text, never crashes the view.
12. A string containing literal `%`, `%@`, `%d` renders those characters unchanged (regression guard for the `LocalizedStringKey` footgun I'm deliberately avoiding).
13. Empty string renders to an empty, non-crashing result.
14. A huge input (~500 KB, realistic worst case for a doc file) renders without crashing or hanging — bounds the cost of pathological huge input.
15. Embedded control/newline characters survive (line breaks preserved, not collapsed into one paragraph) — `.inlineOnlyPreservingWhitespace` is the reason this option is chosen over the full/block parser.

**App layer (light checks only, per PRD #152 Testing Decisions — SwiftUI isn't `swift test`-able here, verified through the simulator build + screenshots instead):**
16. Demo mode: `-tab docs` reaches the repo list with no taps.
17. Demo mode: `-tab docs -demoDocsId __master__` deep-links straight to that repo's tree with no taps.
18. Demo mode: `-tab docs -demoDocsId __master__ -demoDocsPath <file>` deep-links straight to that file's rendered content with no taps.
19. Empty repos list → "no docs yet"-style empty state, not a blank screen (person's mistake / stale state: registry briefly empty).
20. Empty tree (a repo with zero tracked files) → empty state, not a blank screen.
21. A `BackendError` on any of the three calls while online → the existing `error`-text pattern (`ActivityView`/`HealthView`'s convention), not a crash; while offline, the `ConnectionBanner` already explains it so the per-screen error text is suppressed (matches existing `model.connection.status == .online` guard) — never double-messaged.
22. Rapid navigation (push tree → pop → push a different repo's tree before the first load finishes) relies on SwiftUI's per-destination `.task` cancellation-on-disappear (same guarantee every other tab already depends on) — documented, not re-implemented.

**Untested behavior I must state plainly (per the playbook — I can't run the simulator myself):** the actual rendered look of nested-block markdown (headers, lists, code fences) is untested visually beyond what the pipeline's own post-build screenshot step captures; `AttributedString(markdown:, .inlineOnlyPreservingWhitespace)` only styles inline spans, so headers/lists will render as plain paragraphs with their markdown punctuation stripped, not as structured headings/bullets — an honest, named limitation of this v1, not a bug.

## Decisions

None. The ticket names the exact three endpoints and this repo's existing tabs (Activity, Health) already fix every layout/pattern choice this ticket needs — there's no real design fork to put to Gil as buttons.

## Task List

1. **MarvinCore models** (`Packages/MarvinCore/Sources/MarvinCore/Models.swift`): add `DocsRepo`, `DocsRepos` (`generated_at`→`generatedAt`), `DocsTreeEntry` (`Identifiable` via `path`), `DocsTree` (`tree`→`entries`). Write tests 1–8 first (new `DocsModelsTests.swift`).
2. **BackendClient** (`BackendClient.swift`): add `docsRepos()`, `docsTree(id:)`, `docsContent(id:path:)` using the existing `get` helper. (Covered by tests 1–8, which exercise the client end to end via `StubProtocol`.)
3. **DocsMarkdown** (new `Packages/MarvinCore/Sources/MarvinCore/DocsMarkdown.swift`): pure `render(_ text: String) -> AttributedString` using `AttributedString(markdown:options:)` with `.inlineOnlyPreservingWhitespace`, falling back to verbatim on throw. Write tests 9–15 first (new `DocsMarkdownTests.swift`).
4. **DemoBackend** (`DemoBackend.swift`): add `/docs/repos`, `/docs/tree`, `/docs/content` fixtures (master doc first, 2 sample repos, a small tree, one markdown-flavored content string) to the `response(for:)` switch. Confirms tests 16–18's deep links have real data to show.
5. **Theme.Page** (`Theme.swift`): add an optional `path: Binding<NavigationPath>? = nil` parameter to `Page`, using `NavigationStack(path:)` when supplied, falling back to today's plain `NavigationStack` otherwise — a backward-compatible extension; every existing call site (`Page(title:) { … }`) keeps compiling unchanged.
6. **DocsView** (new `Apps/Marvin/Sources/DocsView.swift`): `DocsRoute` enum (`.tree(id:name:)`, `.file(id:path:name:)`); `DocsReposView` (list, `__master__` sorted first, empty/error states per tests 19–21); `DocsTreeView` (`LazyVStack` — tree size is a priori unbounded, unlike the small bounded Activity/Health lists); `DocsFileView` (fetches content, renders via `DocsMarkdown.render`, `.textSelection(.enabled)` to match `CheckDetail`'s convention). Owns `@State private var path = NavigationPath()`, reads `-demoDocsId`/`-demoDocsPath` from `UserDefaults` in demo mode only (mirrors `-demoPrompt`) to satisfy tests 17–18.
7. **Wire the tab** (`MarvinApp.swift`): replace the Docs `ComingSoonView` with `DocsView()`.
8. **Screenshots** (`scripts/screenshots.sh`): add `8-docs-tree` (`-tab docs -demoDocsId __master__`) and `9-docs-file` (`-tab docs -demoDocsId __master__ -demoDocsPath <demo-fixture-path>`) shot lines; the pipeline's own post-build step captures these — I cannot run the simulator myself.
9. Run `swift test --package-path Packages/MarvinCore` to confirm everything green before handoff.