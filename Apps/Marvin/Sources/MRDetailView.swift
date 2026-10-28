import MarvinCore
import SwiftUI

/// MR Review detail: PR summary, ticket context, Approve/Deny buttons.
struct MRDetailView: View {
    let pr: PullRequest
    let allPRs: [PullRequest]
    @Environment(AppModel.self) private var model
    @State private var ticketContext: TicketContext?
    @State private var loadingContext = false
    @State private var showingDenySheet = false
    @State private var inFlight = false
    @State private var result: String?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Page(title: "PR") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PRHeader(pr: pr)
                    if let ticketContext {
                        TicketContextCard(context: ticketContext)
                    }
                    if loadingContext {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    }
                    if let result {
                        Text(result).font(.footnote).foregroundStyle(Theme.secondary).padding()
                    }
                    HStack(spacing: 12) {
                        Button(action: { showingDenySheet = true }) {
                            Label("Deny", systemImage: "xmark.circle").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(inFlight)
                        .tint(Theme.color(.red))
                        Button(action: { approve() }) {
                            Label("Approve", systemImage: "checkmark.circle").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(inFlight)
                        .tint(Theme.color(.green))
                    }
                    .padding(12)
                    Spacer()
                }
            }
            .task { await loadTicketContext() }
            .task { await showDemoDenySheet() }
            .sheet(isPresented: $showingDenySheet) {
                DenyReasonSheet(isPresented: $showingDenySheet, prNumber: pr.number, onDeny: deny)
            }
        }
    }

    private func loadTicketContext() async {
        guard let ticket = pr.ticket else { return }
        loadingContext = true
        defer { loadingContext = false }
        guard let client = model.client else { return }
        do {
            ticketContext = try await client.mrTicketContext(prNumber: pr.number)
        } catch {
            result = "Couldn't load ticket context"
        }
    }

    private func approve() {
        Task {
            inFlight = true
            defer { inFlight = false }
            guard let actions = model.mrActions else { return }
            let approveResult = await actions.approve(prNumber: pr.number)
            if approveResult?.merged == true {
                result = "✓ Merged"
                try? await Task.sleep(for: .seconds(1))
                dismiss()
            } else {
                result = "Approve failed or cancelled"
            }
        }
    }

    private func deny(reasons: [DenyReason], comment: String) {
        Task {
            inFlight = true
            defer { inFlight = false }
            guard let actions = model.mrActions else { return }
            let action = MRDenyAction(prNumber: pr.number, reasons: reasons, comment: comment)
            let denyResult = await actions.deny(action: action)
            if denyResult?.recorded == true {
                result = "✓ Denial recorded"
                try? await Task.sleep(for: .seconds(1))
                dismiss()
            } else {
                result = "Denial failed or cancelled"
            }
        }
    }

    private func showDemoDenySheet() async {
        guard model.isDemo, UserDefaults.standard.bool(forKey: "demoDenySheet") else { return }
        try? await Task.sleep(for: .milliseconds(500))
        showingDenySheet = true
    }
}

private struct PRHeader: View {
    let pr: PullRequest

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 10) {
                StatusDot(severity: pr.severity, size: 12)
                VStack(alignment: .leading, spacing: 8) {
                    Text(pr.title ?? pr.key).font(.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(shortRepo)#\(pr.number)")
                            .font(.caption.monospaced())
                            .foregroundStyle(Theme.muted)
                        Text(pr.status.label).font(.caption).foregroundStyle(Theme.secondary)
                        if let author = pr.author {
                            Text("by \(author)").font(.caption2).foregroundStyle(Theme.muted)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    private var shortRepo: String { pr.repo.split(separator: "/").last.map(String.init) ?? pr.repo }
}

private struct TicketContextCard: View {
    let context: TicketContext

    var body: some View {
        Card {
            SectionLabel("Ticket")
            Text("\(shortRepo)#\(context.number): \(context.title ?? "Untitled")")
                .font(.subheadline)
                .lineLimit(2)
            if let desc = context.description, !desc.isEmpty {
                Text(desc).font(.caption).foregroundStyle(Theme.secondary).lineLimit(3)
            }
            HStack(spacing: 12) {
                if let status = context.status {
                    Label(status, systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
                if let stage = context.stage {
                    Label(stage, systemImage: "arrow.forward.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
    }

    private var shortRepo: String { context.repo.split(separator: "/").last.map(String.init) ?? context.repo }
}

private struct DenyReasonSheet: View {
    @Binding var isPresented: Bool
    let prNumber: Int
    let onDeny: ([DenyReason], String) -> Void
    @State private var selectedReasons: Set<DenyReason> = []
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Why deny this PR?").font(.subheadline.weight(.semibold))
                    VStack(spacing: 8) {
                        ForEach(DenyReason.allCases, id: \.self) { reason in
                            Button(action: { toggle(reason) }) {
                                HStack {
                                    Image(systemName: selectedReasons.contains(reason) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(Theme.selected)
                                    Text(reason.label)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .tint(Theme.text)
                        }
                    }
                    Divider().overlay(Theme.border)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Feedback (optional)").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                        TextEditor(text: $comment)
                            .font(.caption)
                            .frame(height: 80)
                            .padding(8)
                            .background(Theme.raised, in: .rect(cornerRadius: 8))
                    }
                    Spacer()
                    Button(action: send) {
                        Label("Send feedback", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedReasons.isEmpty)
                    Button(action: { isPresented = false }) {
                        Label("Drop entirely", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.color(.red))
                }
                .padding()
            }
            .navigationTitle("Deny PR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    private func toggle(_ reason: DenyReason) {
        if selectedReasons.contains(reason) {
            selectedReasons.remove(reason)
        } else {
            selectedReasons.insert(reason)
        }
    }

    private func send() {
        onDeny(Array(selectedReasons), comment)
        isPresented = false
    }
}

// Launch args for demo deep links
#Preview {
    let mockPR = PullRequest(
        number: 315, repo: "G-Eskayo/marvin", key: "G-Eskayo/marvin#315",
        title: "MR Review: approve and deny with Face ID", status: .readyToMerge,
        ticket: TicketSummary(number: 3, repo: "G-Eskayo/marvin-mobile", key: "G-Eskayo/marvin-mobile#3", title: "MR Review tab"),
        author: "claude-code", createdAt: "2026-10-23T14:22:11Z", url: nil
    )
    MRDetailView(pr: mockPR, allPRs: [mockPR])
        .environment(AppModel())
}
