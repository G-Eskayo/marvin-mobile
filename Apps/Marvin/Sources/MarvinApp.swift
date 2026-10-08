import MarvinCore
import SwiftUI

@main
struct MarvinApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.selected)
                .task { await model.monitorConnection() }
        }
    }
}

/// Tabs mirror the desktop dashboard (Activity, MR Review, Health, Docs), with the
/// Thread first because it's what the phone is mostly for. Portfolio and Metrics stay
/// desktop-only (PRD #152).
struct RootView: View {
    @Environment(AppModel.self) private var model
    /// `-tab <name>` opens a given tab: lets simulator screenshots reach every tab without taps.
    @State private var selection = UserDefaults.standard.string(forKey: "tab") ?? "marvin"

    var body: some View {
        TabView(selection: $selection) {
            Tab("MARVIN", systemImage: "bubble.left.and.text.bubble.right", value: "marvin") { ThreadView() }
            Tab("Activity", systemImage: "list.bullet.rectangle", value: "activity") { ActivityView() }
            Tab("MR Review", systemImage: "arrow.triangle.pull", value: "review") {
                ComingSoonView(title: "MR Review", ticket: "marvin-mobile#3",
                               blurb: "Open pipeline PRs with their status, the ticket behind each, and approve or deny behind Face ID.")
            }
            Tab("Health", systemImage: "heart.text.square", value: "health") { HealthView() }
                .badge(model.redCheckCount)
            Tab("Docs", systemImage: "doc.text", value: "docs") {
                ComingSoonView(title: "Docs", ticket: "marvin-mobile#4",
                               blurb: "Read CONTEXT.md, ADRs and plans from every project, read-only.")
            }
        }
    }
}

/// An honest placeholder for a tab whose ticket hasn't been built yet.
struct ComingSoonView: View {
    let title: String
    let ticket: String
    let blurb: String

    var body: some View {
        Page(title: title) {
            VStack(spacing: 12) {
                Spacer()
                SectionLabel("Not built yet")
                Text(blurb)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondary)
                Text(ticket).font(.footnote.monospaced()).foregroundStyle(Theme.muted)
                Spacer()
            }
            .padding(32)
        }
    }
}
