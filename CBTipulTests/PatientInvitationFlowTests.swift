import Foundation
import Testing
@testable import CBTipul

@MainActor
private final class InvitationGate {
    private var waiter: CheckedContinuation<Void, Never>?
    var waiting: Bool { waiter != nil }
    func wait() async { await withCheckedContinuation { waiter = $0 } }
    func open() { waiter?.resume(); waiter = nil }
}

@MainActor
private final class InvitationFixture {
    var session: InvitationSession?
    var initialization: () async -> Void = {}
    var existingContext = AppContext(version: 1, role: .patient, activation: .incomplete, patientId: nil)
    let patientID = UUID()
    var signOuts = 0, signIns = 0, claims = 0, contextCalls = 0, clears = 0
    var claimFailures = 0, contextFailures = 0, existingContextFailures = 0, signInFailures = 0
    var claimed = false
    var anonymousSignInReturnsTherapist = false
    var afterClaim: () -> Void = {}
    struct Failed: Error {}
    init(_ session: InvitationSession? = nil) { self.session = session }
    var dependencies: InvitationActivationDependencies {
        InvitationActivationDependencies(
            awaitInitialization: { await self.initialization() },
            session: { self.session },
            signOutLocally: { expected in
                #expect(self.session?.userID == expected)
                #expect(self.session?.isAnonymous == false)
                self.signOuts += 1; self.session = nil
            },
            signInAnonymously: {
                self.signIns += 1
                if self.signInFailures > 0 { self.signInFailures -= 1; throw Failed() }
                self.session = InvitationSession(userID: "anonymous", isAnonymous: !self.anonymousSignInReturnsTherapist)
            },
            clearContext: { self.clears += 1 },
            context: {
                self.contextCalls += 1
                if !self.claimed {
                    if self.existingContextFailures > 0 { self.existingContextFailures -= 1; throw Failed() }
                    return self.existingContext
                }
                if self.contextFailures > 0 { self.contextFailures -= 1; throw Failed() }
                return AppContext(version: 1, role: .patient, activation: .active, patientId: self.patientID)
            },
            claim: { token in
                #expect(self.session?.isAnonymous == true)
                #expect(token == "mock-invitation")
                self.claims += 1
                if self.claimFailures > 0 { self.claimFailures -= 1; throw PatientInvitationClaimError.failed }
                self.claimed = true
                self.afterClaim()
                return self.patientID
            }
        )
    }
}

@MainActor
struct PatientInvitationFlowTests {
    private let therapist = InvitationSession(userID: "therapist", isAnonymous: false)
    private let patient = InvitationSession(userID: "patient", isAnonymous: true)
    private func preview(_ flow: PatientInvitationFlow, token: String = "mock-invitation") async {
        flow.receive(token: token)
        await flow.loadPreview(using: { _ in PatientInvitationPreview(status: .valid, therapistDisplayName: "מטפל/ת", expiresAt: nil) })
        flow.continueToConsent()
    }

    @Test(arguments: [false, true]) func coldAndWarmInvitationReserveRootBeforeAwait(warm: Bool) async {
        let flow = PatientInvitationFlow()
        #expect(AppRootRouting.destination(invitationActive: false, hasSession: warm, isAnonymous: false) == (warm ? .therapist : .unauthenticated))
        flow.receive(token: "mock-invitation")
        #expect(flow.phase == .loading)
        #expect(AppRootRouting.destination(invitationActive: flow.isActive, hasSession: true, isAnonymous: false) == .invitation)
        await flow.loadPreview(using: { _ in PatientInvitationPreview(status: .valid, therapistDisplayName: "name", expiresAt: nil) })
        #expect(flow.phase == .preview(therapistDisplayName: "name"))
    }

    @Test func restoredTherapistRequiresSeparateConfirmationAndCancelPreservesAccess() async {
        let f = InvitationFixture(therapist), flow = PatientInvitationFlow()
        await preview(flow)
        await flow.activate(using: f.dependencies)
        #expect(flow.phase == .confirmTherapistSwitch)
        #expect(f.signOuts == 0 && f.signIns == 0 && f.claims == 0 && f.clears == 0)
        flow.dismiss()
        #expect(f.session == therapist)
        #expect(AppRootRouting.destination(invitationActive: flow.isActive, hasSession: true, isAnonymous: false) == .therapist)
    }

    @Test func confirmedSwitchIsLocalThenAnonymousThenClaim() async {
        let f = InvitationFixture(therapist), flow = PatientInvitationFlow()
        await preview(flow); await flow.activate(using: f.dependencies)
        await flow.confirmTherapistSwitch(using: f.dependencies)
        #expect(f.signOuts == 1 && f.signIns == 1 && f.claims == 1)
        #expect(f.session?.isAnonymous == true && flow.phase == .idle && flow.token == nil)
    }

