import SwiftUI

/// Therapist Notification Center: persisted events, newest first.
struct NotificationsInboxView: View {
    @Environment(PatientStore.self) private var store
    @Environment(NotificationStore.self) private var notifications
    @Environment(TherapistNotificationCoordinator.self) private var coordinator
    @Environment(\.scenePhase) private var scenePhase

    @State private var openedTarget: PendingPatientNavigation?

    var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack {
            Group {
                if notifications.isLoading && notifications.notifications.isEmpty {
                    ProgressView()
                } else if notifications.didFailLastLoad && notifications.notifications.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.notificationsLoadFailedTitle, systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button(L10n.retry) {
                            Task { await notifications.refresh() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if notifications.notifications.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.notificationsEmptyTitle, systemImage: "bell.badge")
                    } description: {
                        Text(store.isDemoMode ? L10n.notificationsDemoBody : L10n.notificationsEmptyBody)
                    }
                } else {
                    inboxList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .patientAtmosphere(Theme.gold)
            .background(Theme.base.ignoresSafeArea())
            .subtleAnimation(value: notifications.isLoading)
            .subtleAnimation(value: notifications.didFailLastLoad)
            .demoModeChrome()
            .navigationTitle(L10n.therapistTabNotifications)
            .navigationBarTitleDisplayMode(.large)
            .accessibilityIdentifier("notifications.root")
            .navigationDestination(item: $openedTarget) { target in
                NotificationItemDestination(target: target)
            }
            .onChange(of: openedTarget) { _, target in coordinator.isInboxShowingDetail = target != nil }
            .onChange(of: coordinator.pendingPatientNavigation?.token) { _, _ in consumeTarget() }
            .onAppear { consumeTarget() }
            .alert(L10n.notificationTargetUnavailable, isPresented: $coordinator.unavailableTarget) {
                Button(L10n.ok, role: .cancel) {}
            }
            .task {
                #if DEBUG
                if AuthManager.isUITesting, store.isDemoMode,
                   ProcessInfo.processInfo.arguments.contains("-UITestingNotifications"),
                   notifications.notifications.isEmpty,
                   let patient = store.patients.first(where: { !$0.sessions.isEmpty }) {
                    _ = try? await store.loadQuestionnaires(for: patient)
                    notifications.seedUITestingNotifications(
                        patientID: patient.id.queryValue,
                        questionnaireID: store.prepareUITestingQuestionnaireNotification(for: patient)?.queryValue
                    )
                }
                #endif
                if store.isDemoMode { return }
                await notifications.refresh()
            }
            .refreshable {
                if store.isDemoMode { return }
                await notifications.refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, !store.isDemoMode else { return }
                Task { await notifications.refresh() }
            }
        }
    }

    private func consumeTarget() {
        guard coordinator.selectedTab == .notifications,
              let target = coordinator.consumePatientNavigation() else { return }
        coordinator.isInboxShowingDetail = true
        openedTarget = target
    }

