import SwiftUI

/// Consent screen before entering local demo mode for the tutorial.
struct WelcomeOnboardingView: View {
    var onStartDemoTour: () -> Void
    var onSkip: () -> Void
    /// When false, only Continue / info are shown.
    var allowsSkip: Bool = true

    @State private var isShowingInfo = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.welcomeTitle)
                        .font(.title.bold())
                        .foregroundStyle(Theme.textBright)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(L10n.welcomeBody)
                        .font(.body)
                        .foregroundStyle(Theme.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 32)

                VStack(spacing: 12) {
                    Button(action: onStartDemoTour) {
                        Text(L10n.welcomePrimaryAction)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.pressableProminent)
                    .accessibilityIdentifier("welcome.continueDemo")

                    if allowsSkip {
                        Button(action: onSkip) {
                            Text(L10n.welcomeSecondaryAction)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.textBody)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        isShowingInfo = true
                    } label: {
                        Text(L10n.welcomeInfoLink)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.gold)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.base.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingInfo) {
                WelcomeInfoSheet()
                    .presentationDetents([.medium])
                    .appTextSize()
            }
        }
    }
}

/// Short explanation of how patient names and other data are stored.
private struct WelcomeInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var privacyURL: URL {
        URL(string: "https://cbtipul.com/privacy")!
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.welcomeInfoBody)
                    .font(.body)
                    .foregroundStyle(Theme.textBright)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    openURL(privacyURL)
                } label: {
                    Text(L10n.privacyPolicyTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.base.ignoresSafeArea())
            .navigationTitle(L10n.welcomeInfoLink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.welcomeInfoDoneAction) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    WelcomeOnboardingView(onStartDemoTour: {}, onSkip: {})
        .appTextSize()
}
