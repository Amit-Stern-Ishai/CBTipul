import SwiftUI

/// Therapist home after auth/terms/welcome gates: five persistent tabs.
enum TherapistRootTab: Hashable {
    case patients
    case sessions
    case notifications
    case settings
}

struct TherapistRootView: View {
    @Environment(PatientStore.self) private var store
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(GettingStartedRouter.self) private var gettingStartedRouter
    @Environment(NotificationStore.self) private var notificationStore
    @Environment(TherapistNotificationCoordinator.self) private var coordinator
    @Environment(\.scenePhase) private var scenePhase

    @State private var isShowingWelcome = false

    var body: some View {
        @Bindable var coordinator = coordinator
        // GettingStartedRouter is installed on ContentView, an ancestor of
        // this TabView. Applying it on TabView / tabItem is dropped by SwiftUI.
        TabView(selection: $coordinator.selectedTab) {
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
                .badge(notificationStore.unseenCount)
                .accessibilityIdentifier("therapist.tab.notifications")

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
                coordinator.selectedTab = .patients
                isShowingWelcome = true
            }
        }
        .onChange(of: store.isDemoMode) { _, isDemo in
            guard isDemo else {
                notificationStore.isDemoInbox = false
                Task { await notificationStore.refresh() }
                return
            }
            notificationStore.isDemoInbox = true
            notificationStore.clear()
            coordinator.selectedTab = .patients
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
        .task {
            coordinator.markTherapistRootReady()
            store.loadCachedPatients()
            if store.isDemoMode {
                notificationStore.isDemoInbox = true
                notificationStore.clear()
            } else {
                notificationStore.isDemoInbox = false
                await notificationStore.refresh()
            }
            coordinator.processPending(patients: store.patients)
        }
        .onDisappear {
            coordinator.markTherapistRootNotReady()
        }
        .onChange(of: coordinator.pendingRevision) { _, _ in
            coordinator.processPending(patients: store.patients)
        }
        .task(id: coordinator.selectedTab) {
            guard NotificationInboxSeenPolicy.shouldMarkSeen(
                isInboxVisible: coordinator.selectedTab == .notifications,
                unseenCount: notificationStore.unseenCount
            ) else { return }
            await notificationStore.markInboxSeen()
        }
        .onChange(of: notificationStore.unseenCount) { _, count in
            guard NotificationInboxSeenPolicy.shouldMarkSeen(
                isInboxVisible: coordinator.selectedTab == .notifications,
                unseenCount: count
            ) else { return }
            Task { await notificationStore.markInboxSeen() }
        }
        .onChange(of: store.patients.map(\.id.queryValue).joined(separator: ",")) { _, _ in
            coordinator.processPending(patients: store.patients)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !store.isDemoMode else { return }
            Task {
                await notificationStore.refresh()
                coordinator.processPending(patients: store.patients)
            }
        }
    }

    private func startDemoTour() {
        var settle = Transaction()
        settle.disablesAnimations = true
        withTransaction(settle) {
            onboarding.markDemoTourCompleted()
            onboarding.dismissWelcome()
            onboarding.showChecklistAgain()
            store.enterDemoMode()
            coordinator.selectedTab = .patients
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
