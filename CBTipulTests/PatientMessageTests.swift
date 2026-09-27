import Foundation
import Testing
@testable import CBTipul

struct PatientMessageTests {
    private let messageID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    private let patientID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!

    @Test func decodesUnreadAndReadRows() throws {
        let unreadJSON = Data("""
        {
          "id": "\(messageID.uuidString)",
          "patient_id": "\(patientID.uuidString)",
          "body": "hello",
          "created_at": "2026-01-02T10:15:00Z",
          "read_at": null
        }
        """.utf8)
        let readJSON = Data("""
        {
          "id": "\(messageID.uuidString)",
          "patient_id": "\(patientID.uuidString)",
          "body": "hello",
          "created_at": "2026-01-02T10:15:00Z",
          "read_at": "2026-01-02T11:00:00Z"
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let unread = try decoder.decode(PatientMessage.self, from: unreadJSON)
        let read = try decoder.decode(PatientMessage.self, from: readJSON)
        #expect(unread.isUnread)
        #expect(unread.readAt == nil)
        #expect(!read.isUnread)
        #expect(read.readAt != nil)
        #expect(unread.body == "hello")
    }

    @Test func emptyAndTooLongBodiesCannotSend() {
        #expect(!PatientMessageDraft.canSend("   "))
        #expect(!PatientMessageDraft.canSend(""))
        #expect(SendPatientMessageRequestFactory.make(patientId: patientID, rawBody: "  \n") == nil)
        let tooLong = String(repeating: "א", count: PatientMessageDraft.maxLength + 1)
        #expect(!PatientMessageDraft.canSend(tooLong))
        #expect(SendPatientMessageRequestFactory.make(patientId: patientID, rawBody: tooLong) == nil)
        let maxed = String(repeating: "א", count: PatientMessageDraft.maxLength)
        #expect(PatientMessageDraft.canSend(maxed))
    }

    @Test func sendRequestTrimsBodyAndKeepsPatientId() {
        let request = SendPatientMessageRequestFactory.make(
            patientId: patientID,
            rawBody: "  היי, רציתי להזכיר לך למלא את היומן.  "
        )
        #expect(request?.patientId == patientID)
        #expect(request?.body == "היי, רציתי להזכיר לך למלא את היומן.")
    }

    @Test func markReadUpdatesLocalStateOnly() {
        let unread = PatientMessage(
            id: messageID,
            patientId: patientID,
            body: "hello",
            createdAt: Date(timeIntervalSince1970: 100),
            readAt: nil
        )
        let readAt = Date(timeIntervalSince1970: 200)
        let read = unread.markedRead(at: readAt)
        #expect(unread.isUnread)
        #expect(!read.isUnread)
        #expect(read.readAt == readAt)
        #expect(read.body == unread.body)
        #expect(read.id == unread.id)
    }

    @Test func messageReceivedPayloadParsesExactUUID() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "message_received",
            "notificationId": "11111111-1111-1111-1111-111111111111",
            "patientId": patientID.uuidString,
            "resourceType": "message",
            "resourceId": messageID.uuidString,
        ])
        #expect(payload?.type == .messageReceived)
        #expect(PatientMessageRouter.messageID(resourceId: payload?.resourceId) == messageID)
        #expect(
            PatientMessageRouter.destination(from: payload!) == .exact(messageID)
        )
        #expect(NotificationRouter.destination(from: payload!) == .none)
    }

    @Test func missingMessageFallsBackToList() {
        let missingResource = AppNotificationPayload.from(userInfo: [
            "type": "message_received",
            "patientId": patientID.uuidString,
            "resourceType": "message",
        ])!
        #expect(PatientMessageRouter.destination(from: missingResource) == .list)
        let badUUID = AppNotificationPayload.from(userInfo: [
            "type": "message_received",
            "patientId": patientID.uuidString,
            "resourceType": "message",
            "resourceId": "not-a-uuid",
        ])!
        #expect(PatientMessageRouter.messageID(resourceId: "not-a-uuid") == nil)
        #expect(PatientMessageRouter.destination(from: badUUID) == .list)
    }

    @Test func inboxAndPushSharePatientMessageRoute() {
        let notification = AppNotification(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            type: .messageReceived,
            patientId: patientID.uuidString,
            sessionId: nil,
            assignmentId: nil,
            resourceType: "message",
            resourceId: messageID.uuidString,
            createdAt: Date(),
            seenAt: nil,
            readAt: nil
        )
        let fromRecord = PatientMessageRouter.destination(
            from: AppNotificationPayload.from(notification: notification)
        )
        let fromPush = PatientMessageRouter.destination(from: AppNotificationPayload.from(userInfo: [
            "type": "message_received",
            "notificationId": "11111111-1111-1111-1111-111111111111",
            "patientId": patientID.uuidString,
            "resourceType": "message",
            "resourceId": messageID.uuidString,
        ])!)
        #expect(fromRecord == fromPush)
        #expect(fromRecord == .exact(messageID))
        #expect(NotificationRouter.destination(from: notification) == .none)
    }

    @Test func questionnaireAndPatientConnectedRoutingUnchanged() {
        let questionnaire = AppNotificationPayload.from(userInfo: [
            "type": "questionnaire_completed",
            "patientId": "patient-1",
            "resourceType": "questionnaire",
            "resourceId": "42",
        ])!
        #expect(
            NotificationRouter.destination(from: questionnaire)
                == .completedQuestionnaire(
                    patientId: "patient-1",
                    resourceType: "questionnaire",
                    resourceId: "42"
                )
        )
        #expect(PatientMessageRouter.destination(from: questionnaire) == .none)
        let connected = AppNotificationPayload.from(userInfo: [
            "type": "patient_connected",
            "patientId": "patient-1",
        ])!
        #expect(
            NotificationRouter.destination(from: connected) == .patientDetail(patientId: "patient-1")
        )
        #expect(PatientMessageRouter.destination(from: connected) == .none)
    }

    @Test func messageNavigationStackPreservesEntryPath() {
        let fromHome = PatientModeMessageStack.screens(afterOpening: .homeLatest)
        #expect(fromHome == [.home, .detail])
        #expect(PatientModeMessageStack.screensAfterBack(from: fromHome) == [.home])

        let fromList = PatientModeMessageStack.screens(afterOpening: .allMessagesThenMessage)
        #expect(fromList == [.home, .list, .detail])
        #expect(PatientModeMessageStack.screensAfterBack(from: fromList) == [.home, .list])
        #expect(PatientModeMessageStack.screensAfterBack(from: [.home, .list]) == [.home])

        let fromPush = PatientModeMessageStack.screens(afterOpening: .pushExact)
        #expect(fromPush == [.home, .detail])
        #expect(PatientModeMessageStack.screensAfterBack(from: fromPush) == [.home])
        #expect(fromPush == fromHome)
        #expect(fromList != fromPush)
    }
}
