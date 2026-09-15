import SwiftUI

/// Persistent chrome shown while local demo mode is active.
///
/// Full-width strip placed flush under the navigation bar; in demo mode the
/// title is forced inline so the banner sits above list content (e.g.
/// “Patients”), not under a large title.
struct DemoModeBanner: View {
    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var borderPulse = false

    var body: some View {
        if store.isDemoMode {
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

private struct DemoModeChromeLayout<Content: View>: View {
    @Environment(PatientStore.self) private var store
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            DemoModeBanner()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Theme.base.ignoresSafeArea())
        // Inline title while demo is on so the yellow strip sits directly
        // under the bar and above list titles like “Patients”.
        .navigationBarTitleDisplayMode(store.isDemoMode ? .inline : .automatic)
        // Inline mode otherwise falls back to the system (often white) bar;
        // keep it on Theme.base like the rest of the app.
        .toolbarBackground(Theme.base, for: .navigationBar)
        .toolbarBackground(store.isDemoMode ? .visible : .automatic, for: .navigationBar)
    }
}

extension View {
    /// Nav bar, then full-width demo banner, then the screen content.
    func demoModeChrome() -> some View {
        DemoModeChromeLayout { self }
    }
}
