import MarvinCore
import SwiftUI

/// Main Docs tab: lists repositories, loads tree on selection, renders content.
struct DocsView: View {
    @Environment(AppModel.self) private var model
    @State private var repos: [DocRepo] = []
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        let args = ProcessInfo.processInfo.arguments
        let demoRepoId = args.firstIndex(of: "-docsRepo").flatMap { i in args.indices.contains(i + 1) ? args[i + 1] : nil }
        let demoPath = args.firstIndex(of: "-docsPath").flatMap { i in args.indices.contains(i + 1) ? args[i + 1] : nil }

        if let repoId = demoRepoId, let path = demoPath {
            DocTreeView(repoId: repoId, repoName: nil, deepLink: path)
                .task { await load() }
        } else if let repoId = demoRepoId {
            let repoName = repos.first(where: { $0.id == repoId })?.name
            DocTreeView(repoId: repoId, repoName: repoName, deepLink: nil)
                .task { await load() }
        } else {
            Page(title: "Docs") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error, model.connection.status == .online {
                            Text(error).font(.footnote).foregroundStyle(Theme.muted)
                        }
                        if !repos.isEmpty { repoList }
                        if loaded, repos.isEmpty, error == nil {
                            Text("No docs available").foregroundStyle(Theme.muted)
                        }
                    }
                    .padding()
                }
                .refreshable { await load() }
                .task { await load() }
            }
        }
    }

    private var repoList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Repositories")
            VStack(spacing: 0) {
                ForEach(repos) { repo in
                    NavigationLink { DocTreeView(repoId: repo.id, repoName: repo.name) } label: {
                        RepoRow(repo: repo)
                    }
                    if repo.id != repos.last?.id { Divider().overlay(Theme.border) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            repos = try await client.docsRepos().repos
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}

private struct RepoRow: View {
    let repo: DocRepo

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(repo.name).lineLimit(1)
                Text(repo.id).font(.caption.monospaced()).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
        }
        .multilineTextAlignment(.leading)
        .padding(12)
    }
}

/// Tree browser for a documentation repository.
struct DocTreeView: View {
    @Environment(AppModel.self) private var model
    let repoId: String
    let repoName: String?
    var deepLink: String?

    @State private var tree: [DocTreeItem] = []
    @State private var resolvedRepoName: String?
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        let deepLinkLeaf = loaded ? findLeaf(withPath: deepLink ?? "") : nil

        if let leaf = deepLinkLeaf {
            DocContentView(repoId: repoId, leaf: leaf)
        } else {
            Page(title: "Docs") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error, model.connection.status == .online {
                            Text(error).font(.footnote).foregroundStyle(Theme.muted)
                        }
                        if !tree.isEmpty { treeView }
                        if loaded, tree.isEmpty, error == nil {
                            Text("No documents").foregroundStyle(Theme.muted)
                        }
                    }
                    .padding()
                }
                .task { await load() }
            }
            .navigationTitle(resolvedRepoName ?? repoName ?? "Docs")
        }
    }

    private func findLeaf(withPath path: String) -> DocLeaf? {
        guard !path.isEmpty else { return nil }
        for item in tree {
            if case .section(_, let leaves) = item {
                if let leaf = leaves.first(where: { $0.path == path }) {
                    return leaf
                }
            } else if case .leaf(let leaf) = item, leaf.path == path {
                return leaf
            }
        }
        return nil
    }

    private var treeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(tree, id: \.id) { item in
                switch item {
                case .section(let section, let leaves):
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(section)
                        VStack(spacing: 0) {
                            ForEach(leaves) { leaf in
                                NavigationLink { DocContentView(repoId: repoId, leaf: leaf) } label: {
                                    LeafRow(leaf: leaf)
                                }
                                if leaf.id != leaves.last?.id { Divider().overlay(Theme.border) }
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                    }
                case .leaf(let leaf):
                    NavigationLink { DocContentView(repoId: repoId, leaf: leaf) } label: {
                        LeafRow(leaf: leaf)
                    }
                    .background(Theme.card, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                }
            }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            let docTree = try await client.docsTree(id: repoId)
            tree = docTree.tree
            resolvedRepoName = repoName
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}

private struct LeafRow: View {
    let leaf: DocLeaf

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(leaf.label).lineLimit(1)
                Text(leaf.path).font(.caption.monospaced()).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
        }
        .multilineTextAlignment(.leading)
        .padding(12)
    }
}

/// Document content viewer.
struct DocContentView: View {
    @Environment(AppModel.self) private var model
    let repoId: String
    let leaf: DocLeaf

    @State private var content: String?
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error, model.connection.status == .online {
                    Text(error).font(.footnote).foregroundStyle(Theme.muted)
                }
                if let content {
                    Text(DocsMarkdown.render(content))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !loaded {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle(leaf.label)
        .task { await load() }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            let markdown = try await client.docsContent(id: repoId, path: leaf.path)
            content = markdown
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}
