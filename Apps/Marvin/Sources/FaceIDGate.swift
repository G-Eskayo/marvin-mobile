import LocalAuthentication

/// Protocol for Face ID authentication (helps with testing).
protocol FaceIDAuthenticating: Sendable {
    func authenticate() async -> Bool
}

/// Real Face ID authentication using LocalAuthentication.
final actor FaceIDGate: FaceIDAuthenticating {
    static let shared = FaceIDGate()

    func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Confirm to post reply to ticket"
            )
        } catch {
            return false
        }
    }
}
