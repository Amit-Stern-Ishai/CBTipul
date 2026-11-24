import Foundation
import Observation
import Supabase

/// Memory-only, per authentication session. Never persists an inferred role.
@Observable @MainActor
final class EmailInvitationClaim {
    enum State { case idle, checking, confirmation, unavailable, verification, failed, done }
    private(set) var state: State = .idle
    private var generation = 0
    struct Response: Decodable {
        let status: String
        let invitation_revision: String?
        init(_ status: String, revision: String? = nil) { self.status = status; invitation_revision = revision }
    }
    private var revision: String?
    private var confirmedRevision: String?
    private var awaitingPatient = false
    private var attempted = false
    let eligible: () -> Bool
    let request: (String?) async throws -> Response
    init(eligible: @escaping () -> Bool, request: @escaping (String?) async throws -> Response) {
        self.eligible = eligible; self.request = request
    }
    func reset() { generation += 1; state = .idle; revision = nil; confirmedRevision = nil; awaitingPatient = false; attempted = false }
    func retry(confirmSwitch: Bool = false) {
        guard state != .checking else { return }
        if confirmSwitch {
            guard state == .confirmation, let revision else { return }
            confirmedRevision = revision
        }
        state = .idle
    }
    func decline() { guard state == .confirmation || state == .unavailable else { return }; state = .done }
    func resolve(_ context: AppContext, reload: () async throws -> AppContext) async throws -> AppContext? {
        if context.isActivePatient { awaitingPatient = false; state = .done; return context }
        if context.role == .patient && !eligible() { return context }
        if state == .done { return context }
        guard state == .idle else { return nil }
        if !attempted && !eligible() { return context }
        attempted = true
        let epoch = generation
        state = .checking
        do {
            if awaitingPatient { throw ClaimFailure.unconfirmedRole }
            let wasConfirmation = confirmedRevision != nil
            var response = try await request(confirmedRevision)
            guard epoch == generation else { throw CancellationError() }
            if response.status == "invitation_changed" {
                revision = nil; confirmedRevision = nil
                response = try await request(nil)
                guard epoch == generation else { throw CancellationError() }
            }
            switch response.status {
            case "connected":
                awaitingPatient = true
                let updated = try await reload()
                guard epoch == generation else { throw CancellationError() }
                guard updated.isActivePatient else { throw ClaimFailure.unconfirmedRole }
                awaitingPatient = false; state = .done; return updated
            case "no_match":
                if wasConfirmation {
                    let updated = try await reload()
                    guard epoch == generation else { throw CancellationError() }
                    state = .done; return updated
                }
                state = .done; return context
            case "confirmation_required":
                guard let value = response.invitation_revision, UUID(uuidString: value) != nil else { throw ClaimFailure.invalidResponse }
                revision = value; confirmedRevision = nil; state = .confirmation
            case "invitation_changed":
                revision = nil; confirmedRevision = nil
                throw ClaimFailure.invalidResponse
            case "connection_unavailable": state = .unavailable
            case "email_not_verified": state = .verification
            default: throw ClaimFailure.invalidResponse
            }
            return nil
        } catch {
            if epoch == generation { state = .failed }
            throw error
        }
    }
    enum ClaimFailure: Error { case unconfirmedRole, invalidResponse }
}

extension EmailInvitationClaim {
    convenience init(client: SupabaseClient) {
        self.init(eligible: {
            guard let user = client.auth.currentUser else { return false }
            return !user.isAnonymous && user.emailConfirmedAt != nil && !(user.email ?? "").isEmpty
        }, request: { revision in
            struct Request: Encodable { let version = 2; let invitation_revision: String? }
            let body = Request(invitation_revision: revision)
            do {
                let response: Response = try await client.functions.invoke("claim-patient-email-invitation", options: .init(body: body))
                return response
            } catch {
                if case let FunctionsError.httpError(_, data) = error,
                   let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let code = (payload["status"] ?? payload["code"] ?? payload["error"]) as? String,
                   ["connection_unavailable", "email_not_verified", "invitation_changed"].contains(code) { return Response(code) }
                throw error
            }
        })
    }
}
