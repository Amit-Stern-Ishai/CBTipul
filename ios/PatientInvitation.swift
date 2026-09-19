import Foundation
import OSLog
import Supabase
import SwiftUI

enum InvitationKind: String, Encodable, Sendable {
    case initial
}

/// Response from the `create-patient-invitation` Edge Function.
/// `invitationUrl` is used exactly as returned — the token is never parsed.
nonisolated struct PatientInvitation: Decodable, Sendable {
    let invitationId: UUID
    let invitationUrl: String
    let expiresAt: String
}

private struct CreatePatientInvitationRequest: Encodable {
    let patientId: UUID
    let kind: InvitationKind
}

enum PatientInvitationPreviewStatus: String, Codable, Sendable {
    case valid
    case expired
    case claimed
    case cancelled
    case invalid
}

/// Response from `get-patient-invitation`. Patient-only fields are present
/// when `status` is `valid`.
nonisolated struct PatientInvitationPreview: Decodable, Sendable {
    let status: PatientInvitationPreviewStatus
    let therapistDisplayName: String?
    let expiresAt: String?
}

private struct GetPatientInvitationRequest: Encodable {
    let token: String
}

nonisolated struct ClaimedPatientInvitation: Decodable, Sendable {
    let patientId: UUID
    let therapistId: UUID
}

enum PatientInvitationClaimError: LocalizedError {
    case status(PatientInvitationPreviewStatus)
    case failed

    var errorDescription: String? {
        switch self {
        case .status(.expired): L10n.inviteExpiredTitle
        case .status(.claimed): L10n.inviteClaimedTitle
        case .status(.cancelled): L10n.inviteCancelledTitle
        case .status(.invalid): L10n.inviteInvalidTitle
        case .status(.valid), .failed: L10n.patientActivationClaimFailed
        }
    }
}

/// Creates patient invitations through the shared authenticated Supabase client.
@MainActor
final class PatientInvitationService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func createPatientInvitation(
        patientId: UUID,
        kind: InvitationKind = .initial
    ) async throws -> PatientInvitation {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        let invitation: PatientInvitation = try await client.functions.invoke(
            "create-patient-invitation",
            options: FunctionInvokeOptions(
                body: CreatePatientInvitationRequest(patientId: patientId, kind: kind)
            )
        )
        AppLog.store.info("Patient invitation created")
        return invitation
    }

    /// Public preview of an invitation token. Callable without signing in.
    /// Does not claim the invitation or create an auth user.
    func getPatientInvitation(token: String) async throws -> PatientInvitationPreview {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        let preview: PatientInvitationPreview = try await client.functions.invoke(
            "get-patient-invitation",
            options: FunctionInvokeOptions(
                body: GetPatientInvitationRequest(token: token)
            )
        )
        AppLog.store.info(
            "Invitation preview status: \(preview.status.rawValue, privacy: .public)"
        )
        return preview
    }

    /// Claims the invitation for the current authenticated (anonymous) user.
    /// Creates `patient_access` only on the server.
    func claimPatientInvitation(token: String) async throws -> ClaimedPatientInvitation {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        do {
            let claimed: ClaimedPatientInvitation = try await client.functions.invoke(
                "claim-patient-invitation",
                options: FunctionInvokeOptions(
                    body: GetPatientInvitationRequest(token: token)
                )
            )
            AppLog.store.info("Patient invitation claimed")
            return claimed
        } catch let FunctionsError.httpError(_, data) {
            if let preview = try? JSONDecoder().decode(PatientInvitationPreview.self, from: data),
               preview.status != .valid {
                throw PatientInvitationClaimError.status(preview.status)
            }
            AppLog.store.error("Patient invitation claim failed")
            throw PatientInvitationClaimError.failed
        } catch let error as PatientInvitationClaimError {
            throw error
        } catch {
            AppLog.store.error(
                "Patient invitation claim failed: \(error.localizedDescription, privacy: .public)"
            )
            throw PatientInvitationClaimError.failed
        }
    }
}

/// Native share sheet. The app has no existing share helper.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
