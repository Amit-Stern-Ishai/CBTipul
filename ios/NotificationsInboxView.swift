import SwiftUI

/// Notifications tab. Stage 1 is an empty placeholder with no local history.
struct NotificationsInboxView: View {
    var body: some View {
        NavigationStack {
            TherapistTabPlaceholder(
                title: L10n.notificationsPlaceholderTitle,
                systemImage: "bell",
                bodyText: L10n.notificationsPlaceholderBody
            )
            .demoModeChrome()
            .navigationTitle(L10n.therapistTabNotifications)
            .navigationBarTitleDisplayMode(.large)
            .accessibilityIdentifier("notifications.root")
        }
    }
}
