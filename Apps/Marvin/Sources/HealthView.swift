import MarvinCore
import SwiftUI

/// The desktop Health tab on a phone: red/yellow/green tiles, then the checks grouped by
/// severity, worst first. Tap a check for its full detail.
struct HealthView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Page(title: "Health") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let health = model.health {
                        summary(health)
                        ForEach([Severity.red, .yellow, .green, .grey], id: \.self) { severity in
                            let checks = health.checks.filter { $0.severity == severity }
                            if !checks.isEmpty { group(severity, checks) }
                        }
                    } else if let error = model.healthError, model.connection.status == .online {
                        Text(error).font(.footnote).foregroundStyle(Theme.muted)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding()
            }
            .refreshable { await model.loadHealth() }
            .task { await model.loadHealth() }
        }
    }

    private func summary(_ health: HealthStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                StatusDot(severity: health.overall, size: 10)
                Text("Overall: \(health.overall.rawValue)").foregroundStyle(Theme.secondary)
                Spacer()
                if let at = health.generatedAt.flatMap(Self.parse) {
                    Text("checked \(at.formatted(.relative(presentation: .named)))")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
            HStack(spacing: 10) {
                StatCard(label: "Red", value: "\(health.count(.red))", valueColor: Theme.color(.red))
                StatCard(label: "Yellow", value: "\(health.count(.yellow))", valueColor: Theme.color(.yellow))
                StatCard(label: "Green", value: "\(health.count(.green))", valueColor: Theme.color(.green))
            }
        }
    }

    private func group(_ severity: Severity, _ checks: [HealthStatus.Check]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("\(severity.rawValue) · \(checks.count)")
            VStack(spacing: 0) {
                ForEach(checks) { check in
                    NavigationLink { CheckDetail(check: check) } label: { CheckRow(check: check) }
                    if check.id != checks.last?.id { Divider().overlay(Theme.border) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        }
    }

    static func parse(_ iso: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }
}

private struct CheckRow: View {
    let check: HealthStatus.Check

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            StatusDot(severity: check.severity)
            VStack(alignment: .leading, spacing: 3) {
                Text(check.label).foregroundStyle(Theme.text)
                if let detail = check.detail, check.severity != .green {
                    Text(detail).font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
        }
        .multilineTextAlignment(.leading)
        .padding(12)
    }
}

private struct CheckDetail: View {
    let check: HealthStatus.Check

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack { StatusDot(severity: check.severity, size: 10); SectionLabel(check.severity.rawValue) }
                Text(check.label).font(.title3.weight(.semibold))
                Text(check.detail ?? "No detail").foregroundStyle(Theme.secondary).textSelection(.enabled)
                Text(check.id).font(.caption.monospaced()).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Theme.background)
    }
}
