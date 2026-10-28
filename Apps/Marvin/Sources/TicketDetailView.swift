import MarvinCore
import SwiftUI

/// Ticket detail: body, timeline, related PRs/docs, and reply composer.
struct TicketDetailView: View {
    @Environment(AppModel.self) private var model
    let repo: String
    let number: Int

    @State private var timeline: [TimelineEvent] = []
    @State private var relations: TicketRelations?
    @State private var error: String?
    @State private var loaded = false
    @State private var replyText = ""
    @State private var showingReplyComposer = false

    var body: some View {
        Page(title: "\(shortRepo)#\(number)") {
            if loaded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !timeline.isEmpty { timeline_ }
                        if let relations, hasRelated { related_ }
                        if error != nil, model.connection.status == .online {
                            Text(error ?? "Error loading ticket").font(.footnote).foregroundStyle(Theme.muted)
                        }
                    }
                    .padding()
                }
                .refreshable { await load() }
            } else {
                ProgressView().padding()
            }
        }
        .task { await load() }
    }

    @ViewBuilder private var timeline_: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline").font(.headline).foregroundStyle(Theme.secondary)
            VStack(spacing: 0) {
                ForEach(timeline.prefix(10)) { event in
                    TimelineRow(event: event)
                    if event.id != timeline.prefix(10).last?.id { Divider().overlay(Theme.border) }
                }
                if timeline.count > 10 {
                    HStack {
                        Text("... and \(timeline.count - 10) more")
                            .font(.caption).foregroundStyle(Theme.muted)
                        Spacer()
                    }
                    .padding(12)
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
    }

    @ViewBuilder private var related_: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related").font(.headline).foregroundStyle(Theme.secondary)

            if let prs = relations?.relatedPRs, !prs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pull Requests").font(.subheadline.weight(.medium))
                    ForEach(prs) { pr in
                        HStack(spacing: 8) {
                            Text("#\(pr.number)").font(.caption.monospaced()).foregroundStyle(Theme.muted)
                            Text(pr.title ?? "Unknown PR").lineLimit(1)
                            Spacer()
                            if let url = prURL(pr) {
                                Link(destination: url) {
                                    Image(systemName: "arrow.up.right").foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .padding(10)
                        .background(Theme.raised, in: .rect(cornerRadius: 6))
                    }
                }
            }

            if let docs = relations?.relatedDocs, !docs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Docs").font(.subheadline.weight(.medium))
                    ForEach(docs) { doc in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                if let label = doc.label {
                                    Text(label).font(.caption.weight(.medium))
                                }
                                Text(doc.path).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Theme.raised, in: .rect(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private var hasRelated: Bool {
        let prs = relations?.relatedPRs.flatMap { $0 }.isEmpty == false
        let docs = relations?.relatedDocs.flatMap { $0 }.isEmpty == false
        return prs || docs
    }

    private var shortRepo: String { repo.split(separator: "/").last.map(String.init) ?? repo }

    private func prURL(_ pr: RelatedRef) -> URL? {
        guard let repo = pr.repo else { return nil }
        return URL(string: "https://github.com/\(repo)/pull/\(pr.number)")
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            async let t = client.timeline(repo: repo, number: number)
            async let r = client.relations(repo: repo, number: number)
            (timeline, relations) = try await (t, r)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}

private struct TimelineRow: View {
    let event: TimelineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack {
                Circle().fill(Theme.color(.green)).frame(width: 6)
                Spacer()
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(event.type).font(.caption.weight(.medium)).foregroundStyle(Theme.secondary)
                    if let actor = event.actor {
                        Text("by \(actor)").font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                if let body = event.body {
                    Text(body).font(.body).foregroundStyle(Theme.text)
                }
                if let createdAt = event.createdAt {
                    Text(createdAt).font(.caption2).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
        }
        .padding(12)
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
