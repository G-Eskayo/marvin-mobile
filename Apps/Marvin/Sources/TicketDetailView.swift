import MarvinCore
import SwiftUI

struct TicketDetailView: View {
    @Environment(AppModel.self) private var model
    @State private var timeline: [TimelineEvent] = []
    @State private var relations: TicketRelations?
    @State private var error: String?
    @State private var replyText = ""
    @State private var isReplying = false
    @State private var replyError: String?
    @State private var showReplyWarning = false

    let card: Card
    let repo: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TicketHeaderView(card: card, repo: repo)
                TimelineView(events: timeline)
                if let relations {
                    RelationsView(relations: relations)
                }
                ReplyBoxView(
                    text: $replyText,
                    isReplying: isReplying,
                    error: replyError,
                    onSend: { await sendReply() }
                )
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("\(repo.split(separator: "/").last ?? repo)#\(card.number)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            async let t = client.timeline(number: card.number, repo: repo)
            async let r = client.relationsForTicket(repo: repo, number: card.number)
            (timeline, relations) = try await (t, r)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func sendReply() async {
        guard !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let client = model.client else { return }

        isReplying = true
        replyError = nil

        let gate = FaceIDGate()
        let authenticated = await gate.authenticate()
        guard authenticated else {
            isReplying = false
            replyError = "Face ID authentication failed"
            return
        }

        do {
            let result = try await client.replyToTicket(repo: repo, number: card.number, body: replyText)
            if result.ok {
                replyText = ""
                replyError = result.warning
            } else {
                replyError = result.message ?? "Failed to send reply"
            }
        } catch {
            replyError = error.localizedDescription
        }
        isReplying = false
    }
}

private struct TicketHeaderView: View {
    let card: Card
    let repo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.title).font(.headline).lineLimit(3)
            HStack(spacing: 8) {
                Text("\(repo.split(separator: "/").last ?? repo)#\(card.number)")
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.muted)
                if let progress = card.progress {
                    Text("\(progress.percent)%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
            }
            if !card.prLinks.isEmpty {
                HStack(spacing: 8) {
                    ForEach(card.prLinks) { pr in
                        Button {
                            model.activeTab = "review"
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: pr.hasDevEvidence ? "checkmark.circle.fill" : "circle")
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(pr.repo.split(separator: "/").last.map { String($0) } ?? pr.repo)
                                        .font(.caption2.weight(.semibold))
                                    Text("#\(pr.number)").font(.caption2)
                                }
                            }
                            .padding(8)
                            .background(Theme.raised, in: .rect(cornerRadius: 6))
                            .foregroundStyle(Theme.accent)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Theme.raised, in: .rect(cornerRadius: 8))
    }
}

private struct TimelineView: View {
    let events: [TimelineEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline").font(.subheadline.weight(.semibold))
            if events.isEmpty {
                Text("No events yet").font(.caption).foregroundStyle(Theme.muted)
            } else {
                VStack(spacing: 0) {
                    ForEach(events) { event in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .center, spacing: 0) {
                                Circle()
                                    .fill(Theme.accent)
                                    .frame(width: 8, height: 8)
                                if event.id != events.last?.id {
                                    Rectangle()
                                        .fill(Theme.border)
                                        .frame(width: 1)
                                        .frame(height: 30)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.eventType).font(.caption.weight(.semibold))
                                Text(event.description).font(.caption).foregroundStyle(Theme.secondary)
                                if let cost = event.costUsd, cost > 0 {
                                    Text(cost, format: .currency(code: "USD").precision(.fractionLength(3)))
                                        .font(.caption2).foregroundStyle(Theme.muted)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(12)
                .background(Theme.card, in: .rect(cornerRadius: 8))
            }
        }
    }
}

private struct RelationsView: View {
    let relations: TicketRelations

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !relations.relatedTickets.isEmpty {
                Text("Related tickets").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                VStack(spacing: 4) {
                    ForEach(relations.relatedTickets) { item in
                        HStack(spacing: 8) {
                            Text("#\(item.number)").font(.caption.monospaced()).foregroundStyle(Theme.secondary)
                            Text(item.title).font(.caption).lineLimit(1)
                            Spacer()
                        }
                        .padding(8)
                        .background(Theme.raised, in: .rect(cornerRadius: 6))
                    }
                }
            }
            if !relations.relatedPRs.isEmpty {
                Text("Related PRs").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                VStack(spacing: 4) {
                    ForEach(relations.relatedPRs) { item in
                        HStack(spacing: 8) {
                            Text("#\(item.number)").font(.caption.monospaced()).foregroundStyle(Theme.secondary)
                            Text(item.title).font(.caption).lineLimit(1)
                            Spacer()
                        }
                        .padding(8)
                        .background(Theme.raised, in: .rect(cornerRadius: 6))
                    }
                }
            }
            if !relations.relatedDocs.isEmpty {
                Text("Related docs").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                VStack(spacing: 4) {
                    ForEach(relations.relatedDocs) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundStyle(Theme.secondary)
                            Text(item.title).font(.caption).lineLimit(1)
                            Spacer()
                        }
                        .padding(8)
                        .background(Theme.raised, in: .rect(cornerRadius: 6))
                    }
                }
            }
        }
    }
}

private struct ReplyBoxView: View {
    @Binding var text: String
    let isReplying: Bool
    let error: String?
    var onSend: () async -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reply").font(.subheadline.weight(.semibold))
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1), in: .rect(cornerRadius: 6))
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .background(Theme.card, in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                .frame(height: 80)
            Button(action: { Task { await onSend() } }) {
                HStack {
                    if isReplying {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text("Send")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.primary)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isReplying)
        }
        .padding(12)
        .background(Theme.raised, in: .rect(cornerRadius: 8))
    }
}
