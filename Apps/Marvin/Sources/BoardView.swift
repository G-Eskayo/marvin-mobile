import MarvinCore
import SwiftUI

/// Board detail: columns, cards, and project navigation.
struct BoardView: View {
    @Environment(AppModel.self) private var model
    let repo: String
    let name: String?

    @State private var detail: BoardDetail?
    @State private var error: String?
    @State private var loaded = false
    @State private var navigationPath: [(String, Int)] = []

    var body: some View {
        Page(title: name ?? repo) {
            if loaded, let detail {
                NavigationStack(path: $navigationPath) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let columns = detail.columns, !columns.isEmpty {
                                columns_
                            }
                            if let others = detail.otherProjects, !others.isEmpty {
                                otherProjects_
                            }
                            if let error, model.connection.status == .online {
                                Text(error).font(.footnote).foregroundStyle(Theme.muted)
                            }
                        }
                        .padding()
                    }
                    .navigationDestination(for: (String, Int).self) { tuple in
                        TicketDetailView(repo: tuple.0, number: tuple.1)
                    }
                }
                .refreshable { await load() }
            } else if loaded, error != nil {
                VStack(spacing: 12) {
                    Spacer()
                    Text(error ?? "Couldn't load board").foregroundStyle(Theme.muted)
                    Spacer()
                }
                .padding()
            } else {
                ProgressView().padding()
            }
        }
        .task { await load() }
    }

    @ViewBuilder private var columns_: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Columns")
            if let columns = detail?.columns {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(columns) { column in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(column.name).font(.subheadline.weight(.medium))
                                VStack(spacing: 8) {
                                    if let cards = column.cards {
                                        ForEach(cards) { card in
                                            Button(action: { navigationPath.append((card.repo ?? repo, card.number)) }) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(card.title ?? "#\(card.number)").lineLimit(2)
                                                    if let assignee = card.assignee {
                                                        Text(assignee).font(.caption).foregroundStyle(Theme.muted)
                                                    }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(8)
                                                .background(Theme.raised, in: .rect(cornerRadius: 6))
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: 160)
                            }
                            .padding(8)
                            .background(Theme.card, in: .rect(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var otherProjects_: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Other projects")
            if let projects = detail?.otherProjects {
                VStack(spacing: 0) {
                    ForEach(projects) { proj in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(proj.name ?? proj.repo).font(.subheadline)
                                Text("\(proj.cardCount ?? 0) card\(proj.cardCount == 1 ? "" : "s")").font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.secondary)
                        }
                        .padding(12)
                        if proj.id != projects.last?.id { Divider().overlay(Theme.border) }
                    }
                }
                .background(Theme.card, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            detail = try await client.boardDetail(repo: repo)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}

private struct Page<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title).font(.title2.weight(.semibold))
                Spacer()
            }
            .padding()
            .background(Theme.background)
            Divider().overlay(Theme.border)
            content()
        }
        .background(Theme.background)
    }
}

private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.headline).foregroundStyle(Theme.secondary)
    }
}
