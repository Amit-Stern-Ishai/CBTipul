import SwiftUI

/// Global Sessions tab. Stage 1 is an empty placeholder only.
struct GlobalSessionsView: View {
    var body: some View {
        NavigationStack {
            TherapistTabPlaceholder(
                title: L10n.globalSessionsPlaceholderTitle,
                systemImage: "calendar",
                bodyText: L10n.globalSessionsPlaceholderBody
            )
            .demoModeChrome()
            .navigationTitle(L10n.therapistTabSessions)
            .navigationBarTitleDisplayMode(.large)
            .accessibilityIdentifier("sessions.root")
        }
    }
}
