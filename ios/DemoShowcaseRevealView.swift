import SwiftUI

/// Floating countdown chip — visible but does not dim or block the screen.
struct ShowcaseCountdownOverlay: View {
    let secondsLeft: Int

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                Text(L10n.showcaseCountdownTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textOnAccent)
                    .multilineTextAlignment(.leading)
                Text("\(secondsLeft)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textOnAccent)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.25), value: secondsLeft)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Theme.gold, Theme.warning],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .shadow(color: Theme.warning.opacity(0.35), radius: 12, y: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }
}

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

#Preview("Countdown") {
    ShowcaseCountdownOverlay(secondsLeft: 3)
}

#Preview("Intro") {
    DemoShowcaseIntroView(onExplore: {})
        .appTextSize()
}
