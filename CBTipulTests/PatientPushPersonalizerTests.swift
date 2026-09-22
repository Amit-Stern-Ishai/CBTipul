import UserNotifications
import XCTest

final class PatientPushPersonalizerTests: XCTestCase {
    private let names: [String: String] = ["known-id": "דני"]

    func testUnknownTypeLeavesBodyUnchanged() {
        let content = UNMutableNotificationContent()
        content.title = "CBTipul"
        content.body = "המטופל/ת התחבר/ה בהצלחה ל-CBTipul"
        content.userInfo = ["type": "other"]
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.body, "המטופל/ת התחבר/ה בהצלחה ל-CBTipul")
    }

    func testPatientConnectedMissingPatientIdLeavesBodyUnchanged() {
        let content = UNMutableNotificationContent()
        content.title = "CBTipul"
        content.body = "המטופל/ת התחבר/ה בהצלחה ל-CBTipul"
        content.userInfo = ["type": "patient_connected"]
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.body, "המטופל/ת התחבר/ה בהצלחה ל-CBTipul")
    }

    func testPatientConnectedKnownIdUsesLocalName() {
        let content = connectedContent(patientId: "known-id")
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.body, "דני התחבר/ה בהצלחה ל-CBTipul")
    }

    func testQuestionnaireCompletedKnownIdUsesLocalName() {
        let content = questionnaireContent(patientId: "known-id")
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.body, "דני מילא/ה שאלון חדש")
        XCTAssertEqual(PatientPushPersonalizer.assignmentId(from: content.userInfo), "assign-1")
        XCTAssertEqual(PatientPushPersonalizer.sessionId(from: content.userInfo), "session-1")
    }

    func testQuestionnaireCompletedUnknownIdUsesGenericFallback() {
        let content = questionnaireContent(patientId: "unknown-id")
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.body, "מטופל/ת מילא/ה שאלון חדש")
        XCTAssertEqual(PatientPushPersonalizer.assignmentId(from: content.userInfo), "assign-1")
        XCTAssertEqual(PatientPushPersonalizer.sessionId(from: content.userInfo), "session-1")
    }

    func testQuestionnaireCompletedMissingPatientIdUsesGenericFallback() {
        let content = questionnaireContent(patientId: nil)
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.body, "מטופל/ת מילא/ה שאלון חדש")
        XCTAssertEqual(PatientPushPersonalizer.assignmentId(from: content.userInfo), "assign-1")
        XCTAssertEqual(PatientPushPersonalizer.sessionId(from: content.userInfo), "session-1")
    }

    private func connectedContent(patientId: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "CBTipul"
        content.body = "המטופל/ת התחבר/ה בהצלחה ל-CBTipul"
        var info: [AnyHashable: Any] = ["type": "patient_connected"]
        if let patientId { info["patientId"] = patientId }
        content.userInfo = info
        return content
    }

    private func questionnaireContent(patientId: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "CBTipul"
        content.body = "מטופל/ת מילא/ה שאלון חדש"
        var info: [AnyHashable: Any] = [
            "type": "questionnaire_completed",
            "assignmentId": "assign-1",
            "sessionId": "session-1",
        ]
        if let patientId { info["patientId"] = patientId }
        content.userInfo = info
        return content
    }
}
