import SwiftUI

/// Opened from the gear on any tab. Rarely needed: which Mac the app talks to.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    TextField("Backend URL", text: $model.backendURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(model.isDemo)
                    Button("Use default (\(AppModel.defaultBackend))") {
                        model.backendURLString = AppModel.defaultBackend
                    }
                    .disabled(model.isDemo)
                    Button("Check connection") {
                        Task { await model.refreshConnection() }
                    }
                } header: {
                    Text("Backend")
                } footer: {
                    Text(model.isDemo ? "Demo mode: showing built-in sample data." : "Tailscale must be on. Status: \(statusText)")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }

    private var statusText: String {
        switch model.connection.status {
        case .unknown: "checking…"
        case .online: "connected"
        case .offline: "unreachable"
        case .notAllowlisted: "not allowlisted"
        }
    }
}
