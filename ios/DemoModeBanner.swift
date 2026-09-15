import SwiftUI

/// Persistent chrome shown while local demo mode is active.
///
/// Full-width yellow strip directly under the navigation bar.
struct DemoModeBanner: View {
    @Environment(PatientStore.self) private var store
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

/// Pins the demo banner under the nav bar. Does not wrap content in another
/// container — wrapping was fighting NavigationStack toolbar layout.
private struct DemoModeBannerInset: ViewModifier {
    @Environment(PatientStore.self) private var store

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if store.isDemoMode {
                    DemoModeBanner()
                        // Avoid the default insert transition that slides
                        // the whole screen downward when demo starts.
                        .transition(.identity)
                }
            }
            .animation(nil, value: store.isDemoMode)
    }
}

extension View {
    /// Demo banner under the nav bar only — does not restyle the toolbar.
    /// (Forcing a solid `Theme.base` bar made the nav look black vs before.)
    func demoModeChrome() -> some View {
        modifier(DemoModeBannerInset())
    }
}
