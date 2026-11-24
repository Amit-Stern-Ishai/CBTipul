import SwiftUI

enum RevokePatientAccess {
    static let phrase = "הפסקת גישה"
    static let explanation = "הפסקת הגישה תמנע מהמטופל/ת גישה לתיק באפליקציה.\nהתיק והמידע שנשמר בו לא יימחקו."
    static func matches(_ value: String) -> Bool { value.trimmingCharacters(in: .whitespacesAndNewlines) == phrase }
    static func confirmed(_ value: String) -> Bool { value == "access_revoked" || value == "already_disconnected" }
}

private struct RevokePatientAccessConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    let revoke: () async throws -> Void
    @State private var input = ""
    @State private var busy = false
    @State private var failed = false

    func body(content: Content) -> some View {
        content
            .disabled(busy)
            .overlay { if busy { ProgressView().padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
            .interactiveDismissDisabled(busy)
            .alert(RevokePatientAccess.phrase, isPresented: $isPresented) {
                TextField(L10n.deleteCodePlaceholder, text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(RevokePatientAccess.phrase, role: .destructive) { submit() }
                    .disabled(busy || !RevokePatientAccess.matches(input))
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(RevokePatientAccess.explanation + "\n\nלהמשך יש להקליד את הביטוי:\n" + RevokePatientAccess.phrase)
            }
            .alert(RevokePatientAccess.phrase, isPresented: $failed) {
                Button("ניסיון נוסף") { submit() }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text("לא ניתן להשלים את הפסקת הגישה. אפשר לנסות שוב.")
            }
            .onChange(of: isPresented) { _, shown in
                if shown { input = ""; failed = false }
            }
    }

    private func submit() {
        guard !busy, RevokePatientAccess.matches(input) else { return }
        busy = true
        Task {
            do { try await revoke() }
            catch { failed = true }
            busy = false
        }
    }
}

extension View {
    func revokePatientAccessConfirmation(isPresented: Binding<Bool>, revoke: @escaping () async throws -> Void) -> some View {
        modifier(RevokePatientAccessConfirmation(isPresented: isPresented, revoke: revoke))
    }
}
