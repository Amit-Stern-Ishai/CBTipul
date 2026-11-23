import SwiftUI
import Supabase

/// Thrown when the user declines (or never grants) AI data sharing while an
/// AI action is waiting on it. A deliberate cancellation, not a failure —
/// screens must cancel the action quietly instead of raising an error alert
/// (see `Error.userFacingMessage`).
nonisolated struct AIDataSharingConsentDeclinedError: Error {}

extension Error {
    /// Known transport failures retain their recovery guidance; unknown failures
    /// keep the screen's existing, context-specific copy.
    nonisolated func userFacingMessage(fallback: String) -> String? {
        if self is AIDataSharingConsentDeclinedError || self is CancellationError { return nil }
        let failure = ClientFailure.from(self)
        return failure == .unknown ? fallback : failure.localizedDescription
    }

    /// The message a screen should surface for a failed action, or `nil`
    /// when the failure is the user's own "not now" on the AI consent
    /// sheet, which must cancel silently.
    nonisolated var userFacingMessage: String? {
        if self is AIDataSharingConsentDeclinedError || self is CancellationError { return nil }
        let failure = ClientFailure.from(self)
        if failure != .unknown { return failure.localizedDescription }
        // Domain errors supply curated copy; never display raw transport bodies.
        if self is EntitlementDenied || self is AuthError || self is PatientStoreError || self is SummaryAllowanceError || self is NameSyncFailure { return localizedDescription }
        return ClientFailure.unknown.localizedDescription
    }
}

