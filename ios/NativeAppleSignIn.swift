import AuthenticationServices
import CryptoKit
import Foundation
import Security

/// Shared nonce contract for native Google and Apple tokens.
@MainActor
enum NativeSignInNonce {
    static func nonce() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw AppleLoginError.failed
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func hash(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

}

@MainActor
struct AppleSignInAttempt {
    let nonce: String
    let state: String

    init() throws {
        nonce = try NativeSignInNonce.nonce()
        state = UUID().uuidString
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.email, .fullName]
        request.nonce = NativeSignInNonce.hash(nonce)
        request.state = state
    }

    func identityToken(_ data: Data?, returnedState: String?) throws -> String {
        guard returnedState == state, let data,
              let token = String(data: data, encoding: .utf8),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppleLoginError.failed
        }
        return token
    }

    static func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == ASAuthorizationError.errorDomain
            && error.code == ASAuthorizationError.canceled.rawValue
    }
}

enum AppleLoginError: LocalizedError {
    case failed
    var errorDescription: String? { L10n.appleSignInFailed }
}
