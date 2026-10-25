import MarvinCore
import SwiftUI

struct BoardColumnsView: View {
    @Environment(AppModel.self) private var model
    @State private var board: BoardDetail?
    @State private var queue: QueueResponse?
    @State private var error: String?
    @State private var loaded = false

    let repo: String
    var onCardTap: (Card) -> Void = { _ in }

    var body: some View {
        VStack {
            if let error, model.connection.status == .online {
                Text(error).font(.footnote).foregroundStyle(Theme.muted)
                    .padding()
            }
            if let board {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(board.columns) { column in
                            ColumnView(column: column, onCardTap: { card in
                                onCardTap(card)
                            })
                        }
                    }
                    .padding()
                }
            }
            Spacer()
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            async let b = client.boardDetail(repo: repo)
            async let q = client.queue()
            (board, queue) = try await (b, q)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}

private struct ColumnView: View {
    let column: BoardColumn
    var onCardTap: (Card) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(column.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            VStack(spacing: 8) {
                ForEach(column.cards) { card in
                    CardRowView(card: card, onTap: { onCardTap(card) })
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(minWidth: 280)
        .background(Theme.raised, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }
}

private struct CardRowView: View {
    let card: Card
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title).font(.callout.weight(.medium)).lineLimit(2)
                        Text("#\(card.number)").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if let progress = card.progress {
                        Text("\(progress.percent)%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.secondary)
                    }
                }
                if let reason = card.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(2)
                }
                if !card.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(card.tags) { tag in
                            Text(tag.label)
                                .font(.caption2)
                                .foregroundStyle(tagColor(tag.kind))
                        }
                        Spacer()
                    }
                }
                if !card.prLinks.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(card.prLinks.prefix(2)) { pr in
                            HStack(spacing: 2) {
                                Image(systemName: pr.hasDevEvidence ? "checkmark.circle.fill" : "circle")
                                    .font(.caption)
                                Text("#\(pr.number)")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.border, in: .rect(cornerRadius: 4))
                            .foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(10)
            .background(Theme.card, in: .rect(cornerRadius: 8))
            .foregroundStyle(Theme.text)
        }
    }

    private func tagColor(_ kind: Tag.Kind) -> Color {
        switch kind {
        case .blocker: .red
        case .milestone: Theme.accent
        case .review: Theme.color(.yellow)
        case .inProgress: Theme.color(.green)
        case .done: Theme.muted
        }
    }
}
