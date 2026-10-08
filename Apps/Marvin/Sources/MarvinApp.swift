import SwiftUI

@main
struct MarvinApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.monitorConnection() }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Thread", systemImage: "bubble.left.and.bubble.right") { ThreadView() }
            Tab("Dashboard", systemImage: "square.grid.2x2") { DashboardView() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
    }
}
