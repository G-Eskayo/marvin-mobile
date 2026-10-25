import MarvinCore
import SwiftUI

/// Top-level repo list for the Docs tab: lists available documentation repositories.
struct DocsView: View {
    @Environment(AppModel.self) private var model
    @State private var repos: [DocRepo] = []
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        Page(title: "Docs") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let error, model.connection.status == .online {
                        Text(error).font(.footnote).foregroundStyle(Theme.muted)
                    }
                    if !repos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Projects")
                            VStack(spacing: 0) {
                                ForEach(repos) { repo in
                                    NavigationLink { DocsRepoView(repo: repo) } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(repo.name).font(.subheadline.weight(.medium))
                                                Text(repo.path).font(.caption.monospaced()).foregroundStyle(Theme.muted)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
                                        }
                                        .multilineTextAlignment(.leading)
                                        .padding(12)
                                        .foregroundStyle(Theme.text)
                                    }
                                    if repo.id != repos.last?.id { Divider().overlay(Theme.border) }
                                }
                            }
                            .background(Theme.card, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                        }
                    }
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

    private func load() async {
        guard let client = model.client else { return }
        do {
            repos = try await client.docsRepos()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}

/// Displays one repository's docs tree, with full tree fetched once.
struct DocsRepoView: View {
    let repo: DocRepo
    @Environment(AppModel.self) private var model
    @State private var tree: [DocTreeEntry] = []
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        Page(title: repo.name) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let error, model.connection.status == .online {
                        Text(error).font(.footnote).foregroundStyle(Theme.muted)
                    }
                    if !tree.isEmpty {
                        DocsTreeLevel(path: "/", tree: tree, repoPath: repo.path)
                    }
                    if loaded, tree.isEmpty, error == nil {
                        Text("This repository has no docs").foregroundStyle(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            tree = try await client.docsTree(repo: repo.path)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}

/// Renders one level of the tree (recursive, parameterized by path).
struct DocsTreeLevel: View {
    let path: String
    let tree: [DocTreeEntry]
    let repoPath: String

    var body: some View {
        let children = tree.first?.children(of: path, in: tree) ?? []
        VStack(alignment: .leading, spacing: 0) {
            ForEach(children) { entry in
                if entry.isDir {
                    NavigationLink { DocsTreeLevel(path: entry.path, tree: tree, repoPath: repoPath) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder").font(.caption2).foregroundStyle(Theme.accent)
                            Text(entry.name).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
                        }
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 10).padding(.horizontal, 12)
                        .foregroundStyle(Theme.text)
                    }
                } else {
                    NavigationLink { DocsContentView(repo: repoPath, path: entry.path) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text").font(.caption2).foregroundStyle(Theme.secondary)
                            Text(entry.name).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
                        }
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 10).padding(.horizontal, 12)
                        .foregroundStyle(Theme.text)
                    }
                }
                if entry.id != children.last?.id { Divider().overlay(Theme.border).padding(.horizontal, 12) }
            }
        }
        .background(Theme.card, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
    }
}

/// Displays one document's content (markdown rendered via AttributedString, with plain text fallback).
struct DocsContentView: View {
    let repo: String
    let path: String
    @Environment(AppModel.self) private var model
    @State private var content: String = ""
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let error, model.connection.status == .online {
                    Text(error).font(.footnote).foregroundStyle(Theme.muted)
                }
                if loaded {
                    if path.hasSuffix(".md") {
                        markdownContent
                    } else {
                        Text(content).font(.body.monospaced()).textSelection(.enabled)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Theme.background)
        .task { await load() }
    }

    @ViewBuilder
    private var markdownContent: some View {
        if let attributed = try? AttributedString(markdown: content) {
            Text(attributed).textSelection(.enabled)
        } else {
            Text(content).font(.body.monospaced()).textSelection(.enabled)
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            content = try await client.docsContent(repo: repo, path: path)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}
