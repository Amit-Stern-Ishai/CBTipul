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
}

/// Native share sheet. The app has no existing share helper.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
