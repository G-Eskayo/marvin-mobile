import MarvinCore
import SwiftUI

struct MrReviewView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedPr: MrPr?
    @State private var showingDeny = false
    @State private var actionInProgress = false

    var body: some View {
        Page(title: "MR Review") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let error = model.mrListError, model.connection.status == .online {
                        Text(error).font(.footnote).foregroundStyle(Theme.muted)
                    }
                    if !model.mrList.isEmpty {
                        HStack(spacing: 10) {
                            StatCard(label: "Open", value: "\(model.mrOpenCount)", valueColor: Theme.selected)
                            if !model.mrList.isEmpty {
                                StatCard(label: "Reviewing", value: "\(model.mrList.count)", valueColor: Theme.accent)
                            }
                        }
                    }
                    if !model.mrList.isEmpty { prList }
                    if model.mrList.isEmpty, model.mrListError == nil {
                        Text("No PRs to review").foregroundStyle(Theme.muted)
                    }
                }
                .padding()
            }
            .refreshable { await model.loadMrList() }
            .task { await model.loadMrList() }
            .task {
                applyDebugArguments()
            }
        }
        .sheet(item: $selectedPr) { pr in MrDetail(pr: pr, dismiss: { selectedPr = nil }, showDenyInitially: showingDeny) }
    }

    private func applyDebugArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-mrDetail") else { return }
        guard let detailIndex = args.firstIndex(of: "-mrDetail") else { return }
        let nextIndex = args.index(after: detailIndex)
        guard nextIndex < args.endIndex else { return }
        let indexStr = args[nextIndex]
        guard let index = Int(indexStr), index < model.mrList.count else { return }
        selectedPr = model.mrList[index]
        if args.contains("-mrDeny") {
            showingDeny = true
        }
    }

    private var prList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Pipeline PRs")
            VStack(spacing: 0) {
                ForEach(model.mrList) { pr in
                    Button {
                        selectedPr = pr
                    } label: {
                        MrRow(pr: pr)
                    }
                    if pr.id != model.mrList.last?.id { Divider().overlay(Theme.border) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
    }
}

private struct MrRow: View {
    let pr: MrPr

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            StatusDot(severity: statusSeverity)
            VStack(alignment: .leading, spacing: 3) {
                Text(pr.title).lineLimit(2)
                Text("\(shortRepo)#\(pr.number)").font(.caption.monospaced()).foregroundStyle(Theme.muted)
            }
            Spacer()
            statusBadge
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusSeverity: Severity {
        switch pr.status {
        case .approved: .green
        case .changesRequested: .red
        case .pending: .yellow
        }
    }

    private var statusBadge: some View {
        Text(pr.status.rawValue)
            .font(.caption.weight(.medium))
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        Theme.color(statusSeverity)
    }

    private var shortRepo: String {
        pr.repo.split(separator: "/").last.map(String.init) ?? pr.repo
    }
}

private struct MrDetail: View {
    let pr: MrPr
    let dismiss: () -> Void
    let showDenyInitially: Bool
    @Environment(AppModel.self) private var model
    @State private var showingDeny = false
    @State private var actionInProgress = false
    @State private var ticket: TicketInfo?
    @State private var ticketLoading = false

    init(pr: MrPr, dismiss: @escaping () -> Void, showDenyInitially: Bool = false) {
        self.pr = pr
        self.dismiss = dismiss
        self.showDenyInitially = showDenyInitially
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(pr.title).font(.headline)
                    Text("\(pr.repo)#\(pr.number)").font(.caption.monospaced()).foregroundStyle(Theme.muted)
                    if let author = pr.author {
                        Text("by \(author)").font(.caption).foregroundStyle(Theme.secondary)
                    }
                    Divider().overlay(Theme.border)
                    if ticketLoading {
                        ProgressView()
                    } else if let ticket {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Related Ticket")
                            Text(ticket.title ?? "Ticket #\(ticket.number)").font(.subheadline)
                            HStack(spacing: 12) {
                                if let stage = ticket.currentStage {
                                    Text(stage).font(.caption).foregroundStyle(Theme.secondary)
                                }
                                if let status = ticket.currentStatus {
                                    Text(status).font(.caption).foregroundStyle(Theme.secondary)
                                }
                            }
                        }
                        Divider().overlay(Theme.border)
                    }
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                actionInProgress = true
                                do {
                                    try await model.approve(pr)
                                    dismiss()
                                } catch {
                                    // Handle error
                                }
                                actionInProgress = false
                            }
                        } label: {
                            Text("Approve").frame(maxWidth: .infinity).padding(12)
                        }
                        .buttonStyle(.bordered)
                        .disabled(actionInProgress)
                        Button {
                            showingDeny = true
                        } label: {
                            Text("Deny").frame(maxWidth: .infinity).padding(12)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.color(.red))
                        .disabled(actionInProgress)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingDeny) {
            DenySheet(pr: pr, dismiss: dismiss)
        }
        .task {
            ticketLoading = true
            do {
                let components = pr.url.split(separator: "/")
                if let prNum = components.last {
                    ticket = try await model.client?.mrTicketContext(ref: String(prNum), repo: pr.repo)
                }
            } catch {
                // Silently fail, ticket is optional
            }
            ticketLoading = false
        }
        .onAppear {
            if showDenyInitially {
                showingDeny = true
            }
        }
    }
}

private struct DenySheet: View {
    let pr: MrPr
    let dismiss: () -> Void
    @Environment(AppModel.self) private var model
    @State private var selectedAction: DenyAction = .changesRequested
    @State private var comment = ""
    @State private var actionInProgress = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Action") {
                    Picker("What to do", selection: $selectedAction) {
                        ForEach(DenyAction.allCases, id: \.self) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                }
                Section("Comment") {
                    TextEditor(text: $comment)
                        .frame(minHeight: 80)
                }
                Section {
                    Button("Deny PR") {
                        Task {
                            actionInProgress = true
                            do {
                                try await model.deny(pr, action: selectedAction, reasons: [], comment: comment)
                                dismiss()
                            } catch {
                                // Handle error
                            }
                            actionInProgress = false
                        }
                    }
                    .disabled(actionInProgress)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
