import SwiftUI

/// Therapist home after auth/terms/welcome gates: five persistent tabs.
enum TherapistRootTab: Hashable {
    case patients
    case sessions
    case notifications
    case library
    case settings
}

struct TherapistRootView: View {
    @Environment(PatientStore.self) private var store
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(GettingStartedRouter.self) private var gettingStartedRouter

    @State private var selectedTab: TherapistRootTab = .patients
    @State private var isShowingWelcome = false

    var body: some View {
        // GettingStartedRouter is installed on ContentView, an ancestor of
        // this TabView. Applying it on TabView / tabItem is dropped by SwiftUI.
        TabView(selection: $selectedTab) {
            PatientListView()
                .tabItem {
                    Label(L10n.therapistTabPatients, systemImage: "person.2.fill")
                }
                .tag(TherapistRootTab.patients)
                .accessibilityIdentifier("therapist.tab.patients")

            GlobalSessionsView()
                .tabItem {
                    Label(L10n.therapistTabSessions, systemImage: "calendar")
                }
                .tag(TherapistRootTab.sessions)
                .accessibilityIdentifier("therapist.tab.sessions")

            NotificationsInboxView()
                .tabItem {
                    Label(L10n.therapistTabNotifications, systemImage: "bell.fill")
                }
                .tag(TherapistRootTab.notifications)
                .accessibilityIdentifier("therapist.tab.notifications")

            LibraryPlaceholderView()
                .tabItem {
                    Label(L10n.therapistTabLibrary, systemImage: "books.vertical.fill")
                }
                .tag(TherapistRootTab.library)
                .accessibilityIdentifier("therapist.tab.library")

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(L10n.therapistTabSettings, systemImage: "gearshape.fill")
            }
            .tag(TherapistRootTab.settings)
            .accessibilityIdentifier("therapist.tab.settings")
        }
        .tint(Theme.gold)
        .toolbarBackground(.visible, for: .tabBar)
        .accessibilityIdentifier("therapist.root")
        .onChange(of: onboarding.wantsDemoConsent) { _, wants in
            guard wants else { return }
            onboarding.clearDemoConsentRequest()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedTab = .patients
                isShowingWelcome = true
            }
        }
        .onChange(of: store.isDemoMode) { _, isDemo in
            guard isDemo else { return }
            selectedTab = .patients
            gettingStartedRouter.setPlacement(.patientList)
            gettingStartedRouter.refresh(using: store)
        }
        .fullScreenCover(isPresented: $isShowingWelcome) {
            WelcomeOnboardingView(
                onStartDemoTour: {
                    startDemoTour()
                },
                onSkip: {
                    onboarding.dismissWelcome()
                    isShowingWelcome = false
                }
            )
            .appTextSize()
        }
        .showcaseIntroHost()
    }

    private func startDemoTour() {
        var settle = Transaction()
        settle.disablesAnimations = true
        withTransaction(settle) {
            onboarding.markDemoTourCompleted()
            onboarding.dismissWelcome()
            onboarding.showChecklistAgain()
            store.enterDemoMode()
            selectedTab = .patients
            gettingStartedRouter.setPlacement(.patientList)
            gettingStartedRouter.refresh(using: store)
            gettingStartedRouter.resetShowcaseReveal()
        }
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                var dismissTx = Transaction()
                dismissTx.disablesAnimations = true
                withTransaction(dismissTx) {
                    isShowingWelcome = false
                    gettingStartedRouter.syncHighlight()
                }
            }
        }
    }
}
