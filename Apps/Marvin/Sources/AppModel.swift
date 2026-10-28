import Foundation
import MarvinCore
import Observation

/// App-wide state: which backend to talk to, whether it's reachable, the Thread, Health,
/// and MR Review (shared because the MR tab's badge shows its open count).
@MainActor @Observable
final class AppModel {
    static let defaultBackend = "http://100.80.189.85:7880"   // MacBook for the first demo; Mac Mini later (ADR 0042)
    private static let backendKey = "backendURL"

    /// Launched with `-demo`: a built-in fake backend, for repeatable simulator screenshots.
    let isDemo = ProcessInfo.processInfo.arguments.contains("-demo")

    var backendURLString: String {
        didSet { UserDefaults.standard.set(backendURLString, forKey: Self.backendKey) }
    }
    private(set) var connection = ConnectionState()
    private(set) var messages: [ThreadMessage] = []
    /// The reply being streamed right now, shown under the Thread until it finishes.
    private(set) var streaming: ReplyAccumulator?
    private(set) var threadError: String?
    private(set) var health: HealthStatus?
    private(set) var healthError: String?
    private(set) var mrReviewStatus: MRReviewStatus?
    private(set) var mrError: String?

    private let demoClient = DemoBackend.client()
    private(set) var biometricGate: BiometricGate
    private(set) var mrActions: MRReviewActions?

    init() {
        backendURLString = UserDefaults.standard.string(forKey: Self.backendKey) ?? Self.defaultBackend
        biometricGate = LAContextBiometricGate()

        // Convert launch arguments to UserDefaults for demo mode navigation
        if isDemo {
            let args = ProcessInfo.processInfo.arguments
            var i = 0
            while i < args.count {
                let arg = args[i]
                switch arg {
                case "-tab", "-demoPrompt", "-demoMRDetail":
                    if i + 1 < args.count {
                        let key = String(arg.dropFirst())  // Remove leading "-"
                        UserDefaults.standard.set(args[i + 1], forKey: key)
                        i += 2
                    } else {
                        i += 1
                    }
                case "-demoDenySheet":
                    UserDefaults.standard.set(true, forKey: "demoDenySheet")
                    i += 1
                default:
                    i += 1
                }
            }
        }
    }

    var client: BackendClient? {
        if isDemo { return demoClient }
        return URL(string: backendURLString).map { BackendClient(baseURL: $0) }
    }

    var isSending: Bool { streaming != nil }
    var redCheckCount: Int { health?.count(.red) ?? 0 }
    var mrOpenCount: Int { mrReviewStatus?.openCount ?? 0 }

    func refreshConnection() async {
        guard let client else { connection.record(.unreachable, at: .now); return }
        connection.record(await client.probe(), at: .now)
    }

    /// Re-probes every 15s while the app is open (live updates only while open, PRD #152).
    func monitorConnection() async {
        while !Task.isCancelled {
            await refreshConnection()
            if connection.status == .online {
                if health == nil { await loadHealth() }
                if mrReviewStatus == nil { await loadMRReviewStatus() }
            }
            try? await Task.sleep(for: .seconds(15))
        }
    }

    func loadHealth() async {
        guard let client else { return }
        do {
            health = try await client.health()
            healthError = nil
        } catch {
            healthError = error.localizedDescription
        }
    }

    func loadMRReviewStatus() async {
        guard let client else { return }
        if mrActions == nil { mrActions = MRReviewActions(client: client, biometricGate: biometricGate) }
        do {
            mrReviewStatus = try await client.mrReviewStatus()
            mrError = nil
        } catch {
            mrError = error.localizedDescription
        }
    }

    func loadThread() async {
        guard let client else { return }
        do {
            messages = try await client.thread()
            threadError = nil
        } catch {
            threadError = error.localizedDescription
        }
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let client, !isSending else { return }
        messages.append(ThreadMessage(id: "local-\(UUID())", source: "chat", role: .user, text: trimmed))
        streaming = ReplyAccumulator()
        do {
            for try await event in client.chat(trimmed) {
                streaming?.apply(event)
            }
        } catch {
            streaming?.apply(.error(error.localizedDescription))
        }
        if let reply = streaming {
            let text = reply.error.map { "⚠️ \($0)" } ?? reply.text
            messages.append(ThreadMessage(id: "local-\(UUID())", source: "chat", role: .assistant, text: text))
        }
        streaming = nil
    }
}
