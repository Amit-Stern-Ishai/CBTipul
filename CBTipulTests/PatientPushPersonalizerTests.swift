import UserNotifications
import XCTest

final class PatientPushPersonalizerTests: XCTestCase {
    func testUnknownTypeLeavesBodyUnchanged() {
        let content = UNMutableNotificationContent()
        content.title = "CBTipul"
        content.body = "המטופל/ת התחבר/ה בהצלחה ל-CBTipul"
        content.userInfo = ["type": "other"]
        PatientPushPersonalizer.apply(to: content)
        XCTAssertEqual(content.body, "המטופל/ת התחבר/ה בהצלחה ל-CBTipul")
    }

    func testMissingPatientIdLeavesBodyUnchanged() {
        let content = UNMutableNotificationContent()
        content.title = "CBTipul"
        content.body = "המטופל/ת התחבר/ה בהצלחה ל-CBTipul"
        content.userInfo = ["type": "patient_connected"]
        PatientPushPersonalizer.apply(to: content)
        XCTAssertEqual(content.body, "המטופל/ת התחבר/ה בהצלחה ל-CBTipul")
    }
}
