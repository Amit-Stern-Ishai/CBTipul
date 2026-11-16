#if DEBUG
import SwiftUI
import Supabase

func validatePatientDeletionReceipt(status: Int, data: Data) throws {
    struct Receipt: Decodable { let deleted: Bool }
    guard status == 200, try JSONDecoder().decode(Receipt.self, from: data).deleted else { throw AccountActionError.failed }
}

@Observable @MainActor
final class PatientAccountDeletion {
    enum State { case idle, confirming, deleting, rejected, uncertain, checking, retryable, sessionUnverified, cleanupFailed, deleted }
    private(set) var state: State = .idle
    private let identity: () -> String?
    private let owner: String?
    private let request: () async throws -> Void
    private let checkSession: () async throws -> Void
    private let cleanup: () async throws -> Void
    private var generation = 0
    var busy: Bool { state == .deleting || state == .checking }
    init(identity: @escaping () -> String?, request: @escaping () async throws -> Void,
         checkSession: @escaping () async throws -> Void, cleanup: @escaping () async throws -> Void) {
        self.identity = identity; owner = identity(); self.request = request; self.checkSession = checkSession; self.cleanup = cleanup
    }
    func ask() { guard !busy, state == .idle || state == .rejected || state == .retryable else { return }; state = .confirming }
    func cancel() { if state == .confirming { state = .idle } }
    func invalidate() { generation += 1; state = .idle }
    private func current(_ epoch: Int) -> Bool { epoch == generation && owner != nil && identity() == owner }
    func confirm() async {
        guard state == .confirming, current(generation) else { return }
        let epoch = generation; state = .deleting
        do { try await request() }
        catch {
            guard current(epoch) else { return }
            if case let FunctionsError.httpError(status, _) = error, (400..<500).contains(status) {
                state = status == 401 ? .sessionUnverified : .rejected
            } else { state = .uncertain }
            return
        }
        guard current(epoch) else { return }
        await finish(epoch)
    }
    private func finish(_ epoch: Int) async {
        do { try await cleanup(); if epoch == generation { state = .deleted } }
        catch { if current(epoch) { state = .cleanupFailed } }
    }
    func retryCleanup() async { guard state == .cleanupFailed, current(generation) else { return }; state = .deleting; await finish(generation) }
    func recheck() async {
        guard state == .uncertain || state == .sessionUnverified, current(generation) else { return }
        let epoch = generation; state = .checking
        do { try await checkSession(); if current(epoch) { state = .retryable } }
        catch { if current(epoch) { state = .sessionUnverified } }
    }
}

struct PatientDeleteAccountSection: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppContextService.self) private var context
    @State private var confirmationInput = ""
    @State private var deletion: PatientAccountDeletion?
    let busyChanged: (Bool) -> Void
    var body: some View {
        Section {
            Button("מחיקת חשבון", role: .destructive) { confirmationInput = ""; deletion?.ask() }
                .disabled(deletion == nil || deletion?.busy == true || (deletion?.state != .idle && deletion?.state != .rejected && deletion?.state != .retryable))
            if let deletion {
                if deletion.busy { ProgressView(deletion.state == .checking ? "בודק את מצב ההתחברות…" : "מוחק את החשבון…") }
                switch deletion.state {
                case .rejected: Text("הבקשה למחיקת החשבון נדחתה. אפשר לנסות שוב.")
                case .uncertain, .sessionUnverified:
                    Text("לא ניתן לאשר שהחשבון נמחק. יש לבדוק את מצב ההתחברות לפני ניסיון נוסף.")
                    Button("בדיקת מצב ההתחברות") { Task { await deletion.recheck() } }
                case .retryable: Text("ההתחברות אומתה. אפשר לנסות שוב למחוק את החשבון.")
                case .cleanupFailed:
                    Text("החשבון נמחק. לא ניתן להשלים את היציאה מהמכשיר.")
                    Button("השלמת היציאה") { Task { await deletion.retryCleanup() } }
                default: EmptyView()
                }
            }
        }
        .task {
            let owner = auth.currentUserId
            let epoch = auth.accountActions.identityGeneration
            deletion = PatientAccountDeletion(identity: { auth.accountActions.identityGeneration == epoch ? auth.currentUserId : nil }, request: {
                guard context.current?.role == .patient, auth.currentUserId == owner else { throw AccountActionError.identityChanged }
                try await auth.client.functions.invoke("delete-patient-account", options: .init(method: .post, body: [String: String]())) { data, response in
                    try validatePatientDeletionReceipt(status: response.statusCode, data: data)
                }
            }, checkSession: {
                let user = try await auth.client.auth.user()
                guard user.id.uuidString == owner else { throw AccountActionError.identityChanged }
            }, cleanup: {
                try await auth.finishConfirmedPatientDeletion(expectedUserID: owner)
                guard auth.currentUserId == nil else { throw AccountActionError.identityChanged }
                context.clear()
            })
        }
        .onChange(of: deletion?.busy) { _, busy in busyChanged(busy == true) }
        .onChange(of: auth.currentUserId) { _, _ in deletion?.invalidate() }
        .onDisappear { deletion?.invalidate(); busyChanged(false) }
        .alert("למחוק את החשבון?", isPresented: Binding(get: { deletion?.state == .confirming }, set: { _ in })) {
            TextField(L10n.deleteCodePlaceholder, text: $confirmationInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("מחיקת חשבון", role: .destructive) {
                guard DeletionPhrase.account.matches(confirmationInput) else { return }
                // The explicit cancel action owns cancellation; dismissal must not cancel this task.
                let action = deletion
                Task { await action?.confirm() }
            }
            .disabled(!DeletionPhrase.account.matches(confirmationInput))
            Button("ביטול", role: .cancel) { deletion?.cancel() }
        } message: {
            Text("זו מחיקת החשבון, ולא רק יציאה ממנו. פרטי ההתחברות והגישה שלכם לאפליקציה יימחקו. תיק המטופל/ת והרשומות הקליניות אצל המטפל/ת יישארו. לא ניתן לבטל את המחיקה.\n\nלהשלמת המחיקה יש להקליד את הביטוי:\nמחיקת חשבון")
        }
    }
}
#endif
