import MarvinCore
import SwiftUI

/// Shows when the backend can't be reached, and how old the last contact is,
/// so stale data is never mistaken for live (PRD #152 story 6). Hidden while online.
struct ConnectionBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let message {
            Label(message, systemImage: icon)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.2))
        }
    }

    private var message: String? {
        switch model.connection.status {
        case .online, .unknown:
            return nil
        case .notAllowlisted:
            return "This phone isn't on MARVIN's allowlist."
        case .offline:
            guard let last = model.connection.lastReached else { return "Can't reach MARVIN." }
            return "Can't reach MARVIN. Last reached \(last.formatted(.relative(presentation: .named)))."
        }
    }

    private var icon: String {
        model.connection.status == .notAllowlisted ? "lock.slash" : "wifi.slash"
    }
}
