import Testing
@testable import CBTipul
@MainActor struct EmailInvitationResultTests {
 @Test func serverStatusesAndUnknownResult() {
  #expect(EmailInvitationView.result("waiting_for_sign_in") == "ממתין להתחברות המטופל/ת")
  #expect(EmailInvitationView.result("waiting_for_confirmation") == "ממתין לאישור המטופל/ת")
  #expect(EmailInvitationView.result("already_connected") == "המטופל/ת כבר מחובר/ת")
  #expect(EmailInvitationView.result("email_unavailable") == "לא ניתן להשתמש בכתובת הזו להזמנה")
  #expect(EmailInvitationView.result("unknown") == nil)
 }
}
