import SwiftUI

/// Library tab. Intentionally empty until groups/content exist.
struct LibraryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            TherapistTabPlaceholder(
                title: L10n.libraryPlaceholderTitle,
                systemImage: "books.vertical",
                bodyText: L10n.libraryPlaceholderBody
            )
            .demoModeChrome()
            .navigationTitle(L10n.therapistTabLibrary)
            .navigationBarTitleDisplayMode(.large)
            .accessibilityIdentifier("library.root")
        }
    }
}

/// Shared empty-state chrome for Stage 1 therapist placeholder tabs.
struct TherapistTabPlaceholder: View {
    let title: String
    let systemImage: String
    let bodyText: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(bodyText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .patientAtmosphere(Theme.gold)
        .background(Theme.base.ignoresSafeArea())
    }
}
