import UserNotifications
import XCTest
@testable import CBTipul

final class PatientPushPersonalizerTests: XCTestCase {
    private let names: [String: String] = ["known-id": "דני"]

    func testUnknownTypeLeavesBodyUnchanged() {
        let content = UNMutableNotificationContent()
        content.title = "CBTipul"
        content.body = "המטופל/ת התחבר/ה ל-CBTipul"
        content.userInfo = ["type": "other"]
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.body, "המטופל/ת התחבר/ה ל-CBTipul")
    }

    func testPatientConnectedMissingPatientIdLeavesBodyUnchanged() {
        let content = UNMutableNotificationContent()
        content.title = "CBTipul"
        content.body = "המטופל/ת התחבר/ה ל-CBTipul"
        content.userInfo = ["type": "patient_connected"]
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.body, "המטופל/ת התחבר/ה ל-CBTipul")
    }

    func testPatientConnectedKnownIdUsesLocalName() {
        let content = connectedContent(patientId: "known-id")
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.body, "דני התחבר/ה ל-CBTipul")
    }

    func testPatientConnectedUnknownIdUsesGenericFallback() {
        let content = connectedContent(patientId: "unknown-id")
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.body, "המטופל/ת התחבר/ה ל-CBTipul")
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

    func testDiaryOneEntryAddedKnownIdUsesLocalNameAsTitle() {
        let content = diaryOneEntryContent(patientId: "known-id")
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.title, "דני")
        XCTAssertEqual(content.body, "הוסיף/ה רשומה חדשה ליומן 1")
    }

    func testDiaryOneEntryAddedUnknownIdUsesGenericPatientTitle() {
        let content = diaryOneEntryContent(patientId: "unknown-id")
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.title, "מטופל/ת")
        XCTAssertEqual(content.body, "הוסיף/ה רשומה חדשה ליומן 1")
    }

    func testDiaryOneAssignedLeavesBodyUnchanged() {
        let content = UNMutableNotificationContent()
        content.title = "CBTipul"
        content.body = "server copy"
        content.userInfo = ["type": "diary_1_assigned", "patientId": "known-id"]
        PatientPushPersonalizer.apply(to: content, nameForPatientId: { names[$0] })
        XCTAssertEqual(content.body, "server copy")
        XCTAssertEqual(content.title, "CBTipul")
    }

    private func connectedContent(patientId: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "CBTipul"
        content.body = "המטופל/ת התחבר/ה ל-CBTipul"
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

    private func diaryOneEntryContent(patientId: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "CBTipul"
        content.body = "generic"
        var info: [AnyHashable: Any] = [
            "type": "diary_1_entry_added",
            "resourceType": "diary_one_entry",
            "resourceId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        ]
        if let patientId { info["patientId"] = patientId }
        content.userInfo = info
        return content
    }
}
