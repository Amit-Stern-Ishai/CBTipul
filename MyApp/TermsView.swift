import SwiftUI

/// Local record of which accounts accepted the terms and conditions.
enum TermsAcceptance {
    private static func key(for email: String) -> String {
        "hasAcceptedTerms-\(email)"
    }

    static func hasAccepted(email: String) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: email))
    }

    static func setAccepted(email: String) {
        UserDefaults.standard.set(true, forKey: key(for: email))
    }
}

/// The terms and conditions text. Read-only when opened from Settings;
/// when `onAgree` is set it becomes a blocking acceptance screen with an
/// Agree button (shown after sign-up, before the app can be used).
struct TermsView: View {
    /// Set when acceptance is required; called when the user agrees.
    var onAgree: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            Text(L10n.termsBody)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Theme.base.ignoresSafeArea())
        .navigationTitle(L10n.termsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let onAgree {
                Button {
                    onAgree()
                } label: {
                    Text(L10n.termsAgreeAction)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pressableProminent)
                .padding()
                .background(Theme.surface)
            }
        }
    }
}

#Preview("Acceptance") {
    NavigationStack {
        TermsView(onAgree: {})
    }
}

#Preview("Read-only") {
    NavigationStack {
        TermsView()
    }
}
