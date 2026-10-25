import Foundation
import MarvinCore
import Observation

/// App-wide state: which backend to talk to, whether it's reachable, the Thread, and Health
/// (shared because the Health tab's badge shows its red count).
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
    private(set) var mrList: [MrPr] = []
    private(set) var mrListError: String?
    private(set) var mrOpenCount: Int = 0
    private(set) var mrReviewLoaded = false
    private(set) var authenticator: BiometricAuthenticator

    private let demoClient = DemoBackend.client()

    init() {
        backendURLString = UserDefaults.standard.string(forKey: Self.backendKey) ?? Self.defaultBackend
        if isDemo {
            authenticator = DemoBackend.authenticator()
        } else {
            authenticator = FaceIDAuthenticator()
        }
    }

    var client: BackendClient? {
        if isDemo { return demoClient }
        return URL(string: backendURLString).map { BackendClient(baseURL: $0) }
    }

    var isSending: Bool { streaming != nil }
    var redCheckCount: Int { health?.count(.red) ?? 0 }

    func refreshConnection() async {
        guard let client else { connection.record(.unreachable, at: .now); return }
        connection.record(await client.probe(), at: .now)
    }

    /// Re-probes every 15s while the app is open (live updates only while open, PRD #152).
    func monitorConnection() async {
        while !Task.isCancelled {
            await refreshConnection()
            if connection.status == .online, health == nil { await loadHealth() }
            if connection.status == .online, !mrReviewLoaded { await loadMrReviewStatus() }
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

    func loadMrReviewStatus() async {
        guard let client else { return }
        do {
            let status = try await client.mrReviewStatus()
            mrOpenCount = status.openCount
            await loadMrList()
            mrReviewLoaded = true
            mrListError = nil
        } catch {
            mrListError = error.localizedDescription
        }
    }

    func loadMrList() async {
        guard let client else { return }
        do {
            mrList = try await client.mrList()
            mrListError = nil
        } catch {
            mrListError = error.localizedDescription
        }
    }

    func approve(_ pr: MrPr) async throws {
        guard let client else { throw NSError(domain: "AppModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No client"]) }
        let _ = try await client.mrApprove(prUrl: pr.url)
        await loadMrList()
    }

    func deny(_ pr: MrPr, action: DenyAction, reasons: [String], comment: String) async throws {
        guard let client else { throw NSError(domain: "AppModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No client"]) }
        let _ = try await client.mrDeny(prUrl: pr.url, action: action, reasons: reasons, comment: comment)
        await loadMrList()
    }
}
