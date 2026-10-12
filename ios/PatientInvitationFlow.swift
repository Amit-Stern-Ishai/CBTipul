import Foundation
import Observation

struct InvitationSession: Equatable {
    let userID: String
    let isAnonymous: Bool
}

/// All effects are injected so the activation state machine is tested offline.
@MainActor
struct InvitationActivationDependencies {
    var awaitInitialization: () async throws -> Void
    var session: () -> InvitationSession?
    var signOutLocally: (String) async throws -> Void
    var signInAnonymously: () async throws -> Void
    var clearContext: () -> Void
    var context: () async throws -> AppContext
    var claim: (String) async throws -> UUID
}

/// Invitations own the root before any asynchronous work. Tokens live only here.
@Observable
@MainActor
final class PatientInvitationFlow {
    enum Phase: Equatable {
        case idle, loading
        case preview(therapistDisplayName: String)
        case unavailable(PatientInvitationPreviewStatus)
        case failed(String)
        case consent, confirmTherapistSwitch, existingPatient, activating
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
    private(set) var didSucceedClaim = false
    private let telemetryClient: TelemetryClient
    init(telemetry: TelemetryClient = .shared) { telemetryClient = telemetry }
    private var telemetry: TelemetryOperation?
    private var generation = 0
    private var inFlight = false
    private var switchUserID: String?
    private var activationIdentity: InvitationSession?
    private var claimedPatientID: UUID?
    var isActive: Bool { phase != .idle }

    /// Synchronous reservation for both cold and warm links. Duplicate delivery
    /// and links arriving during an accepted activation cannot replace its token.
    func receive(token: String, start: TelemetryStart = .unknown) {
        guard !inFlight else { return }
        guard self.token != token || !isActive else { return }
        telemetry = telemetryClient.operation(.invitation)
        telemetry?.event(.received, start: start)
        generation += 1
        self.token = token
        therapistDisplayName = nil
        didSucceedClaim = false
        claimedPatientID = nil
        activationIdentity = nil
        switchUserID = nil
        phase = .loading
    }

    func loadPreview(using preview: (String) async throws -> PatientInvitationPreview) async {
        guard phase == .loading, let token else { return }
        let request = generation
        do {
            let requestTelemetry = telemetry?.requestOperation(.invitationPreview)
            requestTelemetry?.event(.started)
            let result: PatientInvitationPreview
            do { result = try await preview(token); requestTelemetry?.event(.succeeded) }
            catch { requestTelemetry?.event(.failed,error:.generic); throw error }
            guard request == generation, phase == .loading else { return }
            if result.status == .valid {
                let name = result.therapistDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                therapistDisplayName = name
                phase = .preview(therapistDisplayName: name)
                telemetry?.event(.previewShown)
            } else {
                phase = .unavailable(result.status)
                telemetry?.event(.failed, error: .unavailable)
            }
        } catch {
            guard request == generation, phase == .loading else { return }
            // Response/error text may contain the invitation token.
            phase = .failed(L10n.invitePreviewLoadFailedTitle)
            telemetry?.event(.failed, error: .generic)
        }
    }

    func continueToConsent() {
        guard case .preview = phase else { return }
        phase = .consent
    }
    func returnToPreview() {
        guard !inFlight, token != nil else { return }
        phase = .preview(therapistDisplayName: therapistDisplayName ?? "")
    }

    func activate(using dependencies: InvitationActivationDependencies) async {
        guard phase == .consent || isActivationFailure else { return }
        await runActivation(using: dependencies, confirmedTherapist: nil)
    }

    func confirmTherapistSwitch(using dependencies: InvitationActivationDependencies) async {
        guard phase == .confirmTherapistSwitch, let switchUserID else { return }
        await runActivation(using: dependencies, confirmedTherapist: switchUserID)
    }

