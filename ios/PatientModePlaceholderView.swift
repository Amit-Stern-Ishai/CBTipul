import SwiftUI

/// Temporary Patient Mode shell. Questionnaires and tools come later.
struct PatientModePlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.appTitle)
                    .font(.title.bold())
                    .foregroundStyle(Theme.textBright)
                Text(L10n.patientModeConnectedTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.textBright)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.patientModeConnectedBody)
                    .font(.body)
                    .foregroundStyle(Theme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.base.ignoresSafeArea())
        .appTextSize()
    }
}

/// Anonymous patient whose invitation is not fully active yet.
struct PatientActivationIncompleteView: View {
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.patientActivationIncompleteTitle)
                    .font(.title.bold())
                    .foregroundStyle(Theme.textBright)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.patientActivationIncompleteBody)
                    .font(.body)
                    .foregroundStyle(Theme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 32)
            Button(action: onRetry) {
                Text(L10n.patientActivationRetryAction)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.pressableProminent)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.base.ignoresSafeArea())
        .appTextSize()
    }
}

struct PatientContextRetryView: View {
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.patientContextRetryTitle)
                    .font(.title.bold())
                    .foregroundStyle(Theme.textBright)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.patientContextRetryBody)
                    .font(.body)
                    .foregroundStyle(Theme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 32)
            Button(action: onRetry) {
                Text(L10n.patientActivationRetryAction)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.pressableProminent)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.base.ignoresSafeArea())
        .appTextSize()
    }
}
