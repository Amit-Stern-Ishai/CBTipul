import Foundation
import GoogleSignIn
import Testing
@testable import CBTipul

@MainActor
struct NativeGoogleSignInTests {
    @Test func nonceIsRandomAndUsesSupabaseSHA256Contract() throws {
        let first = try NativeSignInNonce.nonce()
        let second = try NativeSignInNonce.nonce()
        #expect(first.count == 64)
        #expect(first != second)
        #expect(first.allSatisfy { "0123456789abcdef".contains($0) })
        #expect(NativeSignInNonce.hash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func configurationIncludesBothClientsAndPreservesExistingScheme() throws {
        #expect(Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ==
            "378231528435-qjvaeh0a7mnaenmi3v6298hak5dh0obe.apps.googleusercontent.com")
        #expect(Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String ==
            "378231528435-5rftt3sjnsvi3kc6sh6pndua096nt5u7.apps.googleusercontent.com")
        let types = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes.contains("cbtipul"))
        #expect(schemes.contains(try #require(NativeGoogleSignIn.callbackScheme)))
    }

    @Test func googleNeverConsumesExistingLinks() throws {
        for value in ["cbtipul://auth-callback", "cbtipul://password-reset",
                      "https://cbtipul.com/invite/test", "cbtipul://invite/test"] {
            #expect(!NativeGoogleSignIn.handles(try #require(URL(string: value))))
        }
    }

    @Test func onlyGoogleCancellationIsQuiet() {
        #expect(NativeGoogleSignIn.isCancellation(NSError(domain: kGIDSignInErrorDomain,
            code: GIDSignInError.canceled.rawValue)))
        #expect(!NativeGoogleSignIn.isCancellation(NSError(domain: NSURLErrorDomain, code: -5)))
        #expect(!NativeGoogleSignIn.isCancellation(NSError(domain: kGIDSignInErrorDomain, code: -2)))
    }
}
