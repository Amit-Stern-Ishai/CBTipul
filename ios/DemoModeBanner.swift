import SwiftUI

/// Slim strip: “demo mode” + exit (stays under the nav bar).
struct DemoModeBanner: View {
    @Environment(PatientStore.self) private var store
    @Environment(GettingStartedRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var borderPulse = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "flask.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textOnAccent)
                .opacity(borderPulse ? 1 : 0.78)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.demoModeBannerTitle)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.textOnAccent)
                Text(L10n.demoModeBannerBody)
                    .font(.caption2)
                    .foregroundStyle(Theme.textOnAccent.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(L10n.demoModeExitShort) {
                Task {
                    router.resetShowcaseReveal()
                    await store.exitDemoMode()
                    dismiss()
                }
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(Theme.surface.opacity(0.92))
            .foregroundStyle(Theme.warning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Theme.warning
                .overlay { gentleShimmer }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("demo.banner")
        .accessibilityLabel(L10n.demoModeBannerTitle)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                borderPulse = true
            }
        }
    }

    /// Soft light band over the yellow field.
    private var gentleShimmer: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            GeometryReader { geo in
                let period = 4.2
                let raw = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: period) / period
                let travel = min(max(raw / 0.6, 0), 1)
                let eased = travel * travel * (3 - 2 * travel)
                let bandWidth = max(geo.size.width * 0.4, 64)

                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.34),
                        Color.white.opacity(0.22),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: bandWidth)
                .offset(x: -bandWidth + CGFloat(eased) * (geo.size.width + bandWidth))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Demo strip under the nav bar + walkthrough mission dock at the bottom.
private struct DemoModeBannerInset: ViewModifier {
    @Environment(PatientStore.self) private var store
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(GettingStartedRouter.self) private var router

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if store.isDemoMode {
                    DemoModeBanner()
                        .transaction { $0.animation = nil }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if store.isDemoMode, !onboarding.checklistDismissed {
                    TutorialCoachCard(
                        progress: router.progress,
                        placement: router.placement,
                        viewingPatientID: router.viewingPatientID,
                        showcaseLoaded: store.showcaseDataLoaded,
                        countdownEndsAt: router.showcaseCountdownEndsAt,
                        countdownDuration: GettingStartedRouter.showcaseCountdownDuration,
                        onRestart: { router.restart(using: store) },
                        onDismiss: { router.dismissCoach(using: onboarding) },
                        onSkipToShowcase: { router.skipToShowcaseData(using: store) }
                    )
                    .transaction { $0.animation = nil }
                }
            }
    }
}

/// Presents the post-tour showcase intro from a single host screen only.
/// (`demoModeChrome` is applied on every pushed screen — stacking covers
/// there caused the intro to flash off and on.)
private struct ShowcaseIntroHostModifier: ViewModifier {
    var isActive: Bool

    @Environment(PatientStore.self) private var store
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(GettingStartedRouter.self) private var router

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: introPresented) {
                DemoShowcaseIntroView {
                    router.finishShowcaseIntro(using: onboarding, store: store)
                }
                .appTextSize()
            }
    }

    private var introPresented: Binding<Bool> {
        Binding(
            get: {
                guard isActive else { return false }
                if case .intro = router.showcaseRevealPhase { return true }
                return false
            },
            set: { isPresented in
                if !isPresented {
                    router.finishShowcaseIntro(using: onboarding, store: store)
                }
            }
        )
    }
}

extension View {
    /// Demo strip (top) + walkthrough mission dock (bottom).
    func demoModeChrome() -> some View {
        modifier(DemoModeBannerInset())
    }

    /// Host the fake-data intro cover. Use once on the frontmost screen only.
    func showcaseIntroHost(isActive: Bool = true) -> some View {
        modifier(ShowcaseIntroHostModifier(isActive: isActive))
    }
}
