import MarvinCore
import SwiftUI

/// Activity for now: projects with their due dates, and the pipeline's ticket runs.
/// Full boards and ticket answering come with marvin-mobile#2.
struct ActivityView: View {
    @Environment(AppModel.self) private var model
    @State private var boards: [Board] = []
    @State private var activity: [ActivityItem] = []
    @State private var error: String?
    @State private var loaded = false

    var body: some View {
        Page(title: "Activity") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let error, model.connection.status == .online {
                        Text(error).font(.footnote).foregroundStyle(Theme.muted)
                    }
                    if !activity.isEmpty {
                        HStack(spacing: 10) {
                            StatCard(label: "Live now", value: "\(activity.count { $0.isLiveNow == true })", valueColor: Theme.color(.green))
                            StatCard(label: "Failed", value: "\(activity.count { $0.failed })",
                                     valueColor: activity.contains { $0.failed } ? Theme.color(.red) : Theme.text)
                        }
                    }
                    if !boards.isEmpty { projects }
                    if !activity.isEmpty { runs }
                    if loaded, boards.isEmpty, activity.isEmpty, error == nil {
                        Text("No activity yet").foregroundStyle(Theme.muted)
                    }
                }
                .padding()
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private var projects: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Projects")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(boards.filter { $0.status != "archived" }) { board in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(board.name ?? board.repo).font(.subheadline.weight(.medium))
                            if let due = board.due {
                                Text("\(board.dueHard == true ? "due" : "target") \(due)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(board.dueHard == true ? Theme.accent : Theme.muted)
                            } else {
                                Text("no due date").font(.caption2).foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Theme.raised, in: .rect(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var runs: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Pipeline runs")
            VStack(spacing: 0) {
                ForEach(activity) { item in
                    RunRow(item: item)
                    if item.id != activity.last?.id { Divider().overlay(Theme.border) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            async let b = client.boards()
            async let a = client.activity()
            (boards, activity) = try await (b, a)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }
}

private struct RunRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            StatusDot(severity: item.failed ? .red : item.isLiveNow == true ? .green : item.currentStage == "done" ? .grey : .yellow)
            VStack(alignment: .leading, spacing: 3) {
                // Never a bare ticket number: always with its title (or its repo#number key).
                Text(item.title ?? item.key).lineLimit(2)
                Text("\(shortRepo)#\(item.number) · \([item.currentStage, item.currentStatus].compactMap { $0 }.joined(separator: " · "))")
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if let cost = item.costUsd, cost > 0 {
                Text(cost, format: .currency(code: "USD").precision(.fractionLength(2)))
                    .font(.caption.monospacedDigit()).foregroundStyle(Theme.secondary)
            }
        }
        .padding(12)
    }

    private var shortRepo: String { item.repo.split(separator: "/").last.map(String.init) ?? item.repo }
}
