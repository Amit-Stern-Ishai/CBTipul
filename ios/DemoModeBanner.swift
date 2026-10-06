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

private struct DemoModeReminder: ViewModifier {
    @Environment(PatientStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var nextReminder = Date().addingTimeInterval(180)
    @State private var presentedReminder: UIAlertController?

    func body(content: Content) -> some View {
        content
            .onChange(of: store.isDemoMode) { _, _ in
                nextReminder = Date().addingTimeInterval(180)
                presentedReminder?.dismiss(animated: false)
                presentedReminder = nil
            }
            .task(id: store.isDemoMode && scenePhase == .active) {
                guard store.isDemoMode, scenePhase == .active else { return }
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    guard Date() >= nextReminder, presentedReminder == nil else { continue }
                    presentReminder()
                }
            }
    }

    @MainActor
    private func presentReminder() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              var top = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        // Do not interrupt another confirmation or a presentation transition.
        guard !(top is UIAlertController), !top.isBeingDismissed, !top.isBeingPresented else { return }
        let alert = UIAlertController(title: L10n.demoReminderTitle,
                                      message: L10n.demoReminderBody, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.demoReminderContinue, style: .cancel) { _ in
            nextReminder = Date().addingTimeInterval(180)
            presentedReminder = nil
        })
        alert.addAction(UIAlertAction(title: L10n.demoModeExitShort, style: .default) { _ in
            nextReminder = Date().addingTimeInterval(180)
            presentedReminder = nil
            scene.windows.first(where: \.isKeyWindow)?.rootViewController?.dismiss(animated: false)
            Task { await store.exitDemoMode() }
        })
        presentedReminder = alert
        top.present(alert, animated: true)
    }
}

extension View {
    func demoModeReminder() -> some View { modifier(DemoModeReminder()) }
}
