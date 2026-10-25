import MarvinCore
import SwiftUI

struct TicketDetailView: View {
    @Environment(AppModel.self) private var model
    let repo: String
    let number: Int
    @State private var detail: TicketDetail?
    @State private var timeline: [TimelineEvent]?
    @State private var relations: TicketRelations?
    @State private var error: String?
    @State private var isLoading = true
    @State private var replyText = ""
    @State private var isReplying = false
    @State private var replyError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let error, model.connection.status == .online {
                    Text(error).font(.footnote).foregroundStyle(Theme.muted)
                }
                if let detail {
                    header(detail)
                    labels(detail)
                    if let relations, !relations.prs.isEmpty {
                        prChips(relations.prs)
                    }
                    if let timeline {
                        pipelineHistory(timeline)
                    }
                    if let relations {
                        relatedContent(relations)
                    }
                    commentsSection(detail)
                    replyBox(detail)
                }
            }
            .padding()
        }
        .task { await load() }
        .navigationTitle(detail.map { "#\($0.number) \($0.title)" } ?? "#\(number)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ detail: TicketDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(detail.title).font(.title3.weight(.semibold))
            Text(detail.body).font(.footnote).foregroundStyle(Theme.secondary)
                .lineLimit(3)
        }
    }

    private func labels(_ detail: TicketDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Labels").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            HStack(spacing: 4) {
                ForEach(detail.labels) { label in
                    Text(label.name).font(.caption2).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.raised, in: .rect(cornerRadius: 4))
                }
                Spacer()
            }
        }
    }

    private func prChips(_ prs: [RelatedPR]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pull Requests").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            VStack(spacing: 6) {
                ForEach(prs) { pr in
                    HStack(spacing: 8) {
                        Image(systemName: "git.branch")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PR #\(pr.number) \(pr.title)").lineLimit(1)
                            Text(pr.isDraft ? "Draft" : "Ready").font(.caption2).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Theme.raised, in: .rect(cornerRadius: 8))
                    .onTapGesture { model.activeTab = "review" }
                }
            }
        }
    }

    private func pipelineHistory(_ timeline: [TimelineEvent]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pipeline History").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            VStack(spacing: 0) {
                ForEach(Array(timeline.prefix(5).enumerated()), id: \.offset) { idx, event in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.stage).font(.footnote.weight(.semibold))
                            Text(event.status).font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(event.timestamp).font(.caption.monospaced()).foregroundStyle(Theme.muted)
                            if let cost = event.costUsd, cost > 0 {
                                Text(cost, format: .currency(code: "USD").precision(.fractionLength(2)))
                                    .font(.caption2).foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                    .padding(10)
                    if idx < timeline.prefix(5).count - 1 { Divider().overlay(Theme.border) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
    }

    private func relatedContent(_ relations: TicketRelations) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !relations.tickets.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Related Tickets").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    VStack(spacing: 4) {
                        ForEach(relations.tickets) { ticket in
                            HStack(spacing: 8) {
                                Text("#\(ticket.number) \(ticket.title)").lineLimit(1)
                                if let column = ticket.column {
                                    Text(column).font(.caption2).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(Theme.raised, in: .rect(cornerRadius: 8))
                        }
                    }
                }
            }
            if !relations.docs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Related Docs").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    VStack(spacing: 4) {
                        ForEach(relations.docs) { doc in
                            HStack(spacing: 8) {
                                Text(doc.title).lineLimit(1)
                                if let kind = doc.kind {
                                    Text(kind).font(.caption2).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(Theme.raised, in: .rect(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    private func commentsSection(_ detail: TicketDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Comments (last 5)").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            VStack(spacing: 0) {
                ForEach(Array(detail.comments.suffix(5).enumerated()), id: \.offset) { idx, comment in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(comment.author.login).font(.footnote.weight(.semibold))
                            Text(comment.createdAt).font(.caption2).foregroundStyle(Theme.muted)
                            Spacer()
                        }
                        Text(comment.body).font(.footnote).foregroundStyle(Theme.secondary).lineLimit(2)
                    }
                    .padding(10)
                    if idx < detail.comments.suffix(5).count - 1 { Divider().overlay(Theme.border) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
    }

    private func replyBox(_ detail: TicketDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reply").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            VStack(spacing: 6) {
                TextEditor(text: $replyText)
                    .frame(minHeight: 60).font(.footnote)
                    .padding(8)
                    .background(Theme.raised, in: .rect(cornerRadius: 8))
                if let plan = replyPlan {
                    Text(plan.effect).font(.caption).foregroundStyle(Theme.accent)
                }
                if let err = replyError {
                    Text(err).font(.caption).foregroundStyle(Theme.color(.red))
                }
                HStack {
                    Spacer()
                    Button(action: { Task { await reply() } }) {
                        if isReplying {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Post").font(.footnote.weight(.semibold))
                        }
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isReplying)
                }
            }
        }
    }

    private var replyPlan: ReplyPlan? {
        guard !replyText.isEmpty else { return nil }
        return ReplyPlan.planReply(labels: [], state: nil)
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            async let d = client.ticketDetail(repo: repo, number: number)
            async let t = client.timeline(repo: repo, number: number)
            async let r = client.relationsForTicket(repo: repo, number: number)
            (detail, timeline, relations) = try await (d, t, r)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func reply() async {
        guard let client = model.client else { return }
        guard await FaceIDGate.shared.authenticate() else {
            replyError = "Authentication failed"
            return
        }
        isReplying = true
        do {
            let result = try await client.replyToTicket(repo: repo, number: number, body: replyText)
            if result.posted {
                replyText = ""
                replyError = nil
            } else if let warning = result.warning {
                replyError = warning
            }
        } catch {
            replyError = error.localizedDescription
        }
        isReplying = false
    }
}
