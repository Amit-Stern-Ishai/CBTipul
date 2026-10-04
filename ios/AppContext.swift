import Foundation
import OSLog
import Supabase
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
    private let client: SupabaseClient
    private var lastRefresh: Date?
    private var account: String?

    private(set) var current: AppContext?
    private(set) var isLoading = false
    private(set) var loadError: String?

    init(client: SupabaseClient) {
        self.client = client
    }

    func getCurrentAppContext() async throws -> AppContext {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        let identity = client.auth.currentUser?.id.uuidString
        if account != identity { current = nil; lastRefresh = nil; account = identity }
        EntitlementState.shared.setIdentity(identity)
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let context: AppContext = try await client.functions.invoke("get-app-context")
            guard identity == client.auth.currentUser?.id.uuidString, identity == account else { throw CancellationError() }
            current = context
            lastRefresh = Date()
            EntitlementState.shared.apply(context)
            AppLog.auth.info("App context received, role: \(context.role.rawValue, privacy: .public)")
            return context
        } catch {
            if identity == account && identity == client.auth.currentUser?.id.uuidString {
                EntitlementState.shared.invalidate()
                loadError = error.localizedDescription
            }
            throw error
        }
    }

    func refreshOnForeground() async {
        guard client.auth.currentUser != nil, !isLoading else { return }
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < 60 { return }
        _ = try? await getCurrentAppContext()
    }

    func clear() {
        account = nil; lastRefresh = nil
        EntitlementState.shared.clear()
        current = nil
        loadError = nil
        isLoading = false
    }
}
