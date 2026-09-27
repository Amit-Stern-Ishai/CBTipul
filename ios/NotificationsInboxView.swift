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
        List(notifications.notifications) { item in
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
                .at(notifications.notifications.firstIndex(where: { $0.id == item.id }) ?? 0,
                    of: notifications.notifications.count),
                accent: Theme.gold
            ))
            .listRowSeparatorTint(Theme.borderFaint)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .themedScreen()
    }

    private func open(_ item: AppNotification) async {
        await notifications.markRead(item)
        coordinator.handleInboxTap(item, patients: store.patients)
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
            if item.isUnread {
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
        switch item.type {
        case .questionnaireCompleted:
            L10n.notificationQuestionnaireCompleted
        case .questionnaireAssigned, .unknown:
            L10n.notificationGenericTitle
        }
    }
}
