import MarvinCore
import SwiftUI

struct BoardColumnsView: View {
    @Environment(AppModel.self) private var model
    let boardDetail: BoardDetail
    @State private var selectedProject: String?
    @State private var selectedTag: String?
    @State private var showArchive = false
    var onCardTapped: (Card) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            projectsRow
            nextUpQueue
            tabsAndFilters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(visibleColumns) { column in
                        columnView(column)
                    }
                }
                .padding(.horizontal)
            }
            Spacer()
        }
        .padding(.vertical)
    }

    private var projectsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(boardDetail.otherProjects) { project in
                    VStack(spacing: 2) {
                        Text(project.name ?? project.projectId).font(.caption.weight(.medium))
                        Text("\(project.count)").font(.caption2).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(selectedProject == project.projectId ? Theme.accent : Theme.raised, in: .rect(cornerRadius: 6))
                    .onTapGesture { selectedProject = selectedProject == project.projectId ? nil : project.projectId }
                }
            }
            .padding(.horizontal)
        }
    }

    private var nextUpQueue: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next up").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            Text("Dispatch queue coming in v2")
                .font(.caption).foregroundStyle(Theme.muted)
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(Theme.raised, in: .rect(cornerRadius: 8))
        }
        .padding(.horizontal)
    }

    private var tabsAndFilters: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(["all", "priority:high", "status:blocked"], id: \.self) { tag in
                        Text(tag).font(.caption.weight(.medium))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(selectedTag == tag ? Theme.accent : Theme.raised, in: .rect(cornerRadius: 4))
                            .onTapGesture { selectedTag = selectedTag == tag ? nil : tag }
                    }
                }
            }
            Spacer()
            Toggle("Done", isOn: $showArchive).font(.caption)
        }
        .padding(.horizontal)
    }

    private var visibleColumns: [BoardColumn] {
        boardDetail.columns.filter { col in
            (col.archive != true) || showArchive
        }
    }

    private func columnView(_ column: BoardColumn) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(column.label).font(.subheadline.weight(.semibold))
            VStack(spacing: 8) {
                ForEach(column.cards) { card in
                    cardRow(card)
                }
            }
        }
        .frame(minWidth: 280)
        .padding(.vertical)
        .background(Theme.card, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }

    private func cardRow(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    if let repo = card.repo, repo != boardDetail.repo {
                        Text(repo.split(separator: "/").last.map(String.init) ?? repo)
                            .font(.caption2).foregroundStyle(Theme.muted)
                    }
                    Text("#\(card.number)").font(.caption.monospaced()).foregroundStyle(Theme.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title).lineLimit(2).font(.footnote.weight(.medium))
                    if let progress = card.progress {
                        HStack(spacing: 4) {
                            ProgressView(value: Double(progress.done), total: Double(progress.total))
                                .frame(height: 6)
                            Text("\(progress.done)/\(progress.total)").font(.caption2).foregroundStyle(Theme.muted)
                        }
                    }
                }
                Spacer()
            }
            if let tags = card.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags) { tag in
                        Text(tag.name).font(.caption2).foregroundStyle(Theme.accent).lineLimit(1)
                    }
                    Spacer()
                }
            }
            if let prLinks = card.prLinks, !prLinks.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "git.branch")
                        .font(.caption2).foregroundStyle(Theme.accent)
                    ForEach(prLinks) { pr in
                        Text("PR #\(pr.number) \(pr.title)").font(.caption2).foregroundStyle(Theme.accent).lineLimit(1)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Theme.raised, in: .rect(cornerRadius: 8))
        .onTapGesture { onCardTapped(card) }
    }
}
