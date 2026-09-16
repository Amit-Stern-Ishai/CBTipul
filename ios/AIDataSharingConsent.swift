import SwiftUI

/// Thrown when the user declines (or never grants) AI data sharing while an
/// AI action is waiting on it. A deliberate cancellation, not a failure —
/// screens must cancel the action quietly instead of raising an error alert
/// (see `Error.userFacingMessage`).
nonisolated struct AIDataSharingConsentDeclinedError: Error {}

extension Error {
    /// The message a screen should surface for a failed action, or `nil`
    /// when the failure is the user's own "not now" on the AI consent
    /// sheet, which must cancel silently.
    nonisolated var userFacingMessage: String? {
        self is AIDataSharingConsentDeclinedError ? nil : localizedDescription
    }
}

/// The one-time consent for sending user/clinical content to OpenAI
/// (App Review 5.1.1(i) / 5.1.2(i)).
///
/// The decision is stored locally only (UserDefaults) — never on the
/// backend — and per account (like `TermsAcceptance`), so one user's
/// acceptance never carries over to another who signs in on the same
/// device. Every service that would send content off the device awaits
/// `ensureGranted()` (or `requireConsent()`) before its network call, so no
/// request can leave the device without acceptance. Declining is also
/// remembered, but a later AI action asks again — it cannot run without
/// consent.
@MainActor
@Observable
final class AIDataSharingConsentStore {

    static let shared = AIDataSharingConsentStore()

    private static func acceptedKey(for email: String) -> String {
        "aiDataSharingConsentAccepted-\(email)"
    }
    private static func declinedKey(for email: String) -> String {
        "aiDataSharingConsentDeclined-\(email)"
    }

    private(set) var hasAccepted: Bool
    private(set) var hasDeclined: Bool

    /// The signed-in account the flags belong to; kept in sync by the app
    /// root observing `AuthManager.currentUserEmail`.
    @ObservationIgnored
    private var activeUserEmail: String?

    /// Callers waiting on the currently presented consent sheet; all resume
    /// with the single decision the user makes.
    @ObservationIgnored
    private var pendingContinuations: [CheckedContinuation<Bool, Never>] = []

    @ObservationIgnored
    private weak var consentController: UIViewController?

    /// Local demo clinic never prompts for AI data-sharing consent.
    @ObservationIgnored
    private var bypassForDemo = false

    private init() {
        // No decision until the signed-in account is known; the app root
        // calls `setActiveUser(email:)` as soon as (and whenever) the
        // authenticated user changes.
        hasAccepted = false
        hasDeclined = false
    }

    /// Switches the flags to the given account's stored decision. Signed
    /// out (`nil`) means no consent — AI actions can't run then anyway.
    func setActiveUser(email: String?) {
        activeUserEmail = email
        if let email {
            hasAccepted = UserDefaults.standard.bool(forKey: Self.acceptedKey(for: email))
            hasDeclined = UserDefaults.standard.bool(forKey: Self.declinedKey(for: email))
        } else {
            hasAccepted = false
            hasDeclined = false
        }
    }

    func setDemoBypass(_ enabled: Bool) {
        bypassForDemo = enabled
        if enabled {
            let waiting = pendingContinuations
            pendingContinuations = []
            for continuation in waiting {
                continuation.resume(returning: true)
            }
            consentController?.dismiss(animated: false)
            consentController = nil
        }
    }

    func accept() {
        hasAccepted = true
        hasDeclined = false
        persist()
    }

    func decline() {
        hasDeclined = true
        persist()
    }

    func reset() {
        hasAccepted = false
        hasDeclined = false
        persist()
    }

    private func persist() {
        guard let email = activeUserEmail else { return }
        UserDefaults.standard.set(hasAccepted, forKey: Self.acceptedKey(for: email))
        UserDefaults.standard.set(hasDeclined, forKey: Self.declinedKey(for: email))
    }

    /// Gate for the nonisolated service layer: awaited before any request
    /// that carries user content to OpenAI (directly or through an Edge
    /// Function). Throws `AIDataSharingConsentDeclinedError` on decline so
    /// the pending action aborts before anything leaves the device.
    nonisolated static func ensureGranted() async throws {
        guard await shared.requireConsent() else {
            throw AIDataSharingConsentDeclinedError()
        }
    }

    /// True once the user has accepted AI data sharing — immediately when
    /// consent was granted before, otherwise after presenting the consent
    /// sheet and waiting for the decision. Concurrent callers share one
    /// presentation and all receive the same answer.
    func requireConsent() async -> Bool {
        if bypassForDemo { return true }
        if hasAccepted { return true }
        guard let presenter = Self.topmostViewController() else { return false }
        return await withCheckedContinuation { continuation in
            pendingContinuations.append(continuation)
            presentConsentSheet(over: presenter)
        }
    }

    /// AI actions start inside nested sheets (session editor, questionnaire,
    /// chat), so the consent sheet is presented UIKit-side over whatever is
    /// topmost — a root SwiftUI sheet could not appear above them.
    private func presentConsentSheet(over presenter: UIViewController) {
        guard consentController == nil else { return }
        let host = UIHostingController(rootView: AIDataSharingConsentView(
            onAccept: { [weak self] in self?.finish(accepted: true) },
            onDecline: { [weak self] in self?.finish(accepted: false) }
        ))
        // The decision must come from one of the two buttons, never from a
        // swipe that would leave the waiting action undecided.
        host.isModalInPresentation = true
        consentController = host
        presenter.present(host, animated: true)
    }

    private func finish(accepted: Bool) {
        if accepted { accept() } else { decline() }
        consentController?.dismiss(animated: true)
        consentController = nil
        let waiting = pendingContinuations
        pendingContinuations = []
        for continuation in waiting {
            continuation.resume(returning: accepted)
        }
    }

    private static func topmostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let windows = scenes.first { $0.activationState == .foregroundActive }?.windows
            ?? scenes.first?.windows
            ?? []
        var top = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// The consent sheet itself: what is sent to OpenAI and why, with accept /
/// not-now actions. Presented by `AIDataSharingConsentStore` right before
/// the first action that would send content to OpenAI.
struct AIDataSharingConsentView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(L10n.aiConsentBody)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .themedCard()
                    .padding()
            }
            .background(Theme.base.ignoresSafeArea())
            .navigationTitle(L10n.aiConsentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button {
                        onAccept()
                    } label: {
                        Text(L10n.aiConsentAcceptAction)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pressableProminent)
                    Button {
                        onDecline()
                    } label: {
                        Text(L10n.aiConsentDeclineAction)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Theme.surface)
            }
        }
        // Presented UIKit-side, so the sheet doesn't inherit the app root's
        // environment overrides and must apply them itself.
        .appTextSize()
    }
}

#Preview {
    AIDataSharingConsentView(onAccept: {}, onDecline: {})
}
