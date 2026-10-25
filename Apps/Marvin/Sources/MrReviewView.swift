import MarvinCore
import SwiftUI

struct MrReviewView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedPr: MrPr?
    @State private var showDenySheet = false
    @State private var selectedReasons: Set<MrDenyReason> = []
    @State private var selectedAction: MrDenyAction = .requestChanges
    @State private var denyComment = ""

    /// Debug: `-mrDetail <index>` opens a PR's detail sheet on load.
    private var debugDetailIndex: Int? {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-mrDetail"), idx + 1 < args.count {
            return Int(args[idx + 1])
        }
        return nil
    }

    /// Debug: `-mrDeny` opens the deny sheet on load (after detail sheet).
    private var debugShowDeny: Bool {
        ProcessInfo.processInfo.arguments.contains("-mrDeny")
    }

    var body: some View {
        Page(title: "MR Review") {
            if model.mrList.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    SectionLabel("No PRs to review")
                    Text("Pipeline PRs will appear here as they arrive.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                }
                .padding(32)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.mrList) { pr in
                            MrPrRowView(pr: pr, status: model.mrReviewStatus[pr.id])
                                .onTapGesture { selectedPr = pr }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .sheet(item: $selectedPr) { pr in
            MrDetailSheet(pr: pr, showDenySheet: $showDenySheet, selectedReasons: $selectedReasons, selectedAction: $selectedAction, denyComment: $denyComment)
        }
        .task {
            await model.loadMrList()
            if let idx = debugDetailIndex, idx < model.mrList.count {
                selectedPr = model.mrList[idx]
                if debugShowDeny {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showDenySheet = true
                    }
                }
            }
        }
    }
}

struct MrPrRowView: View {
    let pr: MrPr
    let status: MrReviewStatus?

    var statusColor: Color {
        switch status?.status {
        case .approved: return Theme.success
        case .denied: return Theme.error
        case .open, nil: return Theme.muted
        }
    }

    var statusLabel: String {
        switch status?.status {
        case .approved: return "✓"
        case .denied: return "✗"
        case .open, nil: return "◯"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(pr.number) \(pr.title)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                    Text(pr.author)
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                Text(statusLabel)
                    .font(.title2)
                    .foregroundStyle(statusColor)
            }
            .padding(12)
            .background(Color(white: 0.1))
            .cornerRadius(8)
        }
    }
}

struct MrDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let pr: MrPr
    @Binding var showDenySheet: Bool
    @Binding var selectedReasons: Set<MrDenyReason>
    @Binding var selectedAction: MrDenyAction
    @Binding var denyComment: String
    @State private var context: MrTicketContext?
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("marvin-mobile#\(pr.number)")
                            .font(.caption.monospaced())
                            .foregroundStyle(Theme.secondary)
                        Text(pr.title)
                            .font(.headline)
                        Text("by \(pr.author)")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    if let context {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Related Ticket")
                            Text("#\(context.number) \(context.title)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(Theme.accent)
                        }
                    }

                    HStack(spacing: 12) {
                        Button(action: { Task { await model.approve(pr); dismiss() } }) {
                            Label("Approve", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)

                        Button(action: { showDenySheet = true }) {
                            Label("Deny", systemImage: "xmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("PR \(pr.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: { dismiss() })
                }
            }
        }
        .sheet(isPresented: $showDenySheet) {
            MrDenySheet(pr: pr, selectedReasons: $selectedReasons, selectedAction: $selectedAction, denyComment: $denyComment, onDeny: {
                Task {
                    await model.deny(pr, action: selectedAction, reasons: Array(selectedReasons), comment: denyComment.isEmpty ? nil : denyComment)
                    dismiss()
                }
            })
        }
        .task {
            do {
                if let client = model.client {
                    context = try await client.mrTicketContext(ref: "marvin#\(pr.number)", repo: pr.repo)
                }
            } catch {
                context = nil
            }
            isLoading = false
        }
    }
}

struct MrDenySheet: View {
    @Environment(\.dismiss) private var dismiss
    let pr: MrPr
    @Binding var selectedReasons: Set<MrDenyReason>
    @Binding var selectedAction: MrDenyAction
    @Binding var denyComment: String
    var onDeny: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Why are you denying this PR?")
                        ForEach(MrDenyReason.allCases, id: \.self) { reason in
                            HStack {
                                Image(systemName: selectedReasons.contains(reason) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(selectedReasons.contains(reason) ? Theme.accent : Theme.secondary)
                                Text(reason.rawValue.capitalized)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedReasons.contains(reason) {
                                    selectedReasons.remove(reason)
                                } else {
                                    selectedReasons.insert(reason)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("What should happen next?")
                        Picker("Action", selection: $selectedAction) {
                            Text("Ask for changes").tag(MrDenyAction.requestChanges)
                            Text("Escalate").tag(MrDenyAction.escalate)
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Comment (optional)")
                        TextEditor(text: $denyComment)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(white: 0.1))
                            .cornerRadius(8)
                    }

                    HStack(spacing: 12) {
                        Button("Cancel") { dismiss() }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.bordered)
                        Button(action: { onDeny(); dismiss() }) {
                            Text("Deny")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Deny PR \(pr.number)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    @State var model = AppModel()
    return MrReviewView()
        .environment(model)
}
