import SwiftUI
import Supabase

enum EmailInvitationShare {
    static let text = "הוזמנת להשתמש ב־CBTipul. פתחו את האפליקציה והירשמו או התחברו עם כתובת המייל שמסרתם למטפל/ת.\n\nhttps://cbtipul.com/"
}

struct PendingEmailInvitation {
    private(set) var status: String?
    private(set) var editing = true
    var canCorrect: Bool { status == "pending" || status == "waiting_for_sign_in" || status == "waiting_for_confirmation" }
    var canShare: Bool { canCorrect && !editing }
    mutating func receive(_ status: String) {
        guard ["pending", "waiting_for_sign_in", "waiting_for_confirmation", "already_connected"].contains(status) else { return }
        self.status = status; editing = false
    }
    mutating func load(_ status: String) throws {
        switch status {
        case "pending": receive("pending")
        case "connected": receive("already_connected")
        case "no_invitation": self.status = nil; editing = true
        default: throw AuthError.verificationFailed
        }
    }
    mutating func correct() { guard canCorrect else { return }; editing = true }
}

struct EmailInvitationView: View {
    let patientID: String
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var confirmedEmail: String?
    @State private var saving = false
    @State private var sharing = false
    @State private var loading = true
    @State private var statusFailed = false
    @State private var message: String?
    @State private var pending = PendingEmailInvitation()
    struct Request: Encodable { let patient_id: String; let email: String }
    private struct Response: Decodable { let status: String }
    var body: some View {
        NavigationStack {
            Form {
                if loading { ProgressView() }
                else if statusFailed {
                    Text("לא ניתן לבדוק את מצב ההזמנה.")
                    Button(L10n.retry) { Task { await loadStatus() } }
                }
                if !loading && !statusFailed {
                if let status = pending.status, let label = Self.result(status) {
                    Text(label).accessibilityAddTraits(.updatesFrequently)
                    if pending.canCorrect, let confirmedEmail {
                        Text("כתובת המייל להזמנה")
                        Text(confirmedEmail).textSelection(.enabled).environment(\.layoutDirection, .leftToRight)
                    }
                }
                if pending.canShare && !saving {
                    Button { sharing = true } label: {
                        Label("שיתוף הזמנה", systemImage: "square.and.arrow.up")
                    }
                }
                if pending.canCorrect && !pending.editing {
                    Button(L10n.emailInvitationCorrect) { email = ""; message = nil; pending.correct() }
                }
                if pending.editing {
                TextField(L10n.emailInvitationEmail, text: $email)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    .autocorrectionDisabled().disabled(saving)
                    .onChange(of: email) { _, _ in message = nil }
                if let message { Text(message).accessibilityAddTraits(.updatesFrequently) }
                Button(saving ? L10n.emailInvitationSaving : L10n.emailInvitationInvite) {
                    guard !saving else { return }
                    saving = true; message = nil
                    let owner = auth.currentUserId
                    let entered = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { @MainActor in
                        defer { saving = false }
                        do {
                            guard owner == auth.currentUserId, auth.isTherapistAuthenticated else { throw AuthError.verificationFailed }
                            let response: Response = try await auth.client.functions.invoke("save-patient-email-invitation",
                                options: .init(body: Request(patient_id: patientID, email: entered)))
                            guard owner == auth.currentUserId else { return }
                            pending.receive(response.status)
                            if ["waiting_for_sign_in", "waiting_for_confirmation"].contains(response.status) { confirmedEmail = entered }
                            else if response.status == "already_connected" { confirmedEmail = nil }
                            message = pending.editing ? Self.result(response.status) ?? L10n.emailInvitationFailed : nil
                        } catch {
                            guard owner == auth.currentUserId else { return }
                            message = Self.failure(error)
                        }
                    }
                }.disabled(saving || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            }
            .navigationTitle(L10n.emailInvitationInvite)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.cancel) { dismiss() }.disabled(saving) } }
            .interactiveDismissDisabled(saving)
        }
        .sheet(isPresented: $sharing) { ActivityShareSheet(items: [EmailInvitationShare.text]) }
        .task(id: patientID) { await loadStatus() }
        .environment(\.layoutDirection, .rightToLeft)
        .onChange(of: auth.currentUserId) { _, _ in dismiss() }
    }
    @MainActor private func loadStatus() async {
        let owner = auth.currentUserId
        loading = true; statusFailed = false
        defer { if owner == auth.currentUserId { loading = false } }
        do {
            struct Parameters: Encodable { let p_patient_id: String }
            let status: String = try await auth.client.rpc("get_patient_email_invitation_status",
                params: Parameters(p_patient_id: patientID)).execute().value
            guard owner != nil, owner == auth.currentUserId, !Task.isCancelled else { return }
            try pending.load(status)
            confirmedEmail = nil
        } catch {
            guard owner == auth.currentUserId, !Task.isCancelled else { return }
            statusFailed = true
        }
    }
    static func failure(_ error: Error) -> String {
        guard case let FunctionsError.httpError(status, data) = error,
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "לא ניתן לוודא שההזמנה נשמרה. אפשר לנסות שוב."
        }
        let code = body["error"] as? String ?? (body["error"] as? [String: Any])?["code"] as? String
            ?? body["code"] as? String ?? body["status"] as? String
        if status == 409 && code == "patient_profile_already_connected" { return L10n.emailInvitationProfileConnected }
        if code == "email_unavailable" { return L10n.emailInvitationUnavailable }
        return L10n.emailInvitationFailed
    }
    static func result(_ status: String) -> String? {
        switch status {
        case "pending": "הזמנה ממתינה"
        case "waiting_for_sign_in": L10n.emailInvitationWaitingSignIn
        case "waiting_for_confirmation": L10n.emailInvitationWaitingConfirmation
        case "already_connected": L10n.emailInvitationConnected
        case "email_unavailable": L10n.emailInvitationUnavailable
        default: nil
        }
    }
}
