import Foundation
import OSLog
import SwiftUI

enum AppRole: String, Codable, Sendable {
    case therapist
    case patient
}

enum PatientActivation: String, Codable, Sendable {
    case active
    case incomplete
}

/// Access/context for the signed-in Supabase user, as decided by the
/// `get-app-context` Edge Function. Patient-only fields are absent for
/// therapists. Entitlement governs mutations independently of routing.
nonisolated struct AppContext: Codable, Equatable, Sendable {
    let version: Int
    let role: AppRole
    let activation: PatientActivation?
    let patientId: UUID?
    let entitlement: AppEntitlement?

    init(version: Int, role: AppRole, activation: PatientActivation?, patientId: UUID?, entitlement: AppEntitlement? = nil) {
        self.version = version; self.role = role; self.activation = activation; self.patientId = patientId; self.entitlement = entitlement
    }
    private enum CodingKeys: String, CodingKey { case version, role, activation, patientId, entitlement }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        role = try container.decode(AppRole.self, forKey: .role)
        activation = try container.decodeIfPresent(PatientActivation.self, forKey: .activation)
        patientId = try container.decodeIfPresent(UUID.self, forKey: .patientId)
        entitlement = try? container.decode(AppEntitlement.self, forKey: .entitlement)
    }

    var isActivePatient: Bool {
        role == .patient && activation == .active && patientId != nil
    }

    var isIncompletePatient: Bool {
        role == .patient && activation == .incomplete
    }
}

/// Fetches `AppContext` through the shared authenticated Supabase client.
@Observable
@MainActor
final class AppContextService {
    private let telemetryClient: TelemetryClient
    private let identity: () -> String?
    private let requestContext: () async throws -> AppContext
    private var lastRefresh: Date?
    private var account: String?
    private var generation = 0
    private var requestSequence = 0

    private(set) var current: AppContext?
    private(set) var isLoading = false
    private(set) var loadError: String?

    init(identity: @escaping () -> String?, request: @escaping () async throws -> AppContext, telemetry: TelemetryClient = .shared) {
        self.telemetryClient = telemetry
        self.identity = identity
        self.requestContext = request
    }

    func getCurrentAppContext() async throws -> AppContext {
        let telemetry = telemetryClient.begin(.access)
        let identity = self.identity()
        guard identity != nil else { telemetry.event(.failed,error:.unavailable); throw AuthError.verificationFailed }
        let requestGeneration = generation
        requestSequence += 1
        let request = requestSequence
        if account != identity { current = nil; lastRefresh = nil; account = identity }
        EntitlementState.shared.setIdentity(identity)
        isLoading = true
        loadError = nil
        defer { if requestGeneration == generation && request == requestSequence { isLoading = false } }
        do {
            let requestTelemetry = telemetry.requestOperation(.appContext)
            requestTelemetry.event(.started)
            let context: AppContext
            do { context = try await requestContext(); requestTelemetry.event(.succeeded) }
            catch { requestTelemetry.event(.failed, error: .generic); throw error }
            guard requestGeneration == generation, request == requestSequence, identity == self.identity(), identity == account else { throw CancellationError() }
            current = context
            lastRefresh = Date()
            EntitlementState.shared.apply(context)
            AppLog.auth.info("App context received, role: \(context.role.rawValue, privacy: .public)")
            if let access = context.entitlement?.access {
                telemetry.event(.succeeded, access: access == .full ? .full : .readOnly)
            } else { telemetry.event(.failed, error: .unresolved) }
            return context
        } catch {
            telemetry.event(error is CancellationError ? .cancelled : .failed, error: error is CancellationError ? .cancelled : .generic)
            if requestGeneration == generation && request == requestSequence && identity == account && identity == self.identity() {
                EntitlementState.shared.invalidate()
                loadError = error.localizedDescription
            }
            throw error
        }
    }

    func refreshOnForeground() async {
        guard identity() != nil, !isLoading else { return }
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < 60 { return }
        _ = try? await getCurrentAppContext()
    }

    func clear() {
        generation += 1
        account = nil; lastRefresh = nil
        EntitlementState.shared.clear()
        current = nil
        loadError = nil
        isLoading = false
    }
}
