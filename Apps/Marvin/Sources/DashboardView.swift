import MarvinCore
import SwiftUI

/// Dashboard v1 for the demo: Activity and Health, read-only.
/// Boards, PR review and Docs follow as their own slices (PRD #152).
struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var activity: [ActivityItem] = []
    @State private var health: HealthStatus?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ConnectionBanner()
                List {
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Health") {
                        if let health {
                            HStack {
                                StatusDot(status: health.overall)
                                Text("Overall: \(health.overall)")
                            }
                            ForEach(health.checks.filter { $0.status != "green" }) { check in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack { StatusDot(status: check.status); Text(check.name) }
                                    if let detail = check.detail {
                                        Text(detail).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else {
                            Text("No health data yet").foregroundStyle(.secondary)
                        }
                    }
                    Section("Activity") {
                        if activity.isEmpty {
                            Text("No ticket activity").foregroundStyle(.secondary)
                        }
                        ForEach(activity) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                // Never a bare ticket number: always with its title.
                                Text("#\(item.number) \(item.title ?? item.key)")
                                    .lineLimit(2)
                                HStack(spacing: 6) {
                                    if item.isLiveNow == true { Text("● live").foregroundStyle(.green) }
                                    if item.failed { Text("failed").foregroundStyle(.red) }
                                    Text([item.currentStage, item.currentStatus].compactMap { $0 }.joined(separator: " · "))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .refreshable { await load() }
            }
            .navigationTitle("Dashboard")
            .task { await load() }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            async let a = client.activity()
            async let h = client.health()
            (activity, health) = try await (a, h)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct StatusDot: View {
    let status: String

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }

    private var color: Color {
        switch status {
        case "green": .green
        case "amber", "yellow": .orange
        case "red": .red
        default: .gray
        }
    }
}