    @Test func delayedRestorationCannotSkipSwitchConfirmation() async {
        let gate = InvitationGate(), f = InvitationFixture(), flow = PatientInvitationFlow()
        f.initialization = { await gate.wait() }
        await preview(flow)
        let task = Task { await flow.activate(using: f.dependencies) }
        while !gate.waiting { await Task.yield() }
        #expect(flow.phase == .activating && flow.token != nil)
        f.session = therapist; gate.open(); await task.value
        #expect(flow.phase == .confirmTherapistSwitch && f.claims == 0 && f.signIns == 0)
    }

    @Test func changedAccountDuringConfirmationNeedsFreshApproval() async {
        let f = InvitationFixture(therapist), flow = PatientInvitationFlow()
        await preview(flow); await flow.activate(using: f.dependencies)
        f.session = InvitationSession(userID: "other-therapist", isAnonymous: false)
        await flow.confirmTherapistSwitch(using: f.dependencies)
        #expect(flow.phase == .confirmTherapistSwitch && f.signOuts == 0 && f.claims == 0)
    }

    @Test func claimFailureKeepsTokenAndRetriesUnderSameAnonymousSession() async {
        let f = InvitationFixture(), flow = PatientInvitationFlow(); f.claimFailures = 1
        await preview(flow); await flow.activate(using: f.dependencies)
        #expect(flow.phase == .activationFailed(.claim(nil)) && flow.token == "mock-invitation")
        await flow.activate(using: f.dependencies)
        #expect(flow.phase == .idle && f.claims == 2 && f.signIns == 1)
    }

    @Test func postClaimContextRetryDoesNotConsumeInvitationTwice() async {
        let f = InvitationFixture(), flow = PatientInvitationFlow(); f.contextFailures = 1
        await preview(flow); await flow.activate(using: f.dependencies)
        #expect(flow.phase == .activationFailed(.context) && flow.didSucceedClaim)
        await flow.activate(using: f.dependencies)
        #expect(flow.phase == .idle && f.claims == 1 && f.signIns == 1)
    }

    @Test func signInFailureAfterConfirmedSwitchCanRetry() async {
        let f = InvitationFixture(therapist), flow = PatientInvitationFlow(); f.signInFailures = 1
        await preview(flow); await flow.activate(using: f.dependencies)
        await flow.confirmTherapistSwitch(using: f.dependencies)
        #expect(flow.phase == .activationFailed(.signIn) && flow.token != nil && f.claims == 0)
        await flow.activate(using: f.dependencies)
        #expect(flow.phase == .idle && f.signOuts == 1 && f.signIns == 2)
    }

    @Test(arguments: ["same-invitation", "different-invitation"]) func connectedPatientIsNeverRebound(invitation: String) async {
        let f = InvitationFixture(patient), flow = PatientInvitationFlow()
        f.existingContext = AppContext(version: 1, role: .patient, activation: .active, patientId: UUID())
        await preview(flow, token: invitation); await flow.activate(using: f.dependencies)
        #expect(flow.phase == .existingPatient && f.session == patient)
        #expect(f.signOuts == 0 && f.signIns == 0 && f.claims == 0)
        flow.dismiss(); #expect(f.session == patient)
    }

    @Test func patientContextFailurePreservesConnectionAndRetryDoesNotClaimBlindly() async {
        let f = InvitationFixture(patient), flow = PatientInvitationFlow(); f.existingContextFailures = 1
        f.existingContext = AppContext(version: 1, role: .patient, activation: .active, patientId: UUID())
        await preview(flow); await flow.activate(using: f.dependencies)
        #expect(flow.phase == .activationFailed(.context) && f.session == patient)
        await flow.activate(using: f.dependencies)
        #expect(flow.phase == .existingPatient && f.claims == 0 && f.signOuts == 0)
    }

    @Test func restoredIncompletePatientCannotBeAssumedUnbound() async {
        let f = InvitationFixture(patient), flow = PatientInvitationFlow()
        await preview(flow); await flow.activate(using: f.dependencies)
        #expect(flow.phase == .existingPatient && f.session == patient && f.signIns == 0 && f.claims == 0)
    }

    @Test func unexpectedTherapistAfterAnonymousSignInCannotClaim() async {
        let f = InvitationFixture(), flow = PatientInvitationFlow(); f.anonymousSignInReturnsTherapist = true
        await preview(flow); await flow.activate(using: f.dependencies)
        #expect(f.claims == 0 && flow.isActive)
    }

