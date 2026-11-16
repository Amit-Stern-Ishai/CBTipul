import XCTest
import Supabase
@testable import CBTipul
final class EmailInvitationResponseTests: XCTestCase {
 func testAuthErrorsNeverExposeServerDescriptions() {
  XCTAssertTrue(AuthFailureCopy.message(code: "invalid_credentials").contains("הסיסמה"))
  XCTAssertTrue(AuthFailureCopy.message(code: "email_not_confirmed").contains("אומתה"))
  XCTAssertTrue(AuthFailureCopy.message(code: "over_request_rate_limit").contains("המתינו"))
  XCTAssertTrue(AuthFailureCopy.message(URLError(.notConnectedToInternet))!.contains("לאינטרנט"))
  XCTAssertEqual(AuthFailureCopy.message(code: nil), AuthFailureCopy.message(code: "private-server-error"))
  XCTAssertEqual(AuthFailureCopy.message(NSError(domain: "private", code: 1, userInfo: [NSLocalizedDescriptionKey: "private-server-error"])), AuthFailureCopy.message(code: nil))
  XCTAssertNil(AuthFailureCopy.message(CancellationError()))
 }
 func testGenericShareAndEligibility() throws {
  XCTAssertEqual(EmailInvitationShare.text, "הוזמנת להשתמש ב־CBTipul. פתחו את האפליקציה והירשמו או התחברו עם כתובת המייל שמסרתם למטפל/ת.\n\nhttps://cbtipul.com/")
  var pending = PendingEmailInvitation()
  XCTAssertFalse(pending.canShare)
  for status in ["waiting_for_sign_in", "waiting_for_confirmation", "pending"] {
   pending.receive(status); XCTAssertTrue(pending.canShare)
   let before = pending.status
   _ = EmailInvitationShare.text // Opening/cancelling sharing has no invitation mutation.
   XCTAssertEqual(pending.status, before); XCTAssertTrue(pending.canShare)
   pending.correct(); XCTAssertFalse(pending.canShare)
   pending.receive("email_unavailable"); XCTAssertFalse(pending.canShare)
  }
  try pending.load("pending"); XCTAssertTrue(pending.canShare)
  try pending.load("connected"); XCTAssertFalse(pending.canShare)
 }
 func testReopenedStatusAndMalformedRead() throws {
  var pending = PendingEmailInvitation()
  try pending.load("pending")
  XCTAssertTrue(pending.canCorrect); XCTAssertFalse(pending.editing)
  XCTAssertEqual(pending.status, "pending")
  XCTAssertThrowsError(try pending.load("unexpected"))
  XCTAssertEqual(pending.status, "pending")
  pending.correct(); XCTAssertTrue(pending.editing)
  try pending.load("connected")
  XCTAssertFalse(pending.canCorrect); XCTAssertFalse(pending.editing)
  try pending.load("no_invitation")
  XCTAssertNil(pending.status); XCTAssertTrue(pending.editing)
  XCTAssertEqual(try JSONDecoder().decode(String.self, from: Data(#""pending""#.utf8)), "pending")
  XCTAssertThrowsError(try JSONDecoder().decode(String.self, from: Data(#"{"status":"pending"}"#.utf8)))
 }
 func testPendingCorrectionKeepsServerStateUntilSuccess() {
  for original in ["waiting_for_sign_in", "waiting_for_confirmation"] {
   var pending = PendingEmailInvitation()
   pending.receive(original); XCTAssertTrue(pending.canCorrect)
   pending.correct(); XCTAssertTrue(pending.editing); XCTAssertEqual(pending.status, original)
   pending.receive("email_unavailable"); XCTAssertEqual(pending.status, original); XCTAssertTrue(pending.editing)
   pending.receive("waiting_for_sign_in"); XCTAssertFalse(pending.editing)
   pending.correct(); pending.receive("already_connected")
   XCTAssertFalse(pending.canCorrect); XCTAssertFalse(pending.editing)
  }
 }
 func testConflictUsesBodyCode() {
  let expected = "המטופל/ת כבר מחובר/ת לפרופיל הזה."
  XCTAssertEqual(EmailInvitationView.failure(FunctionsError.httpError(code: 409, data: Data(#"{"error":"patient_profile_already_connected"}"#.utf8))), expected)
  XCTAssertEqual(EmailInvitationView.failure(FunctionsError.httpError(code: 409, data: Data(#"{"error":"other"}"#.utf8))), L10n.emailInvitationFailed)
  XCTAssertEqual(EmailInvitationView.failure(FunctionsError.httpError(code: 409, data: Data(#"{"error":"email_unavailable"}"#.utf8))), L10n.emailInvitationUnavailable)
  XCTAssertEqual(EmailInvitationView.result("already_connected"), L10n.emailInvitationConnected)
  XCTAssertEqual(EmailInvitationView.result("waiting_for_sign_in"), "ממתין להתחברות המטופל/ת")
 }
 func testRequestKeepsExactOpenedPatientID() throws {
  let id = "11111111-1111-1111-1111-111111111111"
  let data = try JSONEncoder().encode(EmailInvitationView.Request(patient_id: id, email: "synthetic@example.invalid"))
  let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
  XCTAssertEqual(json["patient_id"], id)
 }
}
