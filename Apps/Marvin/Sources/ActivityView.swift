import MarvinCore
import SwiftUI

enum ActivityDestination: Hashable {
    case board(repo: String, name: String?)
    case ticket(repo: String, number: Int)
}

/// Activity for now: projects with their due dates, and the pipeline's ticket runs.
/// Full boards and ticket answering come with marvin-mobile#2.
struct ActivityView: View {
    @Environment(AppModel.self) private var model
    @State private var boards: [Board] = []
    @State private var activity: [ActivityItem] = []
    @State private var queue: QueueStatus?
    @State private var error: String?
    @State private var loaded = false
    @State private var navigationPath: [ActivityDestination] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Activity").font(.title2.weight(.semibold))
                    Spacer()
                }
                .padding()
                .background(Theme.background)
                Divider().overlay(Theme.border)

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
                        if let queue, !queue.entries.isEmpty { nextUp }
                        if !activity.isEmpty { runs }
                        if loaded, boards.isEmpty, activity.isEmpty, error == nil {
                            Text("No activity yet").foregroundStyle(Theme.muted)
                        }
                    }
                    .padding()
                }
                .background(Theme.background)
            }
            .navigationDestination(for: ActivityDestination.self) { destination in
                switch destination {
                case .board(let repo, let name):
                    BoardView(repo: repo, name: name)
                case .ticket(let repo, let number):
                    TicketDetailView(repo: repo, number: number)
                }
            }
            .refreshable { await load() }
            .task {
                await load()
                let args = ProcessInfo.processInfo.arguments
                if let boardIdx = args.firstIndex(of: "-demoBoard"), boardIdx + 1 < args.count {
                    navigationPath.append(.board(repo: args[boardIdx + 1], name: nil))
                }
                if let ticketIdx = args.firstIndex(of: "-demoTicket"), ticketIdx + 1 < args.count {
                    let parts = args[ticketIdx + 1].split(separator: "#")
                    if parts.count == 2, let number = Int(parts[1]) {
                        navigationPath.append(.ticket(repo: String(parts[0]), number: number))
                    }
                }
            }
        }
        .background(Theme.background)
    }

    private var projects: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Projects")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(boards.filter { $0.status != "archived" }) { board in
                        Button(action: { navigationPath.append(.board(repo: board.repo, name: board.name)) }) {
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
    }

    private var nextUp: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Next up")
            VStack(spacing: 0) {
                ForEach(queue?.entries?.prefix(3) ?? []) { entry in
                    Button(action: { navigationPath.append(.ticket(repo: entry.repo ?? "unknown", number: entry.number)) }) {
                        QueueEntryRow(entry: entry)
                    }
                    if entry.id != (queue?.entries?.prefix(3).last?.id ?? "") { Divider().overlay(Theme.border) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
    }

    private var runs: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Pipeline runs")
            VStack(spacing: 0) {
                ForEach(activity) { item in
                    Button(action: { navigationPath.append(.ticket(repo: item.repo, number: item.number)) }) {
                        RunRow(item: item).foregroundStyle(Theme.text)
                    }
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
            async let q = client.queue()
            (boards, activity, queue) = try await (b, a, q)
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

private struct QueueEntryRow: View {
    let entry: QueueEntry

    var body: some View {
        let key = entry.repo.map { "\($0.split(separator: "/").last ?? "")" } ?? "unknown"
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            StatusDot(severity: entry.stage == "executing" ? .green : entry.stage == "waiting" ? .yellow : .grey)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title ?? "\(key)#\(entry.number)").lineLimit(1)
                Text("\(key)#\(entry.number) · \(entry.stage ?? "unknown")")
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Theme.text)
    }
}
