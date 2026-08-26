import SwiftUI

/// The privacy policy text, opened read-only from Settings.
struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(text: L10n.privacyPolicyBody)
            .navigationTitle(L10n.privacyPolicyTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
