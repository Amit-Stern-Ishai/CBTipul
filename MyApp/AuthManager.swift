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

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return L10n.supabaseNotConfiguredError
        case .notImplemented(let feature):
            return L10n.notImplementedError(feature)
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
    /// The shared Supabase client, also used for database access later.
    let client: SupabaseClient

    private(set) var currentUserEmail: String?

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

    func signIn(email: String, password: String) async throws {
        try ensureConfigured()
        do {
            try await client.auth.signIn(email: email, password: password)
            AppLog.auth.info("Sign-in succeeded")
        } catch {
            AppLog.auth.error("Sign-in failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Creates a new account. Returns `true` when the user must confirm their
    /// email address before they can sign in (no session was returned).
    func signUp(email: String, password: String) async throws -> Bool {
        try ensureConfigured()
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            AppLog.auth.info("Sign-up succeeded, needs email confirmation: \(response.session == nil)")
            return response.session == nil
        } catch {
            AppLog.auth.error("Sign-up failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Sends a password-reset email to the given address.
    func resetPassword(email: String) async throws {
        try ensureConfigured()
        try await client.auth.resetPasswordForEmail(email)
        AppLog.auth.info("Password-reset email requested")
    }

//    func signIn(with provider: AuthProvider) async throws {
//        try ensureConfigured()
//        throw AuthError.notImplemented("\(provider.rawValue) sign-in")
//    }

    func signOut() {
        AppLog.auth.info("Sign-out requested")
        Task {
            try? await client.auth.signOut()
            currentUserEmail = nil
        }
    }

    private func ensureConfigured() throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
    }
}
