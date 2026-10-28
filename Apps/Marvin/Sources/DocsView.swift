import MarvinCore
import SwiftUI

/// Navigation routes for the Docs tab.
enum DocsRoute: Hashable {
    case tree(id: String, name: String)
    case file(id: String, path: String, name: String)
}

struct DocsView: View {
    @Environment(AppModel.self) private var model
    @State private var path = NavigationPath()
    @State private var repos: DocsRepos?
    @State private var error: String?
    @State private var loading = true

    var body: some View {
        Page(title: "Docs", path: $path) {
            Group {
                if let error, model.connection.status == .online {
                    VStack(alignment: .leading) {
                        Text(error).font(.footnote).foregroundStyle(Theme.muted).padding()
                    }
                } else if let repos {
                    DocsReposView(repos: repos, path: $path)
                } else if loading {
                    VStack {
                        Spacer()
                        ProgressView().tint(Theme.secondary)
                        Spacer()
                    }
                } else {
                    VStack(alignment: .center) {
                        Spacer()
                        Text("No docs available").foregroundStyle(Theme.muted)
                        Spacer()
                    }
                }
            }
            .navigationDestination(for: DocsRoute.self) { route in
                switch route {
                case .tree(let id, let name):
                    DocsTreeView(id: id, name: name, path: $path)
                case .file(let id, let filePath, let name):
                    DocsFileView(id: id, path: filePath, name: name)
                }
            }
        }
        .task {
            await loadRepos()
            // In demo mode, navigate to a specific file if `-demoDocsId` and `-demoDocsPath` are set.
            if model.isDemo, let docsId = model.demoDocsId, let docsPath = model.demoDocsPath {
                // Find the file name from the path.
                let fileName = (docsPath.split(separator: "/").last.map(String.init)) ?? docsPath
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    path.append(DocsRoute.tree(id: docsId, name: docsId))
                    path.append(DocsRoute.file(id: docsId, path: docsPath, name: fileName))
                }
            } else if model.isDemo, let docsId = model.demoDocsId {
                // Navigate to just the tree view.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    path.append(DocsRoute.tree(id: docsId, name: docsId))
                }
            }
        }
    }

    private func loadRepos() async {
        guard let client = model.client else {
            loading = false
            return
        }
        do {
            repos = try await client.docsRepos()
            error = nil
        } catch {
            self.error = error.localizedDescription
            repos = nil
        }
        loading = false
    }
}

private struct DocsReposView: View {
    let repos: DocsRepos
    @Binding var path: NavigationPath

    var body: some View {
        if repos.repos.isEmpty {
            VStack(alignment: .center) {
                Spacer()
                Text("No docs available").foregroundStyle(Theme.muted)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedRepos) { repo in
                        NavigationLink(value: DocsRoute.tree(id: repo.id, name: repo.name ?? repo.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(repo.name ?? repo.id)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.text)
                                if let description = repo.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Theme.card, in: .rect(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var sortedRepos: [DocsRepo] {
        var sorted = repos.repos
        sorted.sort { a, b in
            if a.id == "__master__" { return true }
            if b.id == "__master__" { return false }
            let aName = a.name ?? a.id
            let bName = b.name ?? b.id
            return aName < bName
        }
        return sorted
    }
}

private struct DocsTreeView: View {
    @Environment(AppModel.self) private var model
    let id: String
    let name: String
    @Binding var path: NavigationPath
    @State private var tree: DocsTree?
    @State private var error: String?
    @State private var loading = true

    var body: some View {
        Group {
            if let error {
                Text(error).font(.footnote).foregroundStyle(Theme.muted).padding()
            } else if let tree {
                if tree.entries.isEmpty {
                    VStack(alignment: .center) {
                        Spacer()
                        Text("No files in this repository").foregroundStyle(Theme.muted)
                        Spacer()
                    }
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(tree.entries) { entry in
                            if entry.type == "file" {
                                NavigationLink(value: DocsRoute.file(id: id, path: entry.path, name: entry.name)) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text")
                                            .frame(width: 20)
                                            .foregroundStyle(Theme.secondary)
                                        Text(entry.name)
                                            .foregroundStyle(Theme.text)
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Theme.raised, in: .rect(cornerRadius: 8))
                                }
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "folder")
                                        .frame(width: 20)
                                        .foregroundStyle(Theme.secondary)
                                    Text(entry.name)
                                        .foregroundStyle(Theme.secondary)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Theme.card, in: .rect(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                            }
                        }
                    }
                    .padding()
                }
            } else if loading {
                VStack {
                    Spacer()
                    ProgressView().tint(Theme.secondary)
                    Spacer()
                }
            } else {
                VStack(alignment: .center) {
                    Spacer()
                    Text("No files in this repository").foregroundStyle(Theme.muted)
                    Spacer()
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTree() }
    }

    private func loadTree() async {
        guard let client = model.client else {
            loading = false
            return
        }
        do {
            tree = try await client.docsTree(id: id)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

private struct DocsFileView: View {
    @Environment(AppModel.self) private var model
    let id: String
    let path: String
    let name: String
    @State private var content: String?
    @State private var error: String?

    var body: some View {
        Group {
            if let error {
                Text(error).font(.footnote).foregroundStyle(Theme.muted).padding()
            } else if let content {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        let rendered = DocsMarkdown.render(content)
                        Text(rendered)
                            .textSelection(.enabled)
                            .font(.body)
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
            } else {
                VStack {
                    Spacer()
                    ProgressView().tint(Theme.secondary)
                    Spacer()
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadContent() }
    }

    private func loadContent() async {
        guard let client = model.client else { return }
        do {
            content = try await client.docsContent(id: id, path: path)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