    private var inboxList: some View {
        let unread = NotificationInboxSections.unread(notifications.notifications)
        let read = NotificationInboxSections.read(notifications.notifications)
        return List {
            if notifications.didFailLastLoad {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.notificationsRefreshFailed).font(.subheadline)
                        Button(L10n.retry) { Task { await notifications.refresh() } }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            if !unread.isEmpty {
                Section {
                    inboxRows(unread)
                } header: {
                    sectionHeader(L10n.notificationsUnreadSection, count: unread.count, highlighted: true)
                }
            }
            if !read.isEmpty {
                Section {
                    inboxRows(read)
                } header: {
                    sectionHeader(L10n.notificationsReadSection, count: read.count, highlighted: false)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .themedScreen()
    }

    @ViewBuilder
    private func inboxRows(_ items: [AppNotification]) -> some View {
        ForEach(items) { item in
            Button {
                Task { await open(item) }
            } label: {
                NotificationInboxRow(
                    item: item,
                    patientName: NotificationPatientName.resolve(
                        patientId: item.patientId,
                        patients: store.patients
                    )
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func sectionHeader(_ title: String, count: Int, highlighted: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(count, format: .number)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(highlighted ? Theme.goldGhost : Theme.surface, in: Capsule())
        }
        .foregroundStyle(highlighted ? Theme.gold : Theme.textBody)
        .textCase(nil)
        .padding(.vertical, 4)
    }

    private func open(_ item: AppNotification) async {
        coordinator.handleInboxTap(item, patients: store.patients)
        await notifications.markRead(item)
    }
}

private struct NotificationInboxRow: View {
    let item: AppNotification
    let patientName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(eventColor)
                .frame(width: 42, height: 42)
                .background(eventColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(patientName)
                        .font(.headline)
                        .foregroundStyle(Theme.textBright)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if item.isUnread {
                        Circle().fill(Theme.gold).frame(width: 7, height: 7)
                            .accessibilityLabel(L10n.notificationUnreadAccessibility)
                    }
                }
                Text(NotificationInboxCopy.message(for: item.type))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textBody)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        timestamp
                        Spacer(minLength: 8)
                        destinationLabel
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        timestamp
                        destinationLabel
                    }
                }
                .padding(.top, 3)
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(item.isUnread ? Theme.gold.opacity(0.4) : Theme.borderFaint, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private var timestamp: some View {
        Text(L10n.notificationTimestamp(item.createdAt))
            .font(.caption).foregroundStyle(Theme.textFaint)
            .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder private var destinationLabel: some View {
        if let actionTitle {
            HStack(spacing: 4) {
                Text(actionTitle)
                Image(systemName: "chevron.forward").font(.system(size: 9, weight: .semibold))
            }
            .font(.caption.weight(.semibold)).foregroundStyle(Theme.gold)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var actionTitle: String? {
        switch NotificationRouter.destination(from: item) {
        case .completedQuestionnaire: L10n.notificationOpenQuestionnaires
        case .diaryOneEntry, .diaryTwoEntry, .diaryThreeEntry: L10n.notificationOpenDiary
        case .patientDetail: L10n.notificationOpenPatient
        case .none: nil
        }
    }

    private var symbol: String {
        switch item.type {
        case .questionnaireCompleted: "checklist"
        case .patientConnected: "person.crop.circle.badge.checkmark"
        case .diaryOneEntryAdded, .diaryTwoEntryAdded, .diaryThreeEntryAdded: "book.closed"
        default: "bell"
        }
    }

    private var eventColor: Color {
        switch item.type {
        case .patientConnected: Theme.success
        case .diaryOneEntryAdded, .diaryTwoEntryAdded, .diaryThreeEntryAdded: Theme.accentFill
        default: Theme.gold
        }
    }
}

/// A notification opens exactly one destination above the inbox, with its own load state.
private struct NotificationItemDestination: View {
    let target: PendingPatientNavigation
    @Environment(PatientStore.self) private var store
    @Environment(DiaryOneStore.self) private var one
    @Environment(DiaryTwoStore.self) private var two
    @Environment(DiaryThreeStore.self) private var three
    @State private var loading = true
    @State private var failed = false
    @State private var found = false

    var body: some View {
        Group {
            if let patient = store.patients.first(where: { $0.id == target.patientID }) {
                if let route = target.questionnairesRoute {
                    if let id = route.focusQuestionnaireID {
                        NotificationQuestionnaireView(patient: patient, questionnaireID: id)
                    } else { PatientQuestionnairesView(patient: patient) }
                } else if let route = target.diaryOneRoute {
                    if let id = route.focusEntryID {
                        if found, let entry = one.entries(for: patient.id).first(where: { $0.id == id }) {
                            DiaryOneEntryFormView(patient: patient, mode: .edit(entry))
                        } else { loadState }
                    } else { PatientDiaryOneView(patient: patient) }
                } else if let route = target.diaryTwoRoute {
                    if let id = route.focusEntryID {
                        if found { DiaryTwoEntryDetailView(patient: patient, entryID: id) }
                        else { loadState }
                    } else { PatientDiaryTwoView(patient: patient) }
                } else if let route = target.diaryThreeRoute {
                    if let id = route.focusEntryID {
                        if found { DiaryThreeEntryDetailView(patient: patient, entryID: id) }
                        else { loadState }
                    } else { PatientDiaryThreeView(patient: patient) }
                } else { PatientDetailView(patient: patient) }
            } else {
                ContentUnavailableView { Label(L10n.notificationTargetUnavailable, systemImage: "questionmark.circle") }
            }
        }
        .themedScreen()
        .task(id: target.token) { await loadEntry() }
    }

    @ViewBuilder private var loadState: some View {
        if loading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        else {
            ContentUnavailableView {
                Label(failed ? L10n.notificationsLoadFailedTitle : L10n.notificationTargetUnavailable, systemImage: "book.closed")
            } actions: {
                if failed { Button(L10n.retry) { Task { await loadEntry() } } }
            }
        }
    }

    private func loadEntry() async {
        loading = true; failed = false; found = false
        defer { loading = false }
        do {
            if let id = target.diaryOneRoute?.focusEntryID {
                found = try await one.loadEntry(id: id, patientId: target.patientID) != nil
            } else if let id = target.diaryTwoRoute?.focusEntryID {
                found = try await two.loadEntry(id: id, patientId: target.patientID) != nil
            } else if let id = target.diaryThreeRoute?.focusEntryID {
                found = try await three.loadEntry(id: id, patientId: target.patientID) != nil
            }
        } catch { failed = true }
    }
}
