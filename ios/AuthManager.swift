import SwiftUI
import OSLog
import Supabase

/// The third-party identity providers offered on the sign-in screen.
//enum AuthProvider: String {
//    case google = "Google"
//    case facebook = "Facebook"
//}

enum AuthError: LocalizedError {
    case notConfigured
    case notImplemented(String)
    case emailNotConfirmed
    case verificationFailed
    case tooManyRequests

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return L10n.supabaseNotConfiguredError
        case .notImplemented(let feature):
            return L10n.notImplementedError(feature)
        case .emailNotConfirmed:
            return L10n.emailNotConfirmedError
        case .verificationFailed:
            return L10n.verificationFailedError
        case .tooManyRequests:
            return L10n.tooManyRequestsError
        }
    }
}

/// Holds the current authentication state for the app, backed by Supabase Auth.
///
/// Email/password sign-up and sign-in are implemented. OAuth (Google/Facebook)
/// is still a stub and will be added later.
@Observable
@MainActor
final class AuthManager {
    /// The deep link Supabase redirects email-confirmation links to.
    static let authCallbackURL = URL(string: "cbtipul://auth-callback")!

    /// The deep link Supabase redirects password-recovery links to. A
    /// separate host so the app knows to ask for a new password.
    static let passwordResetCallbackURL = URL(string: "cbtipul://password-reset")!

    /// The shared Supabase client, also used for database access later.
    let client: SupabaseClient

    private(set) var currentUserEmail: String?

    /// Error from the last email-verification deep link, shown by the
    /// sign-in screen; cleared when a callback succeeds.
    private(set) var callbackError: String?

    /// True after a password-recovery link signed the user in; the root
    /// presents the new-password prompt until one is saved or it's skipped.
    var isRecoveringPassword = false

    var isAuthenticated: Bool { currentUserEmail != nil }

    init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )

        // Keep local state in sync with Supabase (session restore on launch,
        // sign-in, sign-out, token refresh).
        Task { [weak self] in
            guard let stream = self?.client.auth.authStateChanges else { return }
            for await (event, session) in stream {
                AppLog.auth.info("Auth state changed: \(event.rawValue, privacy: .public), signed in: \(session != nil)")
                self?.currentUserEmail = session?.user.email
            }
        }
    }

    /// Trims whitespace/newlines and lowercases, so the address matches the
    /// one Supabase stores regardless of how it was typed.
    private static func normalized(email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func signIn(email: String, password: String) async throws {
        try ensureConfigured()
        do {
            try await client.auth.signIn(email: Self.normalized(email: email), password: password)
            AppLog.auth.info("Sign-in succeeded")
        } catch {
            AppLog.auth.error("Sign-in failed: \(error.localizedDescription, privacy: .public)")
            // Unverified accounts get a clear Hebrew explanation instead of
            // the raw server error, mapped by error code.
            if let authError = error as? Auth.AuthError, authError.errorCode == .emailNotConfirmed {
                throw AuthError.emailNotConfirmed
            }
            throw error
        }
    }

    /// Creates a new account. Returns `true` when the user must confirm their
    /// email address before they can sign in (no session was returned).
    /// The confirmation link redirects back into the app.
    func signUp(email: String, password: String) async throws -> Bool {
        try ensureConfigured()
        do {
            let response = try await client.auth.signUp(
                email: Self.normalized(email: email),
                password: password,
                redirectTo: Self.authCallbackURL
            )
            AppLog.auth.info("Sign-up succeeded, needs email confirmation: \(response.session == nil)")
            return response.session == nil
        } catch {
            AppLog.auth.error("Sign-up failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Re-sends the sign-up confirmation email with the same callback link.
    func resendSignUpConfirmation(email: String) async throws {
        try ensureConfigured()
        do {
            try await client.auth.resend(
                email: Self.normalized(email: email),
                type: .signup,
                emailRedirectTo: Self.authCallbackURL
            )
            AppLog.auth.info("Sign-up confirmation email re-sent")
        } catch {
            AppLog.auth.error("Resend confirmation failed: \(error.localizedDescription, privacy: .public)")
            if let authError = error as? Auth.AuthError, authError.errorCode == .overEmailSendRateLimit {
                throw AuthError.tooManyRequests
            }
            throw error
        }
    }

    /// Completes email verification from the `cbtipul://auth-callback` deep
    /// link. The SDK exchanges the URL for a session; the auth state stream
    /// then flips the app to its signed-in root. Failures surface through
    /// `callbackError` on the sign-in screen, never as raw server errors.
    func handleAuthCallback(_ url: URL) async {
        do {
            try ensureConfigured()
            try await client.auth.session(from: url)
            callbackError = nil
            if url.host() == Self.passwordResetCallbackURL.host() {
                isRecoveringPassword = true
            }
            AppLog.auth.info("Auth callback handled, session established")
        } catch {
            AppLog.auth.error("Auth callback failed: \(error.localizedDescription, privacy: .public)")
            #if DEBUG
            print("Auth callback error: \(error)")
            #endif
            callbackError = L10n.verificationFailedError
        }
    }

    /// Sends a password-reset email to the given address; the link redirects
    /// back into the app, where the callback establishes a session.
    func resetPassword(email: String) async throws {
        try ensureConfigured()
        try await client.auth.resetPasswordForEmail(
            Self.normalized(email: email),
            redirectTo: Self.passwordResetCallbackURL
        )
        AppLog.auth.info("Password-reset email requested")
    }

    /// Sets a new password for the signed-in user, completing the recovery
    /// flow started by a password-reset link.
    func updatePassword(_ password: String) async throws {
        try ensureConfigured()
        do {
            try await client.auth.update(user: UserAttributes(password: password))
            isRecoveringPassword = false
            AppLog.auth.info("Password updated")
        } catch {
            AppLog.auth.error("Password update failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

//    func signIn(with provider: AuthProvider) async throws {
//        try ensureConfigured()
//        throw AuthError.notImplemented("\(provider.rawValue) sign-in")
//    }

    func signOut() {
        AppLog.auth.info("Sign-out requested")
        isRecoveringPassword = false
        Task {
            try? await client.auth.signOut()
            currentUserEmail = nil
        }
    }

    /// Permanently deletes the signed-in account. The client has no admin
    /// privileges, so the deletion itself (auth user plus all their rows)
    /// is performed by the `delete-account` Edge Function acting on the
    /// caller's identity; afterwards the local session is discarded.
    func deleteAccount() async throws {
        try ensureConfigured()
        do {
            try await client.functions.invoke("delete-account")
            AppLog.auth.notice("Account deleted")
        } catch {
            AppLog.auth.error("Account deletion failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        try? await client.auth.signOut()
        currentUserEmail = nil
    }

    private func ensureConfigured() throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
    }
}