/// Server receipts only. Old device flags deliberately have no role in this notice.
@MainActor @Observable final class AIDataSharingConsentStore {
    static let shared = AIDataSharingConsentStore()
    static let version = "2026-11-22"
    typealias Call = (String, [String: AnyJSON]) async throws -> Data
    @ObservationIgnored private let callOverride: Call?
    @ObservationIgnored private let eligibleOverride: (() -> Bool)?
    @ObservationIgnored private let presentOverride: (() -> Void)?
    init(call: Call? = nil, eligible: (() -> Bool)? = nil, present: (() -> Void)? = nil) {
        callOverride = call; eligibleOverride = eligible; presentOverride = present
    }
    private(set) var hasAccepted = false
    private(set) var hasDeclined = false
    private(set) var busy = false
    private(set) var failed = false
    private(set) var programmingFailure = false
    @ObservationIgnored private var client: SupabaseClient?
    @ObservationIgnored private var account: String?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var receipt: AIConsentReceipt?
    @ObservationIgnored private var pending: AIConsentDecision?
    @ObservationIgnored private var bypassForDemo = false
    @ObservationIgnored private var pendingContinuations: [CheckedContinuation<Bool, Never>] = []
    @ObservationIgnored private weak var consentController: UIViewController?
    func configure(account: String?, client: SupabaseClient? = nil) {
        self.client = client
        guard self.account != account else { return }
        generation += 1; self.account = account; receipt = nil; pending = nil
        hasAccepted = false; hasDeclined = false; failed = false; busy = false; programmingFailure = false
        finish(false)
    }
    func setDemoBypass(_ enabled: Bool) { bypassForDemo = enabled; if enabled { finish(false) } }
    nonisolated static func ensureGranted() async throws {
        let epoch = await shared.generation
        let granted = await withTaskCancellationHandler {
            await shared.requireConsent()
        } onCancel: {
            Task { @MainActor in if shared.generation == epoch { shared.cancelPending() } }
        }
        guard granted else { throw AIDataSharingConsentDeclinedError() }
        try Task.checkCancellation()
    }
    private func check(_ owner: String, _ epoch: Int) throws {
        let eligible = eligibleOverride?() ?? (client?.auth.currentUser?.id.uuidString == owner && EntitlementState.shared.identity == owner && EntitlementState.shared.role == .therapist)
        guard account == owner, generation == epoch, eligible else { throw CancellationError() }
    }
    private func read(_ method: String, params: [String: AnyJSON], owner: String, epoch: Int) async throws -> AIConsentReceipt {
        try check(owner, epoch)
        let data: Data
        if let callOverride { data = try await callOverride(method, params) }
        else if let client { data = try await client.rpc(method, params: params).execute().data }
        else { throw CancellationError() }
        try check(owner, epoch)
        let value = try AIConsentReceipt.decode(data, account: owner)
        if let previous = receipt, value.revision < previous.revision || (value.revision == previous.revision && value.status != previous.status) { throw NameSyncFailure(code: "invalid_response") }
        receipt = value; hasAccepted = value.status == "accepted"
        return value
    }
    private func lookup(owner: String, epoch: Int) async throws -> AIConsentReceipt {
        try await read("get_my_consent", params: ["p_consent_type": .string("ai_data_sharing"), "p_required_version": .string(Self.version)], owner: owner, epoch: epoch)
    }
    func requireConsent() async -> Bool {
        guard !Task.isCancelled else { return false }
        if bypassForDemo { return true }
        guard let owner = account else { return false }
        let epoch = generation
        guard (try? check(owner, epoch)) != nil else { return false }
        do {
            try check(owner, epoch)
            if pending == nil, try await lookup(owner: owner, epoch: epoch).status == "accepted" { return true }
        } catch {
            guard generation == epoch, account == owner else { return false }
            hasAccepted = false; failed = true
        }
        let presenter = presentOverride == nil ? Self.topmostViewController() : nil
        guard presenter != nil || presentOverride != nil else { return false }
        return await withCheckedContinuation { continuation in
            pendingContinuations.append(continuation)
            if let presentOverride { presentOverride(); return }
            guard let presenter, consentController == nil else { return }
            let host = UIHostingController(rootView: AIDataSharingConsentView(store: self,
                onAccept: { Task { await self.accept() } }, onDecline: { self.decline() }))
            host.isModalInPresentation = true; consentController = host
            presenter.present(host, animated: true)
        }
    }
    func accept() async {
        guard !busy, !programmingFailure, let owner = account else { return }
        let epoch = generation
        busy = true; failed = false
        defer { if generation == epoch { busy = false } }
        do {
            try check(owner, epoch)
            if pending == nil {
                let current = try await lookup(owner: owner, epoch: epoch)
                pending = AIConsentDecision(revision: current.revision)
            }
            guard let args = pending else { return }
            let result = try await read("record_my_consent", params: args.params, owner: owner, epoch: epoch)
            guard result.status == "accepted", result.revision >= args.revision else { throw NameSyncFailure(code: "invalid_response") }
            pending = nil; hasDeclined = false; finish(true)
        } catch {
            guard generation == epoch, account == owner else { return }
            let code = NameSyncFailure.from(error).code
            if code == "consent_request_id_reused" { programmingFailure = true }
            if ["consent_revision_conflict", "consent_request_superseded", "consent_request_id_reused"].contains(code) {
                pending = nil; receipt = nil
                _ = try? await lookup(owner: owner, epoch: epoch)
            }
            hasAccepted = false; failed = true
        }
    }
    func cancelPending() { generation += 1; busy = false; finish(false) }
    func decline() { guard !busy else { return }; hasDeclined = true; finish(false) }
    private func finish(_ accepted: Bool) {
        consentController?.dismiss(animated: true); consentController = nil
        let waiting = pendingContinuations; pendingContinuations = []
        for continuation in waiting { continuation.resume(returning: accepted) }
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

struct AIDataSharingConsentView: View {
    var store: AIDataSharingConsentStore = .shared
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(L10n.aiConsentBody)
                    .font(BrandTypography.subheadline)
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
                    if store.failed { Text("לא ניתן לאשר את ההסכמה כרגע. אפשר לנסות שוב או להמשיך לעבוד ידנית.").foregroundStyle(Theme.error) }
                    Button {
                        onAccept()
                    } label: {
                        Text(store.busy ? "בודק…" : store.failed ? "ניסיון נוסף" : L10n.aiConsentAcceptAction)
                            .font(BrandTypography.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pressableProminent)
                    .disabled(store.busy || store.programmingFailure)
                    Button {
                        onDecline()
                    } label: {
                        Text(L10n.aiConsentDeclineAction)
                            .font(BrandTypography.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(store.busy)
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
