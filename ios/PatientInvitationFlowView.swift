import SwiftUI

/// Patient-facing invitation preview. Shown instead of therapist login
/// while an invitation Universal Link is being handled.
struct PatientInvitationFlowView: View {
    @Environment(PatientInvitationFlow.self) private var flow
    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext

    var body: some View {
        Group {
            switch flow.phase {
            case .idle:
                EmptyView()
            case .loading:
                loading
            case .preview(let name):
                preview(therapistDisplayName: name)
            case .unavailable(let status):
                unavailable(status)
            case .failed(let message):
                messageScreen(
                    title: L10n.invitePreviewLoadFailedTitle,
                    body: message,
                    showsClose: true
                )
            case .consent:
                PatientInvitationConsentView()
            case .activating:
                activating
            case .activationFailed(let failure):
                activationFailed(failure)
            }
        }
        .appTextSize()
    }

    private var loading: some View {
        ZStack {
            Theme.base.ignoresSafeArea()
            ProgressView()
                .tint(Theme.gold)
                .controlSize(.large)
        }
    }

    private var activating: some View {
        ZStack {
            Theme.base.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(Theme.gold)
                    .controlSize(.large)
                Text(L10n.patientActivationConnecting)
                    .font(.body)
                    .foregroundStyle(Theme.textBody)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }

    private func activationFailed(_ failure: PatientInvitationFlow.ActivationFailure) -> some View {
        let copy = Self.copy(for: failure)
        return invitationChrome {
            Text(copy.title)
                .font(.title.bold())
                .foregroundStyle(Theme.textBright)
                .fixedSize(horizontal: false, vertical: true)
            Text(copy.body)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
        } footer: {
            Button {
                Task { await retryActivation() }
            } label: {
                Text(L10n.patientActivationRetryAction)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.pressableProminent)

            Button(L10n.invitePreviewCloseAction) {
                flow.dismiss()
            }
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.textBody)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .buttonStyle(.plain)
        }
    }

    @MainActor
    private func retryActivation() async {
        await flow.retryActivation(
            auth: auth,
            invitations: PatientInvitationService(client: auth.client),
            appContext: appContext
        )
    }

