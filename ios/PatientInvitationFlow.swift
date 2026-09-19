import Foundation
import OSLog
import SwiftUI

/// In-memory patient invitation preview/activation flow. Independent of
/// therapist login. The raw token is never persisted.
@Observable
@MainActor
final class PatientInvitationFlow {
    enum Phase: Equatable {
        case idle
        case loading
        case preview(therapistDisplayName: String)
        case unavailable(PatientInvitationPreviewStatus)
        case failed(String)
        case consent
        case activating
        case activationFailed(ActivationFailure)
    }

    enum ActivationFailure: Equatable {
        case signIn
        case claim(PatientInvitationPreviewStatus?)
        case context
    }

    private(set) var token: String?
    private(set) var therapistDisplayName: String?
    private(set) var phase: Phase = .idle
    /// After a successful claim, retries must only re-check app context.
    private(set) var didSucceedClaim = false
    private var isActivationInFlight = false

    var isActive: Bool { phase != .idle }

    func start(token: String, service: PatientInvitationService) async {
        self.token = token
        didSucceedClaim = false
        phase = .loading
        do {
            let preview = try await service.getPatientInvitation(token: token)
            guard self.token == token else { return }
            switch preview.status {
            case .valid:
                let name = preview.therapistDisplayName?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                therapistDisplayName = name
                phase = .preview(therapistDisplayName: name)
            case .expired, .claimed, .cancelled, .invalid:
                phase = .unavailable(preview.status)
            }
        } catch {
            guard self.token == token else { return }
            AppLog.store.error(
                "Invitation preview failed: \(error.localizedDescription, privacy: .public)"
            )
            phase = .failed(error.localizedDescription)
        }
    }

    func continueToConsent() {
        guard case .preview = phase else { return }
        phase = .consent
    }

    /// Returns to the preview without clearing the in-memory token.
    func returnToPreview() {
        guard token != nil else { return }
        phase = .preview(therapistDisplayName: therapistDisplayName ?? "")
    }

    func activate(
        auth: AuthManager,
        invitations: PatientInvitationService,
        appContext: AppContextService
    ) async {
        guard !isActivationInFlight else { return }
        guard phase == .consent || isActivationFailure else { return }
        isActivationInFlight = true
        phase = .activating
        defer { isActivationInFlight = false }
        do {
            if !didSucceedClaim {
                try await ensureAnonymousSession(auth: auth)
                guard let token else {
                    phase = .activationFailed(.claim(nil))
                    return
                }
                _ = try await invitations.claimPatientInvitation(token: token)
                didSucceedClaim = true
                self.token = nil
            }
            let context = try await appContext.getCurrentAppContext()
            guard context.isActivePatient else {
                phase = .activationFailed(.context)
                return
            }
            therapistDisplayName = nil
            phase = .idle
        } catch let error as PatientInvitationClaimError {
            switch error {
            case .status(let status):
                phase = .activationFailed(.claim(status))
            case .failed:
                phase = .activationFailed(.claim(nil))
            }
        } catch {
            if didSucceedClaim {
                phase = .activationFailed(.context)
            } else if auth.isAnonymousUser {
                phase = .activationFailed(.claim(nil))
            } else {
                phase = .activationFailed(.signIn)
            }
        }
    }

    func retryActivation(
        auth: AuthManager,
        invitations: PatientInvitationService,
        appContext: AppContextService
    ) async {
        await activate(auth: auth, invitations: invitations, appContext: appContext)
    }

    func dismiss() {
        token = nil
        therapistDisplayName = nil
        didSucceedClaim = false
        phase = .idle
    }

    private var isActivationFailure: Bool {
        if case .activationFailed = phase { return true }
        return false
    }

    private func ensureAnonymousSession(auth: AuthManager) async throws {
        if auth.hasSession, auth.isAnonymousUser { return }
        if auth.hasSession, !auth.isAnonymousUser {
            await auth.signOutAndWait()
        }
        try await auth.signInAnonymously()
        guard auth.hasSession, auth.isAnonymousUser else {
            throw AuthError.verificationFailed
        }
    }
}
