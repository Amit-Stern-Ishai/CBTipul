import Foundation
import Testing
@testable import CBTipul

struct NotificationRoutingTests {
    @Test func unknownTypeDoesNotCrashAndDoesNotRoute() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "diary_entry_submitted",
            "patientId": "p1",
        ])
        #expect(payload?.type == .unknown("diary_entry_submitted"))
        #expect(NotificationRouter.destination(from: payload!) == .none)
    }

    @Test func missingTypeIsIgnored() {
        #expect(AppNotificationPayload.from(userInfo: ["patientId": "p1"]) == nil)
    }

    @Test func questionnaireCompletedAllowsNullSessionId() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "questionnaire_completed",
            "patientId": "patient-1",
            "assignmentId": "assign-1",
        ])
        #expect(payload != nil)
        #expect(payload?.sessionId == nil)
        #expect(
            NotificationRouter.destination(from: payload!)
                == .completedQuestionnaire(
                    patientId: "patient-1",
                    assignmentId: "assign-1",
                    sessionId: nil,
                    resourceId: nil
                )
        )
    }

    @Test func snakeCaseKeysAreAccepted() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "questionnaire_completed",
            "patient_id": "patient-1",
            "session_id": "session-1",
            "assignment_id": "assign-1",
            "resource_id": "mood-9",
            "notification_id": "11111111-1111-1111-1111-111111111111",
        ])
        #expect(payload?.patientId == "patient-1")
        #expect(payload?.sessionId == "session-1")
        #expect(payload?.assignmentId == "assign-1")
        #expect(payload?.resourceId == "mood-9")
        #expect(payload?.notificationId == "11111111-1111-1111-1111-111111111111")
    }

    @Test func inboxRecordAndPushPayloadShareDestination() {
        let notification = AppNotification(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            type: .questionnaireCompleted,
            patientId: "patient-1",
            sessionId: nil,
            assignmentId: "assign-1",
            resourceId: "mood-9",
            createdAt: Date(),
            readAt: nil
        )
        let fromRecord = NotificationRouter.destination(from: notification)
        let fromPush = NotificationRouter.destination(from: AppNotificationPayload.from(userInfo: [
            "type": "questionnaire_completed",
            "patientId": "patient-1",
            "assignmentId": "assign-1",
            "resourceId": "mood-9",
        ])!)
        #expect(fromRecord == fromPush)
        if case .completedQuestionnaire(_, _, let sessionId, let resourceId) = fromRecord {
            #expect(sessionId == nil)
            #expect(resourceId == "mood-9")
        } else {
            Issue.record("expected completedQuestionnaire destination")
        }
    }

    @Test func questionnaireCompletedWithoutPatientDoesNotRoute() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "questionnaire_completed",
            "assignmentId": "assign-1",
        ])!
        #expect(NotificationRouter.destination(from: payload) == .none)
    }

    @Test func assignmentIdAloneIsNotAQuestionnaireResource() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "questionnaire_completed",
            "patientId": "patient-1",
            "assignmentId": "assign-1",
        ])!
        if case .completedQuestionnaire(_, let assignmentId, _, let resourceId) =
            NotificationRouter.destination(from: payload)
        {
            #expect(assignmentId == "assign-1")
            #expect(resourceId == nil)
        } else {
            Issue.record("expected completedQuestionnaire destination")
        }
    }

    @Test func nestedDataBagIsFlattened() {
        let payload = AppNotificationPayload.from(userInfo: [
            "data": [
                "type": "questionnaire_completed",
                "patientId": "patient-1",
            ],
        ])
        #expect(payload?.patientId == "patient-1")
    }
}
