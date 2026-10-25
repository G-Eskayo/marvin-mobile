# Plan: Docs tab — read-only repos, tree, and Markdown (marvin-mobile#4)

## North-star fit

- **Reuses before adding:** `HealthView`'s group → `NavigationLink` → detail drill-down (`Apps/Marvin/Sources/HealthView.swift:51-108`) for the list→detail navigation shape; `ActivityView`'s local `@State` + `load()` + `.task`/`.refreshable` pattern (`Apps/Marvin/Sources/ActivityView.swift:78-89`) for per-view data fetching (Docs state isn't shared elsewhere, so it doesn't belong in `AppModel` like Health/Thread do); `BackendClient`'s `get<T: Decodable>(_:query:)` plumbing (`Packages/MarvinCore/Sources/MarvinCore/BackendClient.swift:92-107`) for the three new calls; `Severity.init(from:)`'s defensive-decode-to-safe-default pattern (`Packages/MarvinCore/Sources/MarvinCore/Models.swift:31-34`) for tolerating a malformed `isDir` field; `Theme`'s `Page`/`Card`/`SectionLabel` primitives — no new colors, layout primitives, or animations are invented. The existing `shot 7-docs` line in `scripts/screenshots.sh:38` already targets `-tab docs`; it just currently hits the placeholder.
- **Simplest sufficient approach:** one full-tree fetch per repo, filtered client-side per drill-down level (see Decisions/assumptions below for why), instead of a paginated per-folder endpoint — matches how every existing endpoint in this app already fetches its whole resource in one call (no endpoint here is paginated except Thread's `limit`).
- **Token/compute cost:** fetching the tree once per repo and slicing it in pure Swift avoids repeat network round-trips as the user drills into subfolders — an O(N) re-fetch per tap would be the kind of complexity defect the "space/time complexity = correctness" rule flags. The filter itself is O(N) per level, acceptable because `/docs/tree` is scoped to documentation files (small, bounded set), not the full source tree.
- **Phone-OS direction:** read-only cross-repo knowledge, reachable from the phone over Tailscale with no desktop needed — directly OS-shaped (general, linkable, works wherever the tunnel does).
- **User capability:** this is read-only browsing of docs that already exist; it makes Gil more able to check context/ADRs on the go, doesn't automate any judgment away from him.

## Open question — no mock-up is attached

This is a look change (`docs/agents/pr-requirements.md`) and the ticket carries no mock-up, which the playbook's owner gates say I must flag rather than decide alone. I'm proceeding anyway because the design below invents nothing new visually — it is HealthView's exact list→`NavigationLink`→detail shape, reapplied one level deeper, using only existing `Theme` primitives. The Decisions block below gives Gil a button to redirect it if he wants a real mock-up instead.

## Assumption needing verification against the real backend (not a Gil preference — a fact I couldn't check)

I have no read access from this worktree to the marvin repo's dashboard backend source (gh is restricted to `view/list/diff`, no `gh api`/`search`, and outbound web fetches are blocked in this sandbox), so I can't confirm the exact JSON shapes of `/docs/repos`, `/docs/tree`, `/docs/content`. I'm assuming, consistent with every other endpoint in `BackendClient`:
- `GET /docs/repos` → `{ok:true,"data":[{"repo":"owner/name","name":"display name"}...]}`
- `GET /docs/tree?repo=<repo>` → `{ok:true,"data":[{"path":"adr/0001-foo.md","isDir":false}...]}` (flat list, whole repo's doc tree in one call)
- `GET /docs/content?repo=<repo>&path=<path>` → `{ok:true,"data":"<raw markdown text>"}`

Whoever builds this must check these against the desktop Docs tab's actual backend calls before wiring `BackendClient`, and adjust the model/decoding if the real shape differs (e.g., nested tree instead of flat, or a wrapped `{content, truncated}` object for content). I'm stating this plainly rather than guessing silently and shipping it as fact.

<!-- marvin:decisions -->
### d1: No mock-up is attached to this look change — proceed with HealthView's existing drill-down pattern, or hold for a mock-up?
- [ ] Proceed: reuse HealthView's list → NavigationLink → detail pattern (Repos → Tree → Markdown), no new layout/colors
- [ ] Hold: wait for a mock-up before building

### d2: Cap on how much of a single doc file the phone renders?
- [ ] No cap for v1 — render whatever `/docs/content` returns
- [ ] Cap at a fixed size (e.g. 200 KB) with a "truncated — open on desktop" note

### d3: Non-Markdown files in the tree (if the backend's doc tree ever includes any, e.g. images or `.txt`)
- [ ] Show them, tap opens the raw text (monospaced), same as a `.md` parse failure
- [ ] Hide them from the tree entirely (Markdown-only tab)
<!-- /marvin:decisions -->

## Tests first (MarvinCore — logic, no simulator needed)

The ticket has no "How we'll try to break it" section, so these come from the north stars' generic misuse list, calibrated to the existing test depth in `BackendClientTests.swift` / `DemoBackendTests.swift`:

**`BackendClientTests` (new cases, same `StubProtocol` fixture pattern):**
1. `docsReposDecodesRepoRows` — happy path, asserts repo/name decode.
2. `docsTreeDecodesEntries` — happy path for `/docs/tree?repo=...`, asserts the query param is sent and entries decode.
3. `docsTreeToleratesAMissingIsDirField` — malformed/partial entry (mirrors `activityToleratesMissingOptionalFields`): defaults to "not a directory" rather than failing the whole decode.
4. `docsContentDecodesRawText` — happy path for `/docs/content?repo=...&path=...`, asserts both query params reach the request.
5. `docsEndpointsSurfaceAServerError` — 500/`{"ok":false,"error":...}` on each of the three calls surfaces `BackendError.server` (mirrors `aBackendErrorSurfacesItsMessage`).
6. `docsEndpointsAreRejectedWhenNotAllowlisted` — 403 → `BackendError.notAllowlisted` (dependency-failure case already proven generically but worth one concrete assertion since these are new call sites).
7. `docsContentHandlesAnEmptyFile` — `data:""` decodes to an empty string, not a crash or `badResponse`.
8. `docsTreeHandlesAnEmptyRepo` — `data:[]` decodes to an empty array.
9. `docsRepoAndPathWithSpecialCharactersAreSentVerbatimAndEncoded` — a repo path with a space/`&`/unicode character round-trips through `URLQueryItem` without corrupting the request (malformed-input-at-the-boundary case; this is the one place user-visible navigation state becomes a URL).

**New `DocsTreeTests.swift` (pure logic, the pattern worth isolating since it's the one new non-trivial algorithm):**
10. `childrenOfRootReturnsTopLevelEntriesOnly` — flat list → correct first-level files/dirs.
11. `childrenOfAPathReturnsOnlyThatPathsDirectChildren` — nested drill-down filter is exactly one level deep (never two levels at once — "one control per drill-down level").
12. `childrenToleratesAnEmptyTree` — no entries → empty children, no crash.
13. `childrenDedupesRepeatedPaths` — the same path appearing twice in the backend's response doesn't produce duplicate `Identifiable` rows (would otherwise break SwiftUI's `ForEach`).
14. `childrenInfersDirectoriesFromDeeperPaths` — a path like `"adr/0001-foo.md"` with no explicit `"adr"` directory entry still produces an `"adr"` folder row.
15. `childrenIgnoresPathTraversalSegments` — an entry path containing `".."` or a leading `"/"` doesn't escape its repo's own subtree or produce a broken/garbage row (defensive display-layer handling; the real traversal defense is the backend's, out of scope here, but the app must not render nonsense from it).
16. `childrenSortDirectoriesBeforeFilesThenAlphabetically` — stable, predictable ordering.

**`DemoBackendTests` (new cases, so demo mode — and therefore screenshots — has real fixture data):**
17. `servesDocsRepos` — non-empty, has at least the "Where things are" entry first (matches the ticket's own wording).
18. `servesDocsTreeForARepo` — non-empty tree for the demo repo.
19. `servesDocsContentForAFile` — returns non-empty markdown text for a known demo path.
20. `docsEndpointsReturn404ForAnUnknownRepoOrPath` — demo backend's existing `default: (404, ...)` fallback (`DemoBackend.swift:25`) is exercised for an unrecognized repo/path, proving the UI's error path is reachable in demo mode too.

**Markdown-rendering fallback (view-layer, light check per PRD #152 Testing Decisions — not a MarvinCore test, but noted so the task list doesn't skip it):** malformed markdown text must fall back to plain text display rather than crash or show a blank screen. Since SwiftUI views only get light checks, this is verified by eye in the simulator screenshot set (one fixture entry deliberately has unbalanced markdown), not a `swift test` case.

## Task List

1. **`MarvinCore` models** (`Models.swift` or a new `DocsModels.swift`): add `DocRepo` and `DocTreeEntry` (with the defensive `isDir` decode).
2. **`DocsTree.swift`** (new file in `MarvinCore`): the pure `DocTreeEntry.children(of:in:)` function — dedupe, directory-inference, traversal-segment handling, directories-first sort.
3. **`BackendClient`**: add `docsRepos()`, `docsTree(repo:)`, `docsContent(repo:path:)` using the existing `get(_:query:)` plumbing.
4. **`DemoBackend`**: add `/docs/repos`, `/docs/tree`, `/docs/content` cases to `response(for:)`, with fixture data headed by a "Where things are" entry, a small nested tree, and one deliberately-malformed-markdown fixture file for the fallback check.
5. **Tests**: write items 1–20 above (`BackendClientTests`, new `DocsTreeTests`, `DemoBackendTests`) before any view code; confirm they fail against the current code, then make them pass.
6. **`DocsView.swift`** (new file in `Apps/Marvin/Sources`): top-level repo list (`Page(title: "Docs")`, `ActivityView`-style `@State`/`load()`/`.task`/`.refreshable`), each row a `NavigationLink` to `DocsRepoView`.
7. **`DocsRepoView`**: fetches the repo's full tree once (`.task`), owns it as `@State`, renders the root level via `DocsTreeLevel`.
8. **`DocsTreeLevel`** (recursive, parameterized by `path`): renders `DocTreeEntry.children(of:in:)` for the current path; directory rows push another `DocsTreeLevel` one level deeper, file rows push `DocsContentView`.
9. **`DocsContentView`**: fetches content via `.task`, renders `AttributedString(markdown:)` for `.md` paths with a plain-text fallback on a parse throw, `Text(...).font(.body.monospaced())` with `.textSelection(.enabled)` otherwise (matching `CheckDetail`'s selection pattern).
10. **`MarvinApp.swift`**: replace the Docs tab's `ComingSoonView` with `DocsView()`.
11. **`scripts/screenshots.sh`**: extend the existing `shot 7-docs` step (or add adjacent `shot`s) to also capture the tree level and an open Markdown file, via a debug-only launch argument reaching that nav state, since the pipeline's screenshot stage can't tap through the UI itself.
12. **Verify**: `swift test --package-path Packages/MarvinCore` green; state plainly in the PR which behavior (the malformed-markdown fallback's visual appearance, and anything needing the real desktop backend's actual JSON shapes) remains unverified by me.
13. **PR**: closing comment/PR body carries the simulator screenshots, "you want X → tap Y → see Z" use cases per `docs/agents/pr-requirements.md`, and the Decisions block (d1–d3) for Gil to answer.