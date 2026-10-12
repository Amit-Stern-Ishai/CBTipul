import Foundation

@MainActor
extension PatientInvitationFlow {
    func loadPreview(service: PatientInvitationService) async {
        await loadPreview(using: { try await service.getPatientInvitation(token: $0) })
    }

    private func dependencies(auth: AuthManager, invitations: PatientInvitationService,
                              appContext: AppContextService) -> InvitationActivationDependencies {
        InvitationActivationDependencies(
            awaitInitialization: { await auth.awaitInvitationSessionInitialization() },
            session: { auth.invitationSession },
            signOutLocally: { try await auth.signOutLocallyForInvitation(expectedUserID: $0) },
            signInAnonymously: { try await auth.signInAnonymously() },
            clearContext: { appContext.clear() },
            context: { try await appContext.getCurrentAppContext() },
            claim: { try await invitations.claimPatientInvitation(token: $0).patientId }
        )
    }

    func activate(auth: AuthManager, invitations: PatientInvitationService, appContext: AppContextService) async {
        await activate(using: dependencies(auth: auth, invitations: invitations, appContext: appContext))
    }
    func confirmTherapistSwitch(auth: AuthManager, invitations: PatientInvitationService,
                                appContext: AppContextService) async {
        await confirmTherapistSwitch(using: dependencies(auth: auth, invitations: invitations, appContext: appContext))
    }
    func retryActivation(auth: AuthManager, invitations: PatientInvitationService, appContext: AppContextService) async {
        await activate(auth: auth, invitations: invitations, appContext: appContext)
    }
}
