import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    TextField("Backend URL", text: $model.backendURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Use default (\(AppModel.defaultBackend))") {
                        model.backendURLString = AppModel.defaultBackend
                    }
                    Button("Check connection") {
                        Task { await model.refreshConnection() }
                    }
                } header: {
                    Text("Backend")
                } footer: {
                    Text("Tailscale must be on. Status: \(statusText)")
                }
            }
            .navigationTitle("Settings")
        }
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
