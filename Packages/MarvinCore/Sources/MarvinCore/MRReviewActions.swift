import Foundation

/// Coordinates MR Review approve/deny actions with in-flight guard and biometric auth.
public actor MRReviewActions {
    private let client: BackendClient
    private let biometricGate: BiometricGate
    private var inFlightPrNumbers: Set<Int> = []

    public init(client: BackendClient, biometricGate: BiometricGate) {
        self.client = client
        self.biometricGate = biometricGate
    }

    /// Approve a PR after Face ID. Returns nil if already in-flight for this PR.
    public func approve(prNumber: Int) async -> MRApproveResult? {
        guard !isInFlight(prNumber) else { return nil }
        setInFlight(prNumber, true)
        defer { setInFlight(prNumber, false) }

        let auth = await biometricGate.authenticate()
        guard case .success = auth else { return nil }

        do {
            return try await client.mrApprove(prNumber: prNumber)
        } catch {
            return nil
        }
    }

    /// Deny a PR after Face ID. Returns nil if already in-flight for this PR.
    public func deny(action: MRDenyAction) async -> MRDenyResult? {
        let prNumber = action.prNumber
        guard !isInFlight(prNumber) else { return nil }
        setInFlight(prNumber, true)
        defer { setInFlight(prNumber, false) }

        let auth = await biometricGate.authenticate()
        guard case .success = auth else { return nil }

        do {
            return try await client.mrDeny(action)
        } catch {
            return nil
        }
    }

    /// Check if a PR is already being processed.
    public func isInFlight(_ prNumber: Int) -> Bool {
        inFlightPrNumbers.contains(prNumber)
    }

    private func setInFlight(_ prNumber: Int, _ inFlight: Bool) {
        if inFlight {
            inFlightPrNumbers.insert(prNumber)
        } else {
            inFlightPrNumbers.remove(prNumber)
        }
    }
}
