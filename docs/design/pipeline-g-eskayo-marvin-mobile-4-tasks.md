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