import LocalAuthentication

protocol FaceIDAuthenticating {
    func authenticate() async -> Bool
}

final class FaceIDGate: FaceIDAuthenticating {
    private let context = LAContext()

    func authenticate() async -> Bool {
        guard canEvaluatePolicy() else { return false }
        do {
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
            let result = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Confirm to send this reply")
            return result
        } catch {
            return false
        }
    }

    private func canEvaluatePolicy() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
}
