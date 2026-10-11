import AuthenticationServices
import SwiftUI

/// Lives above auth routing so registration warnings and deletion confirmation
/// survive dismissal of the login/settings screens that started the operation.
struct AccountActionNotices: View {
    @Environment(AuthManager.self) private var auth
    @State private var showingRetry = false
    @State private var retryError: String?

    var body: some View {
        VStack(spacing: 8) {
            if let userID = auth.accountActions.registrationWarningUserID,
               userID == auth.currentUserId, auth.isTherapistAuthenticated {
                Text(L10n.appleTokenWarning).font(.footnote)
                Button(L10n.appleTokenRetry) { retryError = nil; showingRetry = true }
                    .disabled(auth.accountActions.isRegistering || auth.isProviderSignInInProgress)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(auth.accountActions.registrationWarningUserID == nil ? 0 : 12)
        .background(Theme.surface)
        .sheet(isPresented: $showingRetry) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text(L10n.appleTokenRetryExplanation)
                    SignInWithAppleButton(.continue, onRequest: { request in
                        retryError = nil
                        do { try auth.prepareAppleTokenRetry(request) }
                        catch { retryError = L10n.appleSignInFailed }
                    }, onCompletion: { result in
                        // Unstructured task deliberately survives sheet/auth routing.
                        Task {
                            do {
                                try await auth.completeAppleSignIn(result)
                                if auth.accountActions.registrationWarningUserID == nil { showingRetry = false }
                            } catch { retryError = L10n.appleSignInFailed }
                        }
                    })
                    .signInWithAppleButtonStyle(.whiteOutline)
                    .environment(\.locale, Locale(identifier: "he"))
                    .frame(height: 48)
                    .disabled(auth.isProviderSignInInProgress || auth.accountActions.isRegistering)
                    if auth.accountActions.isRegistering { ProgressView() }
                    else if auth.accountActions.registrationWarningUserID != nil {
                        Text(L10n.appleTokenWarning).font(.footnote).foregroundStyle(Theme.error)
                    }
                    if let retryError { Text(retryError).foregroundStyle(Theme.error) }
                }
                .padding(24)
                .navigationTitle(L10n.appleTokenRetry)
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.closeAction) { showingRetry = false }
                        .disabled(auth.isProviderSignInInProgress || auth.accountActions.isRegistering)
                } }
            }
            .presentationDetents([.medium])
            .interactiveDismissDisabled(auth.isProviderSignInInProgress || auth.accountActions.isRegistering)
            .appTextSize()
        }
        .onChange(of: auth.currentUserId) { _, _ in showingRetry = false }
        .alert(L10n.accountDeletedTitle, isPresented: Binding(
            get: { auth.accountActions.deletionNotice != nil && !auth.hasSession },
            set: { if !$0 { auth.accountActions.deletionNotice = nil } }
        )) { Button(L10n.ok) { auth.accountActions.deletionNotice = nil } }
        message: { Text(auth.accountActions.deletionNotice ?? "") }
    }
}