    private func runActivation(using d: InvitationActivationDependencies, confirmedTherapist: String?) async {
        guard !inFlight else { return }
        telemetry?.event(.started)
        var telemetrySuccess = false
        defer { if !telemetrySuccess { telemetry?.event(.failed, error: .generic) } }
        inFlight = true
        phase = .activating
        defer { inFlight = false }
        var failure: ActivationFailure = .signIn
        do {
            try await d.awaitInitialization()
            telemetry = telemetry?.rebound()
            var session = d.session()
            if let expected = activationIdentity, session != expected {
                phase = .activationFailed(.signIn)
                return
            }
            if let existing = session, !existing.isAnonymous {
                guard !didSucceedClaim else { phase = .activationFailed(.context); return }
                guard confirmedTherapist == existing.userID else {
                    switchUserID = existing.userID
                    phase = .confirmTherapistSwitch
                    telemetrySuccess = true // Waiting for confirmation is not a failure.
                    return
                }
                telemetry?.event(.roleSwitchConfirmed, previous: .therapist)
                // Only this confirmation authorizes discarding this exact local session.
                d.clearContext()
                try await d.signOutLocally(existing.userID)
                guard d.session() == nil else { phase = .activationFailed(.signIn); return }
                session = nil
            } else if confirmedTherapist != nil {
                // The account changed while the confirmation was displayed.
                phase = .activationFailed(.signIn)
                return
            }
            if !didSucceedClaim {
                if let existing = session {
                    failure = .context
                    let context = try await d.context()
                    guard d.session() == existing else { phase = .activationFailed(.context); return }
                    // Preview exposes no patient ID. Same versus different invitation
                    // cannot safely be determined; never rebind any connected patient.
                    // Incomplete does not prove a restored identity has never
                    // been bound. Only reuse the anonymous identity created for
                    // this pending activation when retrying its same token.
                    if activationIdentity == nil || context.patientId != nil || context.isActivePatient {
                        phase = .existingPatient
                        return
                    }
                    guard context.isIncompletePatient else { phase = .activationFailed(.context); return }
                } else {
                    failure = .signIn
                    try await d.signInAnonymously()
                }
                guard let anonymous = d.session(), anonymous.isAnonymous else {
                    phase = .activationFailed(.signIn); return
                }
                telemetry = telemetry?.rebound()
                if confirmedTherapist != nil { telemetry?.event(.roleSwitchConfirmed, previous: .therapist) }
                activationIdentity = anonymous
                guard let token else { phase = .activationFailed(.claim(nil)); return }
                // No suspension between identity check and the authenticated claim.
                failure = .claim(nil)
                let requestTelemetry = telemetry?.requestOperation(.invitationClaim)
                requestTelemetry?.event(.started)
                do { claimedPatientID = try await d.claim(token); requestTelemetry?.event(.succeeded) }
                catch { requestTelemetry?.event(.failed,error:.generic); throw error }
                didSucceedClaim = true
            }
            failure = .context
            guard d.session() == activationIdentity else { phase = .activationFailed(.context); return }
            d.clearContext() // Invalidate even same-user pre-activation requests.
            let context = try await d.context()
            guard d.session() == activationIdentity, context.isActivePatient,
                  context.patientId == claimedPatientID else {
                phase = .activationFailed(.context); return
            }
            telemetry?.event(.succeeded)
            telemetrySuccess = true
            token = nil
            therapistDisplayName = nil
            phase = .idle
        } catch let error as PatientInvitationClaimError {
            switch error {
            case .status(let status): phase = .activationFailed(.claim(status))
            case .failed: phase = .activationFailed(.claim(nil))
            }
        } catch {
            if error is CancellationError { telemetry?.event(.cancelled,error:.cancelled); telemetrySuccess = true }
            phase = .activationFailed(failure)
        }
    }

    func dismiss() {
        guard !inFlight else { return }
        if isActive { telemetry?.event(.cancelled, error: .cancelled) }
        telemetry = nil
        generation += 1
        token = nil
        therapistDisplayName = nil
        didSucceedClaim = false
        activationIdentity = nil
        claimedPatientID = nil
        switchUserID = nil
        phase = .idle
    }
    private var isActivationFailure: Bool {
        if case .activationFailed = phase { return true }
        return false
    }
}
