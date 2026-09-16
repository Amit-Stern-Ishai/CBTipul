import SwiftUI

/// Shown after the countdown (or “skip to sample data”) — invites exploration.
struct DemoShowcaseIntroView: View {
    var onExplore: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Label(L10n.showcaseRevealTitle, systemImage: "sparkles")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textBright)
                    .labelStyle(.titleAndIcon)

                Text(L10n.showcaseRevealBody)
                    .font(.body)
                    .foregroundStyle(Theme.textBody)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Image(systemName: "flask.fill")
                        .foregroundStyle(Theme.warning)
                    Text(L10n.showcaseRevealExitHint)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textBody)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                Spacer(minLength: 0)

                Button(action: onExplore) {
                    Text(L10n.showcaseRevealAction)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.pressableProminent)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.base.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview("Intro") {
    DemoShowcaseIntroView(onExplore: {})
        .appTextSize()
}
