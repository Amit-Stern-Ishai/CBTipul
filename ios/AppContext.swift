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

#if DEBUG
/// Temporary probe: one `get-app-context` call per authenticated session,
/// shown as an alert. Does not affect routing.
struct DebugAppContextProbe: ViewModifier {
    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext

    @State private var dialog: Dialog?

    func body(content: Content) -> some View {
        content
            .task(id: auth.currentUserId) {
                await runOnceForCurrentSession()
            }
            .alert(
                dialog?.title ?? "",
                isPresented: Binding(
                    get: { dialog != nil },
                    set: { if !$0 { dialog = nil } }
                )
            ) {
                Button(L10n.debugAppContextOKAction, role: .cancel) { dialog = nil }
            } message: {
                Text(dialog?.message ?? "")
            }
    }

    @MainActor
    private func runOnceForCurrentSession() async {
        dialog = nil
        guard auth.isAuthenticated,
              auth.currentUserId != nil,
              !AuthManager.isUITesting
        else { return }

        do {
            let context = try await appContext.getCurrentAppContext()
            guard !Task.isCancelled else { return }
            dialog = Dialog(
                title: L10n.debugAppContextTitle,
                message: context.debugDialogMessage
            )
        } catch {
            guard !Task.isCancelled else { return }
            AppLog.auth.error(
                "App context debug probe failed: \(error.localizedDescription, privacy: .public)"
            )
            dialog = Dialog(
                title: L10n.debugAppContextErrorTitle,
                message: error.localizedDescription
            )
        }
    }

    private struct Dialog {
        let title: String
        let message: String
    }
}

private extension AppContext {
    var debugDialogMessage: String {
        var lines = [
            L10n.debugAppContextVersionLine(version),
            L10n.debugAppContextRoleLine(role.rawValue)
        ]
        if let activation {
            lines.append(L10n.debugAppContextActivationLine(activation.rawValue))
        }
        if let patientId {
            lines.append(L10n.debugAppContextPatientIDLine(patientId.uuidString))
        }
        return lines.joined(separator: "\n")
    }
}
#endif