    private func preview(therapistDisplayName: String) -> some View {
        invitationChrome {
            Text(L10n.invitePreviewTitle)
                .font(.title.bold())
                .foregroundStyle(Theme.textBright)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.invitePreviewTherapistLine(therapistDisplayName))
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.invitePreviewExplanation)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
        } footer: {
            Button {
                flow.continueToConsent()
            } label: {
                Text(L10n.invitePreviewContinueAction)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.pressableProminent)

            Button(L10n.invitePreviewCloseAction) {
                flow.dismiss()
            }
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.textBody)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .buttonStyle(.plain)
        }
    }

    private func unavailable(_ status: PatientInvitationPreviewStatus) -> some View {
        let copy = Self.copy(for: status)
        return messageScreen(title: copy.title, body: copy.body, showsClose: true)
    }

    private func messageScreen(title: String, body: String, showsClose: Bool) -> some View {
        invitationChrome {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(Theme.textBright)
                .fixedSize(horizontal: false, vertical: true)

            if !body.isEmpty {
                Text(body)
                    .font(.body)
                    .foregroundStyle(Theme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            if showsClose {
                Button(L10n.invitePreviewCloseAction) {
                    flow.dismiss()
                }
                .fontWeight(.semibold)
                .buttonStyle(.pressableProminent)
            }
        }
    }

    private func invitationChrome<Content: View, Footer: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 32)
                VStack(spacing: 12) {
                    footer()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.base.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private static func copy(
        for status: PatientInvitationPreviewStatus
    ) -> (title: String, body: String) {
        switch status {
        case .valid:
            return (L10n.invitePreviewTitle, "")
        case .expired:
            return (L10n.inviteExpiredTitle, L10n.inviteExpiredBody)
        case .claimed:
            return (L10n.inviteClaimedTitle, L10n.inviteClaimedBody)
        case .cancelled:
            return (L10n.inviteCancelledTitle, L10n.inviteCancelledBody)
        case .invalid:
            return (L10n.inviteInvalidTitle, "")
        }
    }

    private static func copy(
        for failure: PatientInvitationFlow.ActivationFailure
    ) -> (title: String, body: String) {
        switch failure {
        case .signIn:
            return (L10n.patientActivationFailedTitle, L10n.patientActivationSignInFailedBody)
        case .claim(.expired):
            return (L10n.inviteExpiredTitle, L10n.inviteExpiredBody)
        case .claim(.claimed):
            return (L10n.inviteClaimedTitle, L10n.inviteClaimedBody)
        case .claim(.cancelled):
            return (L10n.inviteCancelledTitle, L10n.inviteCancelledBody)
        case .claim(.invalid):
            return (L10n.inviteInvalidTitle, "")
        case .claim(.valid), .claim(nil):
            return (L10n.patientActivationFailedTitle, L10n.patientActivationClaimFailed)
        case .context:
            return (L10n.patientActivationFailedTitle, L10n.patientActivationContextFailedBody)
        }
    }
}

/// Hebrew patient consent. Tapping continue starts activation.
private struct PatientInvitationConsentView: View {
    @Environment(PatientInvitationFlow.self) private var flow
    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var appContext
    @Environment(\.openURL) private var openURL

    @State private var hasAccepted = false
    @State private var isStartingActivation = false

    private var privacyURL: URL { URL(string: "https://cbtipul.com/privacy/")! }
    private var termsURL: URL { URL(string: "https://cbtipul.com/terms/")! }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L10n.inviteConsentTitle)
                        .font(.title.bold())
                        .foregroundStyle(Theme.textBright)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(L10n.inviteConsentIntro)
                        .font(.body)
                        .foregroundStyle(Theme.textBody)
                        .fixedSize(horizontal: false, vertical: true)

                    consentCard(
                        title: L10n.inviteConsentTherapistHeading,
                        body: L10n.inviteConsentTherapistBody
                    )
                    consentCard(
                        title: L10n.inviteConsentDataHeading,
                        body: L10n.inviteConsentDataBody
                    )
                    consentCard(
                        title: L10n.inviteConsentEmergencyHeading,
                        body: L10n.inviteConsentEmergencyBody
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            openURL(privacyURL)
                        } label: {
                            Text(L10n.privacyPolicyTitle)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.gold)
                        }
                        .buttonStyle(.plain)

                        Button {
                            openURL(termsURL)
                        } label: {
                            Text(L10n.termsTitle)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.gold)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        hasAccepted.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: hasAccepted ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundStyle(hasAccepted ? Theme.gold : Theme.textBody)
                            Text(L10n.inviteConsentAcceptance)
                                .font(.body)
                                .foregroundStyle(Theme.textBright)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isToggle)
                    .accessibilityValue(hasAccepted ? L10n.inviteConsentAcceptedValue : L10n.inviteConsentNotAcceptedValue)
                    .disabled(isStartingActivation)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button {
                        isStartingActivation = true
                        Task {
                            await flow.activate(
                                auth: auth,
                                invitations: PatientInvitationService(client: auth.client),
                                appContext: appContext
                            )
                        }
                    } label: {
                        Text(L10n.inviteConsentAcceptAction)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.pressableProminent)
                    .disabled(!hasAccepted || isStartingActivation)

                    Button(L10n.inviteConsentBackAction) {
                        flow.returnToPreview()
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textBody)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .buttonStyle(.plain)
                    .disabled(isStartingActivation)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .padding(.top, 12)
                .background(Theme.base)
            }
            .background(Theme.base.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func consentCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textBright)
            Text(body)
                .font(.body)
                .foregroundStyle(Theme.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themedCard()
    }
}
