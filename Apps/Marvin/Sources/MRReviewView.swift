import MarvinCore
import SwiftUI

/// MR Review tab: list of pipeline PRs with their status, sorted by readiness.
struct MRReviewView: View {
    @Environment(AppModel.self) private var model
    @State private var prs: [PullRequest] = []
    @State private var error: String?
    @State private var loaded = false
    @State private var selectedPR: PullRequest?

    var body: some View {
        Page(title: "MR Review") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let error, model.connection.status == .online {
                        Text(error).font(.footnote).foregroundStyle(Theme.muted)
                    }
                    if !prs.isEmpty {
                        HStack(spacing: 10) {
                            StatCard(label: "Ready", value: "\(prs.count { $0.status == .readyToMerge })", valueColor: Theme.color(.green))
                            StatCard(label: "Issues", value: "\(prs.count { $0.status == .checksRequired || $0.status == .needsRework })",
                                     valueColor: prs.contains { $0.status == .checksRequired || $0.status == .needsRework } ? Theme.color(.red) : Theme.text)
                        }
                    }
                    if !prs.isEmpty { rows }
                    if loaded, prs.isEmpty, error == nil {
                        Text("No open PRs").foregroundStyle(Theme.muted)
                    }
                }
                .padding()
            }
            .refreshable { await load() }
            .task { await load() }
            .task { await selectDemoPR() }
            .navigationDestination(item: $selectedPR) { pr in
                MRDetailView(pr: pr, allPRs: prs)
            }
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Pull requests")
            VStack(spacing: 0) {
                ForEach(sortedPRs) { pr in
                    NavigationLink(value: pr) {
                        MRRow(pr: pr)
                    }
                    .tint(Theme.text)
                    if pr.id != sortedPRs.last?.id { Divider().overlay(Theme.border) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
    }

    private var sortedPRs: [PullRequest] {
        prs.sorted { a, b in
            let statusOrder: [MRStatus] = [.readyToMerge, .checksRunning, .checksRequired, .needsRework, .waitingForAutomerge, .draft]
            let aIndex = statusOrder.firstIndex(of: a.status) ?? statusOrder.count
            let bIndex = statusOrder.firstIndex(of: b.status) ?? statusOrder.count
            if aIndex != bIndex { return aIndex < bIndex }
            return a.number > b.number
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            prs = try await client.mrList()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }

    private func selectDemoPR() async {
        guard model.isDemo, let demoMRDetail = UserDefaults.standard.string(forKey: "demoMRDetail"),
              let prNumber = Int(demoMRDetail) else { return }
        try? await Task.sleep(for: .milliseconds(500))
        selectedPR = prs.first { $0.number == prNumber }
    }
}

private struct MRRow: View {
    let pr: PullRequest

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            StatusDot(severity: pr.severity)
            VStack(alignment: .leading, spacing: 3) {
                Text(pr.title ?? pr.key).lineLimit(2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(shortRepo)#\(pr.number) · \(pr.status.label)")
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.muted)
                    if let ticket = pr.ticket, let title = ticket.title {
                        Text("\(shortTicketRepo)#\(ticket.number) \(title)").font(.caption).foregroundStyle(Theme.secondary).lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
    }

    private var shortRepo: String { pr.repo.split(separator: "/").last.map(String.init) ?? pr.repo }
    private var shortTicketRepo: String { pr.ticket.map { $0.repo.split(separator: "/").last.map(String.init) ?? $0.repo } ?? "" }
}

extension MRStatus {
    var label: String {
        switch self {
        case .draft: "draft"
        case .readyToMerge: "ready"
        case .checksRunning: "checks…"
        case .checksRequired: "checks ⚠️"
        case .needsRework: "rework"
        case .waitingForAutomerge: "automerge…"
        }
    }
}
