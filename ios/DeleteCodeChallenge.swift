import SwiftUI

/// Second layer of delete protection shown after the regular delete
/// confirmation: an alert displaying a randomly generated 8-character code
/// that the user must type back before `onConfirm` is called. A wrong code
/// shows an error and nothing is deleted.
private struct DeleteCodeChallenge: ViewModifier {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    @State private var code = ""
    @State private var input = ""
    @State private var isShowingMismatch = false

    func body(content: Content) -> some View {
        content
            .alert(L10n.deleteCodeTitle, isPresented: $isPresented) {
                TextField(L10n.deleteCodePlaceholder, text: $input)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button(L10n.deleteCodeConfirmAction, role: .destructive) {
                    if input.trimmingCharacters(in: .whitespaces).uppercased() == code {
                        onConfirm()
                    } else {
                        isShowingMismatch = true
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.deleteCodeMessage(code))
            }
            .alert(L10n.deleteCodeMismatchTitle, isPresented: $isShowingMismatch) {
                Button(L10n.ok, role: .cancel) {}
            } message: {
                Text(L10n.deleteCodeMismatchMessage)
            }
            .onChange(of: isPresented) { _, isShown in
                if isShown {
                    code = Self.randomCode()
                    input = ""
                }
            }
    }

    /// Uppercase letters and digits, skipping the easily confused
    /// 0/O and 1/I.
    private static func randomCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<8).compactMap { _ in characters.randomElement() })
    }
}

extension View {
    func deleteCodeChallenge(isPresented: Binding<Bool>,
                             onConfirm: @escaping () -> Void) -> some View {
        modifier(DeleteCodeChallenge(isPresented: isPresented, onConfirm: onConfirm))
    }
}
