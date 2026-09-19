import SwiftUI
import OSLog

@main
struct MyApp: App {
    @State private var auth: AuthManager
    @State private var store: PatientStore
    @State private var therapistProfiles: TherapistProfileService
    @State private var appContext: AppContextService
    @State private var invitationFlow: PatientInvitationFlow

    init() {
        // The SwiftUI right-to-left override (see AppTextSizeModifier) doesn't
        // reach UIKit-backed controls like TextField's backing field, which
        // would re-resolve to left-to-right the moment they gain focus
        // (e.g. placeholders jumping sides). Force the UIKit layer too.
        UIView.appearance().semanticContentAttribute = .forceRightToLeft

        // Segmented controls are UIKit-backed and ignore the SwiftUI tint,
        // which leaves them system-gray; align them with the theme instead.
        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = Theme.uiAccentFill
        segmented.backgroundColor = Theme.uiElevated
        segmented.setTitleTextAttributes([.foregroundColor: Theme.uiTextOnAccent], for: .selected)
        segmented.setTitleTextAttributes([.foregroundColor: Theme.uiTextBright], for: .normal)

        let auth = AuthManager()
        _auth = State(initialValue: auth)
        _store = State(initialValue: PatientStore(client: auth.client))
        _therapistProfiles = State(initialValue: TherapistProfileService(client: auth.client))
        _appContext = State(initialValue: AppContextService(client: auth.client))
        _invitationFlow = State(initialValue: PatientInvitationFlow())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .environment(store)
                .environment(therapistProfiles)
                .environment(appContext)
                .environment(invitationFlow)
                .onOpenURL(perform: handleIncomingURL)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        handleIncomingURL(url)
                    }
                }
        }
    }

    /// Auth custom-scheme callbacks stay on `cbtipul://`. Invitation
    /// Universal Links are `https://cbtipul.com/invite/<TOKEN>` only.
    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "cbtipul",
           url.host() == "auth-callback" || url.host() == "password-reset" {
            Task { await auth.handleAuthCallback(url) }
            return
        }
        guard let token = InvitationLink.token(from: url) else { return }
        Task {
            await invitationFlow.start(
                token: token,
                service: PatientInvitationService(client: auth.client)
            )
        }
    }
}

