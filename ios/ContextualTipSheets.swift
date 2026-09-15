import SwiftUI

/// Compact non-blocking tip used for first-run contextual education.
struct ContextualTipSheet: View {
    let message: String
    var onContinue: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(message)
                    .font(.body)
                    .foregroundStyle(Theme.textBright)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: onContinue) {
                    Text(L10n.contextualTipContinueAction)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.pressableProminent)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.base.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// Shown when next-session preparation lacks enough clinical signal.
struct PreparationInsufficientSheet: View {
    let action: PreparationMissingAction
    var onAction: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.preparationInsufficientTitle)
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textBright)
                Text(L10n.preparationInsufficientBody)
                    .font(.body)
                    .foregroundStyle(Theme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: onAction) {
                    Text(action.buttonTitle)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.pressableProminent)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.base.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.welcomeInfoDoneAction) { dismiss() }
                }
            }
        }
    }
}
