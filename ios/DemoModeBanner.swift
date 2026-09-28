import SwiftUI

private struct DemoChromeExtendsIntoBottomSafeAreaKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// When false, demo chrome must not paint under the therapist tab bar.
    var demoChromeExtendsIntoBottomSafeArea: Bool {
        get { self[DemoChromeExtendsIntoBottomSafeAreaKey.self] }
        set { self[DemoChromeExtendsIntoBottomSafeAreaKey.self] = newValue }
    }
}

/// Persistent, quiet indication that this is the separate sample clinic.
struct DemoModeBanner: View {
    @Environment(PatientStore.self) private var store
    @Environment(GettingStartedRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var isExiting = false

    var body: some View {
        HStack(spacing: 12) {
            Label(L10n.demoModeBannerTitle, systemImage: "person.2.crop.square.stack")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.gold)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(L10n.demoModeExitShort) {
                isExiting = true
                Task {
                    router.resetShowcaseReveal()
                    await store.exitDemoMode()
                    dismiss()
                }
            }
            .font(.footnote.weight(.semibold))
            .disabled(isExiting)
            .accessibilityIdentifier("demo.exit")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.elevated)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("demo.banner")
    }
}

private struct DemoModeBannerInset: ViewModifier {
    @Environment(PatientStore.self) private var store

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            if store.isDemoMode {
                DemoModeBanner()
                    .transaction { $0.animation = nil }
            }
        }
    }
}

extension View {
    /// Sample-data status and exit, without tutorial overlays.
    func demoModeChrome() -> some View {
        modifier(DemoModeBannerInset())
    }
}
