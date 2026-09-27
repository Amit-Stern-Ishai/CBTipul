import SwiftUI

/// Therapist Notification Center: persisted events, newest first.
struct NotificationsInboxView: View {
    @Environment(PatientStore.self) private var store
    @Environment(NotificationStore.self) private var notifications
    @Environment(TherapistNotificationCoordinator.self) private var coordinator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
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
                        Label(L10n.notificationsEmptyTitle, systemImage: "bell")
                    }
                } else {
                    inboxList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .patientAtmosphere(Theme.gold)
            .background(Theme.base.ignoresSafeArea())
            .demoModeChrome()
            .navigationTitle(L10n.therapistTabNotifications)
            .navigationBarTitleDisplayMode(.large)
            .accessibilityIdentifier("notifications.root")
            .task {
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

    private var inboxList: some View {
        let unread = NotificationInboxSections.unread(notifications.notifications)
        let read = NotificationInboxSections.read(notifications.notifications)
        return List {
            if !unread.isEmpty {
                Section(L10n.notificationsUnreadSection) {
                    inboxRows(unread)
                }
            }
            if !read.isEmpty {
                Section(L10n.notificationsReadSection) {
                    inboxRows(read)
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
            .listRowBackground(groupBorderedRow(
                .at(items.firstIndex(where: { $0.id == item.id }) ?? 0,
                    of: items.count),
                accent: Theme.gold
            ))
            .listRowSeparatorTint(Theme.borderFaint)
        }
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
            VStack(alignment: .leading, spacing: 3) {
                Text(patientName)
                    .font(item.isUnread ? .headline : .body)
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(L10n.notificationTimestamp(item.createdAt))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            if item.isUnseen {
                Circle()
                    .fill(Theme.gold)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                    .accessibilityLabel(L10n.notificationUnreadAccessibility)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var title: String {
        NotificationInboxCopy.message(for: item.type)
    }
}
