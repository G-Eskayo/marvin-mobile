## North-star fit

Reuses, before adding anything: `ActivityView.swift`'s self-contained `@State` + `load()` pattern for the repo list; `HealthView.swift`'s `group(_:_:)` + `NavigationLink` pattern for rendering the tree's sections; `Theme.swift`'s `Page`/`SectionLabel`/`Card` primitives; `BackendClient`'s existing generic `get<T: Decodable>(path:query:)` helper (already handles the `{ok,data,error}` envelope, 403/500 mapping) — Docs needs three thin methods on top of it, no new networking plumbing; `MarvinApp.swift`'s `-tab`/`-demoPrompt` UserDefaults launch-arg convention (already used by `RootView`/`ThreadView`) to deep-link screenshots into the tree and content screens without taps; `DemoBackend`'s URLProtocol-stub fixture pattern for demo data.

Simplest sufficient approach: the backend contract is already built and merged (`G-Eskayo/marvin#156`, then reworked by `#565`/`#571`) — `GET /docs/repos` → `{generated_at, repos:[{id,name,kind,status,local,...}]}` (master "Where things are" first, then catalog projects), `GET /docs/tree?id=` → `{source, dir, tree:[...]}` (entries are either a leaf `{path,label}` or a group `{section,items:[...]}`), `GET /docs/content?id=&path=` → data is the raw file text. The phone side is just three `get()` calls, three models, and three thin views. Markdown rendering uses Foundation's built-in `AttributedString(markdown:)` (package targets iOS 26/macOS 26) — zero new dependencies, so it needs no owner sign-off under the dependency gate.

Token/resource cost: small, self-contained diff; no new caching/freshness layer on the phone — the backend's saved-copy + revalidate logic (`#565`) already keeps GitHub calls off the hot path server-side, so the client just reads what it's given each time a screen opens (O(payload size) time and space per open, released on dismiss; no client-side cache to reason about).

Phone-OS fit: completes PRD #152 story 36 ("read docs... read-only, so I can check a decision on the go") — one more desktop-dashboard surface mirrored on the phone.

More capable or more passive: more capable — read access to the same design record Gil already consults at a desk, strictly read-only, while away from a keyboard. Doesn't replace any judgment he exercises.

## Decisions

None needed. The ticket and the already-merged backend contract are concrete enough to build against. One scope call I'm making unilaterally, not a toss-up: **rendered Markdown does not fetch/display embedded images in v1** — the ticket only asks for "a file rendered as Markdown," and the desktop has an open, unresolved bug class around doc-relative image paths (`marvin#539`). Building phone-side image fetching now would just import that same unresolved problem for a capability nobody asked for. An image reference renders as its literal Markdown text (AttributedString's markdown parser doesn't execute or fetch anything either way, so this is also a non-issue for safety).

## Tests first (MarvinCore — logic lives there, per repo convention)

