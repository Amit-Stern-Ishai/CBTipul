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
/// therapists. Entitlement is intentionally not modeled yet.
nonisolated struct AppContext: Codable, Equatable, Sendable {
    let version: Int
    let role: AppRole
    let activation: PatientActivation?
    let patientId: UUID?

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

    private(set) var current: AppContext?
    private(set) var isLoading = false
    private(set) var loadError: String?

    init(client: SupabaseClient) {
        self.client = client
    }

    func getCurrentAppContext() async throws -> AppContext {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let context: AppContext = try await client.functions.invoke("get-app-context")
            current = context
            AppLog.auth.info("App context received, role: \(context.role.rawValue, privacy: .public)")
            return context
        } catch {
            loadError = error.localizedDescription
            throw error
        }
    }

    func clear() {
        current = nil
        loadError = nil
        isLoading = false
    }
}
