import SwiftUI
import OSLog

@main
struct MyApp: App {
    @State private var auth: AuthManager
    @State private var store: PatientStore
    @State private var therapistProfiles: TherapistProfileService
    @State private var appContext: AppContextService

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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .environment(store)
                .environment(therapistProfiles)
                .environment(appContext)
                // Supabase email-confirmation and password-recovery links
                // (works both when the app is already running and when the
                // link launches it).
                .onOpenURL { url in
                    guard url.scheme == "cbtipul",
                          url.host() == "auth-callback" || url.host() == "password-reset"
                    else { return }
                    Task { await auth.handleAuthCallback(url) }
                }
        }
    }
}

/// Root view that shows the sign-in screen or the patient list depending on
/// authentication state.
struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(TherapistProfileService.self) private var therapistProfiles

    @State private var isShowingSplash = true
    @State private var hasAcceptedTerms = false
    @State private var onboarding = OnboardingStore.shared
    @State private var isResolvingDisplayNameGate = false
    @State private var showOptionalDisplayNamePrompt = false

    var body: some View {
        @Bindable var auth = auth
        @Bindable var onboarding = onboarding
        return ZStack {
            if auth.isAuthenticated {
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
            } else {
                AuthView()
            }

            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .appTextSize()
        #if DEBUG
        .modifier(DebugAppContextProbe())
        #endif
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

    /// Re-runs the optional prompt check when the signed-in user changes
    /// or password recovery ends (recovery uses the root sheet).
    private var displayNameGateTaskID: String {
        "\(auth.currentUserId ?? "")-\(auth.isRecoveringPassword)"
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
}