/// Root view that shows the sign-in screen or the patient list depending on
/// authentication state.
struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(TherapistProfileService.self) private var therapistProfiles
    @Environment(AppContextService.self) private var appContext
    @Environment(PatientInvitationFlow.self) private var invitationFlow

    @State private var isShowingSplash = true
    @State private var hasAcceptedTerms = false
    @State private var onboarding = OnboardingStore.shared
    @State private var isResolvingDisplayNameGate = false
    @State private var showOptionalDisplayNamePrompt = false

    var body: some View {
        @Bindable var auth = auth
        @Bindable var onboarding = onboarding
        return ZStack {
            if invitationFlow.isActive {
                PatientInvitationFlowView()
            } else if auth.isAuthenticated {
                // Existing therapist email/password session. Unchanged.
                if showOptionalDisplayNamePrompt {
                    // Full-screen gate (not a second root sheet) so this
                    // never races Terms/Welcome or the password-recovery sheet.
                    TherapistDisplayNameEditorView(
                        requirement: .optional,
                        onOptionalFinished: {
                            onboarding.markDisplayNamePromptShown()
                            showOptionalDisplayNamePrompt = false
                        }
                    )
                } else if isResolvingDisplayNameGate {
                    Theme.base.ignoresSafeArea()
                } else if !hasAcceptedTerms {
                    // Signed in but not yet agreed: the app stays blocked
                    // behind the terms until the user accepts.
                    NavigationStack {
                        TermsView {
                            if let email = auth.currentUserEmail {
                                TermsAcceptance.setAccepted(email: email)
                            }
                            hasAcceptedTerms = true
                        }
                    }
                } else if !onboarding.welcomeDismissed {
                    // After terms: blocking welcome until Start or Skip.
                    WelcomeOnboardingView(
                        onStartDemoTour: {
                            onboarding.markDemoTourCompleted()
                            onboarding.dismissWelcome()
                            onboarding.showChecklistAgain()
                            store.enterDemoMode()
                        },
                        onSkip: {
                            onboarding.dismissWelcome()
                        }
                    )
                } else {
                    PatientListView()
                }
            } else if auth.hasSession {
                patientSessionRoot
            } else {
                AuthView()
            }

            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .appTextSize()
        // A password-recovery link signs the user in without a new password;
        // this prompt completes the reset.
        .sheet(isPresented: $auth.isRecoveringPassword) {
            NewPasswordView()
        }
        .onChange(of: auth.currentUserEmail, initial: true) { _, email in
            hasAcceptedTerms = email.map(TermsAcceptance.hasAccepted) ?? false
            // AI data-sharing consent is per account too: switching users
            // swaps in that account's own stored decision.
            AIDataSharingConsentStore.shared.setActiveUser(email: email)
        }
        .onChange(of: auth.currentUserId, initial: true) { _, userId in
            onboarding.setActiveUser(id: userId)
            if userId == nil {
                therapistProfiles.clearCache()
                appContext.clear()
                showOptionalDisplayNamePrompt = false
                isResolvingDisplayNameGate = false
            }
            // After AuthView's UITesting inject: skip welcome and enter demo.
            if AuthManager.isUITesting, userId != nil {
                hasAcceptedTerms = true
                onboarding.dismissWelcome()
                onboarding.markDemoTourCompleted()
                onboarding.markDisplayNamePromptShown()
                if !store.isDemoMode {
                    store.enterDemoMode()
                }
            }
        }
        .task(id: displayNameGateTaskID) {
            await resolveDisplayNameGate()
        }
        .task(id: auth.currentUserId) {
            await resolveAnonymousAppContext()
        }
        .environment(onboarding)
        .task {
            if AuthManager.isUITesting {
                // Skip splash so AuthView (and its IDs) appear immediately.
                isShowingSplash = false
                return
            }
            // Keep the splash up briefly so the session can be restored
            // without flashing the sign-in screen.
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.4)) {
                isShowingSplash = false
            }
        }
    }

    /// Anonymous sessions never use therapist AuthView. Context decides
    /// Patient Mode vs a recoverable incomplete/retry state.
    @ViewBuilder
    private var patientSessionRoot: some View {
        if let context = appContext.current {
            if context.isActivePatient {
                PatientModePlaceholderView()
            } else if context.role == .patient {
                PatientActivationIncompleteView {
                    Task { await resolveAnonymousAppContext() }
                }
            } else {
                PatientContextRetryView {
                    Task { await resolveAnonymousAppContext() }
                }
            }
        } else if appContext.isLoading {
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
        } else {
            PatientContextRetryView {
                Task { await resolveAnonymousAppContext() }
            }
        }
    }

    /// Re-runs the optional prompt check when the signed-in user changes
    /// or password recovery ends (recovery uses the root sheet).
    private var displayNameGateTaskID: String {
        "\(auth.currentUserId ?? "")-\(auth.isRecoveringPassword)"
    }

    private func resolveAnonymousAppContext() async {
        guard auth.hasSession, !auth.isAuthenticated, !AuthManager.isUITesting else {
            return
        }
        do {
            _ = try await appContext.getCurrentAppContext()
        } catch {
            AppLog.auth.error(
                "Patient app context failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func resolveDisplayNameGate() async {
        showOptionalDisplayNamePrompt = false
        guard auth.isAuthenticated,
              auth.currentUserId != nil,
              !AuthManager.isUITesting,
              !auth.isRecoveringPassword
        else {
            isResolvingDisplayNameGate = false
            return
        }
        if onboarding.displayNamePromptShown {
            isResolvingDisplayNameGate = false
            return
        }
        isResolvingDisplayNameGate = true
        defer { isResolvingDisplayNameGate = false }
        do {
            let profile = try await therapistProfiles.getCurrentProfile()
            guard !Task.isCancelled else { return }
            if profile?.hasValidDisplayName == true {
                onboarding.markDisplayNamePromptShown()
            } else {
                showOptionalDisplayNamePrompt = true
            }
        } catch {
            AppLog.store.error(
                "Optional display-name check failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

#Preview {
    let auth = AuthManager()
    ContentView()
        .environment(auth)
        .environment(PatientStore(client: auth.client))
        .environment(TherapistProfileService(client: auth.client))
        .environment(AppContextService(client: auth.client))
        .environment(PatientInvitationFlow())
}
