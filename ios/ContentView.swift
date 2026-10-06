import SwiftUI
import OSLog

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var auth: AuthManager
    @State private var store: PatientStore
    @State private var therapistProfiles: TherapistProfileService
    @State private var appContext: AppContextService
    @State private var invitationFlow: PatientInvitationFlow
    @State private var diaryThree: DiaryThreeStore
    @State private var diaryTwo: DiaryTwoStore
    @State private var diaryOne: DiaryOneStore
    @State private var notificationStore: NotificationStore

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
        let store = PatientStore(client: auth.client)
        let diaryOne = DiaryOneStore(client: auth.client)
        let diaryTwo = DiaryTwoStore(client: auth.client)
        let diaryThree = DiaryThreeStore(client: auth.client)
        store.resetDemoContent = {
            diaryOne.clearDemoContent()
            diaryTwo.clearDemoContent()
            diaryThree.clearDemoContent()
        }
        _store = State(initialValue: store)
        _therapistProfiles = State(initialValue: TherapistProfileService(client: auth.client))
        _appContext = State(initialValue: AppContextService(client: auth.client))
        _invitationFlow = State(initialValue: PatientInvitationFlow())
        _diaryOne = State(initialValue: diaryOne)
        _diaryThree = State(initialValue: diaryThree)
        _diaryTwo = State(initialValue: diaryTwo)
        _notificationStore = State(initialValue: NotificationStore(client: auth.client))
    }

    var body: some Scene {
        WindowGroup {
            AppVersionGateView { ContentView() }
                .demoModeReminder()
                .environment(auth)
                .environment(store)
                .environment(therapistProfiles)
                .environment(appContext)
                .environment(invitationFlow)
                .environment(diaryOne)
                .environment(diaryTwo)
                .environment(diaryThree)
                .environment(notificationStore)
                .environment(TherapistNotificationCoordinator.shared)
                .environment(PatientModeMessageCoordinator.shared)
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
    @State private var entitlement = EntitlementState.shared
    @Environment(\.scenePhase) private var entitlementScenePhase
    @Environment(AppVersionManager.self) private var appVersion
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(TherapistProfileService.self) private var therapistProfiles
    @Environment(AppContextService.self) private var appContext
    @Environment(PatientInvitationFlow.self) private var invitationFlow
    @Environment(NotificationStore.self) private var notificationStore

    @State private var isShowingSplash = true
    @State private var hasAcceptedTerms = false
    @State private var onboarding = OnboardingStore.shared
    @State private var gettingStartedRouter = GettingStartedRouter()
    @State private var isResolvingDisplayNameGate = false
    @State private var showOptionalDisplayNamePrompt = false

    var body: some View {
        @Bindable var auth = auth
        @Bindable var onboarding = onboarding
        return VStack(spacing: 0) {
            // A real layout row keeps the notice outside navigation/toolbar bounds.
            if auth.isTherapistAuthenticated && entitlement.access == .readOnly
                && !invitationFlow.isActive && !isShowingSplash
                && !onboarding.shouldShowIntroduction && !entitlement.isLocalDemo {
                Button { entitlement.showExplanation = true } label: {
                    Label(L10n.entitlementReadOnlyTitle, systemImage: "eye")
                        .font(.footnote).frame(maxWidth: .infinity).padding(8)
                }
                .background(Theme.surface)
                .accessibilityIdentifier("entitlement.readOnlyNotice")
            }
            ZStack {
                switch AppRootRouting.destination(
                    invitationActive: invitationFlow.isActive,
                    hasSession: auth.hasSession,
                    isAnonymous: auth.isAnonymous
                ) {
                case .invitation:
                    PatientInvitationFlowView()
                case .therapist:
                    therapistSessionRoot
                case .anonymousPatient:
                    patientSessionRoot
                case .unauthenticated:
                    AuthView()
                }

                if isShowingSplash {
                    SplashView()
                        .transition(.opacity)
                }
            }
        }
        .alert(entitlement.role == .patient ? L10n.entitlementPatientUnavailable : L10n.entitlementReadOnlyTitle,
               isPresented: $entitlement.showExplanation) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(entitlement.role == .patient ? L10n.entitlementPatientUnavailable : entitlement.isLocalDemo ? L10n.entitlementDemoOnlineUnavailable : L10n.entitlementReadOnlyExplanation)
        }
        .onChange(of: entitlementScenePhase) { _, phase in
            if phase == .active && !AuthManager.isUITesting { Task { await appContext.refreshOnForeground() } }
        }
        .safeAreaInset(edge: .bottom) {
            if appVersion.optionalVisible && !isShowingSplash && !invitationFlow.isActive
                && !auth.isRecoveringPassword && (pushRegistrationContext != nil || !auth.hasSession) {
                AppUpdateNotice(required: false)
            }
        }
        .appTextSize()
        // A password-recovery link signs the user in without a new password;
        // this prompt completes the reset.
        .sheet(isPresented: $auth.isRecoveringPassword) {
            NewPasswordView()
        }
        .onChange(of: auth.currentUserEmail, initial: true) { _, email in
            guard !auth.isAnonymous else {
                hasAcceptedTerms = false
                return
            }
            hasAcceptedTerms = email.map(TermsAcceptance.hasAccepted) ?? false
            // AI data-sharing consent is per account too: switching users
            // swaps in that account's own stored decision.
            AIDataSharingConsentStore.shared.setActiveUser(email: email)
        }
        .onChange(of: auth.currentUserId, initial: true) { _, userId in
            entitlement.setIdentity(userId)
            if AuthManager.isUITesting && userId != nil {
                entitlement.apply(AppContext(version: 1, role: .therapist, activation: nil, patientId: nil, entitlement: AppEntitlement(access: .full)))
            }
            if userId == nil {
                therapistProfiles.clearCache()
                appContext.clear()
                showOptionalDisplayNamePrompt = false
                isResolvingDisplayNameGate = false
                notificationStore.clear()
                TherapistNotificationCoordinator.shared.resetOnLogout()
            }
            guard !auth.isAnonymous else {
                showOptionalDisplayNamePrompt = false
                isResolvingDisplayNameGate = false
                return
            }
            onboarding.setActiveUser(id: userId)
            // After AuthView's UITesting inject: skip welcome and enter demo.
            if AuthManager.isUITesting, userId != nil {
                hasAcceptedTerms = true
                onboarding.dismissWelcome()
                onboarding.markDemoTourCompleted()
                onboarding.markDisplayNamePromptShown()
                if !ProcessInfo.processInfo.arguments.contains("-UITestingIntroduction") {
                    onboarding.completeIntroduction()
                }
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
        .task(id: pushRegistrationContext) {
            guard pushRegistrationContext != nil else { return }
            await PushNotificationManager.shared.startAfterEnteringAuthenticatedMode()
        }
        .environment(onboarding)
        // Must sit on this ancestor of TabView. Modifiers on TabView itself
        // (and often on tabItem children) are not forwarded into tab pages.
        .environment(gettingStartedRouter)
        .environment(\.demoChromeExtendsIntoBottomSafeArea, false)
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

    /// Non-anonymous therapist session: Terms / Welcome / tab shell.
    @ViewBuilder
    private var therapistSessionRoot: some View {
        if !hasAcceptedTerms {
            NavigationStack {
                TermsView {
                    if let email = auth.currentUserEmail {
                        TermsAcceptance.setAccepted(email: email)
                    }
                    hasAcceptedTerms = true
                }
            }
        } else if onboarding.shouldShowIntroduction {
            AppIntroductionView(onTrySample: {
                store.enterDemoMode()
                onboarding.completeIntroduction()
            }, onContinue: {
                onboarding.completeIntroduction()
            })
        } else if showOptionalDisplayNamePrompt && !store.isDemoMode && entitlement.access == .full {
            // Full-screen gate (not a second root sheet) so this
            // never races Terms/Welcome or the password-recovery sheet.
            TherapistDisplayNameEditorView(
                requirement: .optional,
                onOptionalFinished: {
                    onboarding.markDisplayNamePromptShown()
                    showOptionalDisplayNamePrompt = false
                }
            )
        } else if isResolvingDisplayNameGate && !store.isDemoMode {
            Theme.base.ignoresSafeArea()
        } else {
            TherapistRootView()
        }
    }

    /// Anonymous sessions never use therapist AuthView. Context decides
    /// Patient Mode vs a recoverable incomplete/retry state.
    @ViewBuilder
    private var patientSessionRoot: some View {
        switch AppRootRouting.anonymousDestination(
            context: appContext.current,
            isLoading: appContext.isLoading
        ) {
        case .patientMode:
            PatientModeView()
        case .incomplete:
            PatientActivationIncompleteView {
                Task { await resolveAnonymousAppContext() }
            }
        case .loading:
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
        case .retry:
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

    /// Permission is requested only from the therapist tab shell
    /// or a successful Patient Mode activation — never on Auth, Terms,
    /// Welcome, invitation, or incomplete activation.
    private var pushRegistrationContext: String? {
        if AuthManager.isUITesting { return nil }
        switch AppRootRouting.destination(
            invitationActive: invitationFlow.isActive,
            hasSession: auth.hasSession,
            isAnonymous: auth.isAnonymous
        ) {
        case .therapist:
            let ready = hasAcceptedTerms
                && !onboarding.shouldShowIntroduction
                && !showOptionalDisplayNamePrompt
                && !isResolvingDisplayNameGate
                && !auth.isRecoveringPassword
            return ready ? auth.currentUserId.map { "therapist-\($0)" } : nil
        case .anonymousPatient:
            let active = AppRootRouting.anonymousDestination(
                context: appContext.current,
                isLoading: appContext.isLoading
            ) == .patientMode
            return active ? auth.currentUserId.map { "patient-\($0)" } : nil
        case .invitation, .unauthenticated:
            return nil
        }
    }

    private func resolveAnonymousAppContext() async {
        guard auth.hasSession, !AuthManager.isUITesting else {
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
        guard auth.isTherapistAuthenticated,
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
        .environment(AppVersionManager())
        .environment(auth)
        .environment(PatientStore(client: auth.client))
        .environment(TherapistProfileService(client: auth.client))
        .environment(AppContextService(client: auth.client))
        .environment(PatientInvitationFlow())
        .environment(DiaryOneStore(client: auth.client))
        .environment(DiaryTwoStore(client: auth.client))
        .environment(NotificationStore(client: auth.client))
        .environment(TherapistNotificationCoordinator.shared)
}
