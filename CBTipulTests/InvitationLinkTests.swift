import Foundation
import Testing
@testable import CBTipul

struct InvitationLinkTests {
    @Test func extractsTokenFromCanonicalURL() {
        let url = URL(string: "https://cbtipul.com/invite/opaque-token")!
        #expect(InvitationLink.token(from: url) == "opaque-token")
    }

    @Test func rejectsEmptyToken() {
        #expect(InvitationLink.token(from: URL(string: "https://cbtipul.com/invite/")!) == nil)
        #expect(InvitationLink.token(from: URL(string: "https://cbtipul.com/invite")!) == nil)
    }

    @Test func rejectsExtraPathSegments() {
        #expect(InvitationLink.token(from: URL(string: "https://cbtipul.com/invite/a/b")!) == nil)
    }

    @Test func rejectsNonHTTPSOrWrongHost() {
        #expect(InvitationLink.token(from: URL(string: "http://cbtipul.com/invite/abc")!) == nil)
        #expect(InvitationLink.token(from: URL(string: "https://www.cbtipul.com/invite/abc")!) == nil)
        #expect(InvitationLink.token(from: URL(string: "cbtipul://auth-callback")!) == nil)
    }
}
