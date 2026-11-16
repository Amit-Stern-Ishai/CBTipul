import SwiftUI

enum DeletionPhrase: String, CaseIterable {
    case patient = "מחיקת מטופל"
    case account = "מחיקת חשבון"
    case session = "מחיקת פגישה"
    case questionnaire = "מחיקת שאלוני מצב הרוח"
    func matches(_ input: String) -> Bool { input.trimmingCharacters(in: .whitespacesAndNewlines) == rawValue }
}

private struct DeleteCodeChallenge: ViewModifier {
    @Binding var isPresented: Bool
    let phrase: DeletionPhrase
    let onConfirm: () -> Void

    @State private var input = ""
    @State private var isShowingMismatch = false

    func body(content: Content) -> some View {
        content
            .alert(L10n.deleteCodeTitle, isPresented: $isPresented) {
                TextField(L10n.deleteCodePlaceholder, text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(L10n.deleteCodeConfirmAction, role: .destructive) {
                    if phrase.matches(input) {
                        onConfirm()
                    } else {
                        isShowingMismatch = true
                    }
                }
                .disabled(!phrase.matches(input))
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.deleteCodeMessage(phrase.rawValue))
            }
            .alert(L10n.deleteCodeMismatchTitle, isPresented: $isShowingMismatch) {
                Button(L10n.ok, role: .cancel) {}
            } message: {
                Text(L10n.deleteCodeMismatchMessage)
            }
            .onChange(of: isPresented) { _, isShown in
                if isShown {
                    input = ""
                }
            }
    }


}

extension View {
    func deleteCodeChallenge(phrase: DeletionPhrase, isPresented: Binding<Bool>,
                             onConfirm: @escaping () -> Void) -> some View {
        modifier(DeleteCodeChallenge(isPresented: isPresented, phrase: phrase, onConfirm: onConfirm))
    }
}