    @Test func staleIdentityAfterClaimCannotFinishActivation() async {
        let f = InvitationFixture(), flow = PatientInvitationFlow()
        f.afterClaim = { f.session = self.therapist }
        await preview(flow); await flow.activate(using: f.dependencies)
        #expect(flow.phase == .activationFailed(.context))
        await flow.activate(using: f.dependencies)
        #expect(f.claims == 1 && flow.isActive)
    }

    @Test func stalePreviewAndDuplicateDeliveryCannotOverrideCurrentInvitation() async {
        let flow = PatientInvitationFlow(), gate = InvitationGate()
        flow.receive(token: "old")
        let old = Task { await flow.loadPreview(using: { _ in await gate.wait(); return PatientInvitationPreview(status: .valid, therapistDisplayName: "old", expiresAt: nil) }) }
        while !gate.waiting { await Task.yield() }
        flow.receive(token: "mock-invitation")
        await flow.loadPreview(using: { _ in PatientInvitationPreview(status: .valid, therapistDisplayName: "new", expiresAt: nil) })
        flow.continueToConsent(); flow.receive(token: "mock-invitation")
        gate.open(); await old.value
        #expect(flow.phase == .consent && flow.token == "mock-invitation")
    }

    @Test func incomingLinkAndDismissDuringActivationCannotLoseAcceptedToken() async {
        let flow = PatientInvitationFlow(), f = InvitationFixture(), gate = InvitationGate()
        f.initialization = { await gate.wait() }
        await preview(flow)
        let task = Task { await flow.activate(using: f.dependencies) }
        while !gate.waiting { await Task.yield() }
        flow.receive(token: "other"); flow.dismiss()
        #expect(flow.token == "mock-invitation" && flow.phase == .activating)
        gate.open(); await task.value
        #expect(flow.phase == .idle)
    }

    @Test(arguments: ["ordinary-update-pre-marker", "reinstall-surviving-keychain", "restored-backup"])
    func persistedSessionIsNeverClearedOnFlowInitialization(scenario: String) async {
        let f = InvitationFixture(therapist)
        let flow = PatientInvitationFlow()
        #expect(f.session == therapist && f.signOuts == 0 && !flow.isActive)
        await preview(flow); flow.dismiss()
        #expect(f.session == therapist && f.signOuts == 0 && f.claims == 0)
    }
}

@MainActor
struct InvitationContextRaceTests {
    @Test func clearInvalidatesOldContextEvenForSameUser() async {
        let gate = InvitationGate()
        var calls = 0
        let patientID = UUID()
        let active = AppContext(version: 1, role: .patient, activation: .active, patientId: patientID)
        let context = AppContextService(identity: { "patient" }, request: {
            calls += 1
            if calls == 1 { await gate.wait(); return AppContext(version: 1, role: .patient, activation: .incomplete, patientId: nil) }
            return active
        })
        let old = Task { try? await context.getCurrentAppContext() }
        while !gate.waiting { await Task.yield() }
        context.clear(); _ = try? await context.getCurrentAppContext()
        gate.open(); _ = await old.value
        #expect(context.current == active && !context.isLoading)
    }

    @Test func delayedTherapistContextCannotReplaceActivatedPatient() async {
        let gate = InvitationGate(); var identity = "therapist"; var calls = 0
        let active = AppContext(version: 1, role: .patient, activation: .active, patientId: UUID())
        let context = AppContextService(identity: { identity }, request: {
            calls += 1
            if calls == 1 { await gate.wait(); return AppContext(version: 1, role: .therapist, activation: nil, patientId: nil) }
            return active
        })
        let old = Task { try? await context.getCurrentAppContext() }
        while !gate.waiting { await Task.yield() }
        identity = "patient"; context.clear(); _ = try? await context.getCurrentAppContext()
        gate.open(); _ = await old.value
        #expect(context.current == active)
    }
}

struct InvitationSessionObservationTests {
    @Test func staleTherapistAndSignOutEventsCannotOverrideCurrentPatient() {
        let therapist = InvitationSession(userID: "therapist", isAnonymous: false)
        let patient = InvitationSession(userID: "patient", isAnonymous: true)
        #expect(!AuthSessionObservation.isCurrent(therapist, current: patient))
        #expect(!AuthSessionObservation.isCurrent(nil, current: patient))
        #expect(AuthSessionObservation.isCurrent(patient, current: patient))
        #expect(AuthSessionObservation.isCurrent(therapist, current: therapist))
        #expect(AuthSessionObservation.isCurrent(nil, current: nil))
    }
}
