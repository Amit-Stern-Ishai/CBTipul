import AuthenticationServices
import Foundation
import Testing
@testable import CBTipul

@MainActor
struct NativeAppleSignInTests {
    @Test func requestUsesFreshNonceHashedForAppleAndRequestsBothScopes() throws {
        let first = try AppleSignInAttempt()
        let second = try AppleSignInAttempt()
        #expect(first.nonce != second.nonce)
        #expect(first.state != second.state)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        first.configure(request)
        #expect(request.nonce == NativeSignInNonce.hash(first.nonce))
        #expect(request.nonce != first.nonce)
        #expect(request.state == first.state)
        #expect(request.requestedScopes == [.email, .fullName])
    }

    @Test func rejectsMissingInvalidOrUncorrelatedCredentials() throws {
        let attempt = try AppleSignInAttempt()
        #expect(throws: AppleLoginError.self) { try attempt.identityToken(nil, returnedState: attempt.state) }
        #expect(throws: AppleLoginError.self) { try attempt.identityToken(Data(), returnedState: attempt.state) }
        #expect(throws: AppleLoginError.self) { try attempt.identityToken(Data([0xff]), returnedState: attempt.state) }
        #expect(throws: AppleLoginError.self) { try attempt.identityToken(Data("token".utf8), returnedState: "stale") }
        #expect(try attempt.identityToken(Data("token".utf8), returnedState: attempt.state) == "token")
    }

    @Test func onlyAppleCancellationIsQuiet() {
        #expect(AppleSignInAttempt.isCancellation(NSError(domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.canceled.rawValue)))
        #expect(!AppleSignInAttempt.isCancellation(NSError(domain: NSURLErrorDomain,
            code: ASAuthorizationError.canceled.rawValue)))
        #expect(!AppleSignInAttempt.isCancellation(NSError(domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.failed.rawValue)))
    }

    @Test func providerRequestBlocksOtherProvidersAndCanBeCancelled() async throws {
        let auth = AuthManager()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        try auth.prepareAppleSignIn(request)
        #expect(auth.isProviderSignInInProgress)
        #expect(throws: AppleLoginError.self) {
            try auth.prepareAppleSignIn(ASAuthorizationAppleIDProvider().createRequest())
        }
        do {
            try await auth.signIn(email: "test@example.com", password: "unused")
            Issue.record("Email must not start while Apple is pending")
        } catch AuthError.signInInProgress { }
        await #expect(throws: Never.self) {
            try await auth.completeAppleSignIn(.failure(NSError(domain: ASAuthorizationError.errorDomain,
                code: ASAuthorizationError.canceled.rawValue)))
        }
        #expect(!auth.isProviderSignInInProgress)
        try auth.prepareAppleSignIn(ASAuthorizationAppleIDProvider().createRequest())
        auth.cancelPendingProviderSignIn()
        #expect(!auth.isProviderSignInInProgress)
    }
}
