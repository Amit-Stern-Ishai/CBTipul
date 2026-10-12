import Foundation
import OSLog
import Supabase
import SwiftUI

enum InvitationKind: String, Encodable, Sendable {
    case initial
    case replacement
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
        try await EntitlementState.shared.requireWrite()
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
        // Preview is public. A restored/expired therapist credential must not
        // be attached to this request or make preview depend on auth refresh.
        let previewClient = FunctionsClient(
            url: SupabaseConfig.url.appendingPathComponent("functions/v1"),
            headers: ["apikey": SupabaseConfig.anonKey, "Authorization": "Bearer \(SupabaseConfig.anonKey)"]
        )
        let preview: PatientInvitationPreview = try await previewClient.invoke(
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
        guard let session = client.auth.currentSession, session.user.isAnonymous else {
            throw PatientInvitationClaimError.failed
        }
        // Pin this claim to the checked anonymous identity. The shared client's
        // fetchWithAuth could otherwise substitute a later therapist token.
        let claimClient = FunctionsClient(
            url: SupabaseConfig.url.appendingPathComponent("functions/v1"),
            headers: ["apikey": SupabaseConfig.anonKey, "Authorization": "Bearer \(session.accessToken)"]
        )
        do {
            let claimed: ClaimedPatientInvitation = try await claimClient.invoke(
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
                "Patient invitation claim failed"
            )
            throw PatientInvitationClaimError.failed
        }
    }
}

/// Native share sheet. The app has no existing share helper.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let invitation = items.compactMap { $0 as? InvitationShareActivityItem }.first
        let emailActions = invitation.map { [InvitationEmailActivity(invitation: $0)] }
        return UIActivityViewController(activityItems: items, applicationActivities: emailActions)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Supplies invitation body to all share targets, and a subject where the
/// destination supports it (Mail). WhatsApp/SMS ignore the subject.
final class InvitationShareActivityItem: NSObject, UIActivityItemSource {
    let body: String
    let subject: String
    let htmlBody: String?
    let emailBody: String?

    init(body: String, subject: String, htmlBody: String? = nil, emailBody: String? = nil) {
        self.body = body
        self.subject = subject
        self.htmlBody = htmlBody
        self.emailBody = emailBody
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        body
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        // Gmail displays HTML Strings literally (and HTML Data can produce an
        // empty body). Only Apple Mail receives HTML; Gmail must receive text.
        if activityType == .mail { return htmlBody ?? emailBody ?? body }
        if activityType?.rawValue == "com.google.Gmail.ShareExtension" { return emailBody ?? body }
        return body
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        activityType == .mail && htmlBody != nil ? "public.html" : "public.plain-text"
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        subject
    }
}

/// Opens an editable draft through the default email app, bypassing share-extension
/// text import. Never sends the invitation automatically.
final class InvitationEmailActivity: UIActivity {
    private let invitation: InvitationShareActivityItem

    init(invitation: InvitationShareActivityItem) {
        self.invitation = invitation
        super.init()
    }

    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType(rawValue: "com.CBTipul.emailInvitation")
    }
    override var activityTitle: String? { L10n.patientInvitationEmailAction }
    override var activityImage: UIImage? { UIImage(systemName: "envelope") }
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool { true }

    override func perform() {
        guard let url = Self.composeURL(subject: invitation.subject,
            body: invitation.emailBody ?? invitation.body) else {
            activityDidFinish(false)
            return
        }
        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            self?.activityDidFinish(opened)
        }
    }

    static func composeURL(subject: String, body: String) -> URL? {
        // RFC 6068: body line breaks must be CRLF, encoded as %0D%0A.
        // Encode values individually so invitation query parameters remain intact.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let normalizedBody = body.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "\r\n")
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedBody = normalizedBody.addingPercentEncoding(withAllowedCharacters: allowed)
        else { return nil }
        return URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)")
    }
}