The ticket carries no "How we'll try to break it" section, so these are drawn from the general misuse categories (bad/empty/huge/malformed input, each dependency failing, repeats/concurrency, wrong permissions, stale state, a person's mistakes), applied to the three new `BackendClient` calls and the new Markdown-render helper. Mirrors the existing style in `BackendClientTests.swift` / `DemoBackendTests.swift`.

1. `docsRepos()` decodes a normal payload (master first, then project repos) — good input.
2. `docsRepos()` decodes an empty `repos: []` — empty input.
3. `docsRepos()` on a 500 surfaces `BackendError.server(message)` — dependency failure (reuses the existing pattern, new call site).
4. `docsRepos()` on a 403 surfaces `BackendError.notAllowlisted` — wrong permissions.
5. `docsTree(id:)` decodes a tree mixing flat leaves and a `{section, items}` group.
6. `docsTree(id:)` decodes the master's single-file tree.
7. `docsTree(id:)` decodes an empty `tree: []` — empty input / a person opening a doc-less project.
8. `docsTree(id:)` on a malformed node (neither `path` nor `section`) throws rather than silently fabricating data or crashing — malformed input, consistent with how every other model in this file already behaves (caught by the existing view-level `catch { error = ... }` pattern, nothing new to add there).
9. `docsTree(id:)` on an unknown id surfaces the backend's `"Unknown project: X"` as `BackendError.server(...)` — a person's mistake / stale id.
10. `docsContent(id:path:)` decodes a normal markdown string.
11. `docsContent(id:path:)` decodes an empty string — empty input (empty file).
12. `docsContent(id:path:)` decodes a huge string (hundreds of KB) without special-casing — huge input, proves there's no silent truncation.
13. `docsContent(id:path:)` correctly round-trips a path with spaces, `&`, and `/` through the query string (the backend contract requires URL-encoding) — malformed/tricky input, proves the existing `get(path:query:)` encoding is reused correctly rather than needing new escaping code.
14. Concurrent `docsContent` calls for different ids/paths never cross-return each other's payload — concurrency, proves `BackendClient`'s statelessness holds for the new calls too (ADR 0063).
15. `DemoBackend` serves `/docs/repos` with "Where things are" first and at least one real repo, `/docs/tree` for a repo, and `/docs/content` for a path — parity with the existing `DemoBackendTests` style, and what makes screenshots possible.
16. `DocsMarkdown.render` on plain text with no markdown syntax.
17. `DocsMarkdown.render` on an empty string.
18. `DocsMarkdown.render` on a large document completes and returns non-empty output — huge input, no hang.
19. `DocsMarkdown.render` on adversarial/unterminated markdown (`**bold` with no close, a dangling `` ` ``, an unterminated link) falls back to plain text instead of throwing uncaught — malformed input.

**Known untested boundary (stated plainly, per the playbook):** the actual repo-list → tree → content tap-through navigation on a simulator is SwiftUI view wiring (light checks only, per PRD #152 Testing Decisions) and I can't run the simulator myself. I'm reaching the tree and content screens for screenshots via two new debug-only launch args (`-docsRepo <id>`, `-docsPath <path>`, read via `UserDefaults.standard.string(forKey:)`, same mechanism `-demoPrompt` already uses) rather than taps — their wiring is covered by this plan, but on-device rendering is unverified until the pipeline's screenshot step runs after this PR.

## Task List

1. [ ] `Models.swift`: add `DocRepo` (`id`, `name`, `kind`, `status` — `local`/`tags`/`repo`/`board` not modeled, unused by the UI), `DocsRepos`, `DocTreeItem`, `DocTreeNode` (custom `init(from:)` branching on presence of `section`), `DocTree`.
2. [ ] `BackendClient.swift`: add `docsRepos()`, `docsTree(id:)`, `docsContent(id:path:)`, reusing the existing `get<T>(path:query:)` helper.
3. [ ] Write tests 1–14 in `BackendClientTests.swift` against the stub protocol.
4. [ ] `DocsMarkdown.swift` (new, MarvinCore): `render(_:) -> AttributedString` with a safe fallback.
5. [ ] `DocsMarkdownTests.swift` (new): tests 16–19.
6. [ ] `DemoBackend.swift`: add `/docs/repos`, `/docs/tree`, `/docs/content` fixtures (master + at least one repo with a grouped tree + markdown content), routed by path and query.
7. [ ] Add test 15 to `DemoBackendTests.swift`.
8. [ ] Run `swift test --package-path Packages/MarvinCore` — green before touching the app layer.
9. [ ] `DocsView.swift` (new, Apps/Marvin/Sources): `DocsView` (repo list, `ActivityView`-style self-contained load), `DocTreeView` (`HealthView`-style grouped list for `{section, items}` nodes, flat rows for leaves), `DocContentView` (fetches and renders via `DocsMarkdown.render`, shown in a `ScrollView`/`Text`). Each reads `-docsRepo`/`-docsPath` launch args in demo mode to support deep-linked screenshots.
10. [ ] `MarvinApp.swift`: replace the Docs tab's `ComingSoonView` with `DocsView()`.
11. [ ] `scripts/screenshots.sh`: append `shot 8-docs-tree` and `shot 9-docs-content` lines using the new launch args (keep the existing `shot 7-docs` line for the repo-list landing screen).
12. [ ] Build the app target, capture the three screenshots, and write the closing-comment how-to-use with use cases (ticket's acceptance criterion).