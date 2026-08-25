import SwiftUI

/// The privacy policy text, opened read-only from Settings.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text(L10n.privacyPolicyBody)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(L10n.privacyPolicyTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
