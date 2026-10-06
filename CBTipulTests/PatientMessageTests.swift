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

    private func message(
        id: String,
        created: TimeInterval,
        readAt: TimeInterval? = nil
    ) -> PatientMessage {
        PatientMessage(
            id: UUID(uuidString: id)!,
            patientId: patientID,
            body: id,
            createdAt: Date(timeIntervalSince1970: created),
            readAt: readAt.map { Date(timeIntervalSince1970: $0) }
        )
    }

    @Test func homePreviewsShowAtMostTwoNewestUnread() {
        let readNewest = message(
            id: "11111111-1111-1111-1111-111111111111",
            created: 500,
            readAt: 600
        )
        let unreadA = message(id: "22222222-2222-2222-2222-222222222222", created: 100)
        let unreadB = message(id: "33333333-3333-3333-3333-333333333333", created: 300)
        let unreadC = message(id: "44444444-4444-4444-4444-444444444444", created: 200)
        let unreadD = message(id: "55555555-5555-5555-5555-555555555555", created: 400)
        let unreadE = message(id: "66666666-6666-6666-6666-666666666666", created: 50)

        #expect(PatientModeHomeMessages.previews(in: []).isEmpty)
        #expect(PatientModeHomeMessages.remainingUnreadCount(in: []) == 0)

        let one = [unreadA, readNewest]
        #expect(PatientModeHomeMessages.previews(in: one).map(\.id) == [unreadA.id])
        #expect(PatientModeHomeMessages.remainingUnreadCount(in: one) == 0)

        let two = [unreadA, unreadB]
        #expect(PatientModeHomeMessages.previews(in: two).map(\.id) == [unreadB.id, unreadA.id])
        #expect(PatientModeHomeMessages.remainingUnreadCount(in: two) == 0)

        let three = [unreadA, unreadB, unreadC]
        #expect(PatientModeHomeMessages.previews(in: three).map(\.id) == [unreadB.id, unreadC.id])
        #expect(PatientModeHomeMessages.remainingUnreadCount(in: three) == 1)
        #expect(L10n.moreUnreadMessages(1) == "ועוד הודעה אחת שלא נקראה")

        let five = [readNewest, unreadA, unreadB, unreadC, unreadD, unreadE]
        let previews = PatientModeHomeMessages.previews(in: five)
        #expect(previews.map(\.id) == [unreadD.id, unreadB.id])
        #expect(previews.allSatisfy { $0.isUnread })
        #expect(!previews.contains(where: { $0.id == readNewest.id }))
        #expect(PatientModeHomeMessages.remainingUnreadCount(in: five) == 3)
        #expect(L10n.moreUnreadMessages(3) == "ועוד 3 הודעות שלא נקראו")
    }

    @Test func readingNewestUnreadPromotesTheNextHomePreview() {
        let d = message(id: "11111111-1111-1111-1111-111111111111", created: 400)
        let c = message(id: "22222222-2222-2222-2222-222222222222", created: 300)
        let b = message(id: "33333333-3333-3333-3333-333333333333", created: 200)
        let a = message(id: "44444444-4444-4444-4444-444444444444", created: 100)
        var items = [d, c, b, a]
        #expect(PatientModeHomeMessages.previews(in: items).map(\.id) == [d.id, c.id])
        #expect(PatientModeHomeMessages.remainingUnreadCount(in: items) == 2)

        items[0] = d.markedRead(at: Date(timeIntervalSince1970: 500))
        #expect(PatientModeHomeMessages.previews(in: items).map(\.id) == [c.id, b.id])
        #expect(!PatientModeHomeMessages.previews(in: items).contains(where: { $0.id == d.id }))
        #expect(PatientModeHomeMessages.remainingUnreadCount(in: items) == 1)
        #expect(items.contains(where: { $0.id == a.id && $0.isUnread }))
    }

    @Test func fullMessageListKeepsReadAndUnread() {
        let unread = message(id: "11111111-1111-1111-1111-111111111111", created: 200)
        let read = message(
            id: "22222222-2222-2222-2222-222222222222",
            created: 100,
            readAt: 150
        )
        let items = [unread, read]
        #expect(PatientModeHomeMessages.previews(in: items).map(\.id) == [unread.id])
        #expect(items.map(\.id) == [unread.id, read.id])
        #expect(items.contains(where: { !$0.isUnread }))
    }
}

struct PatientUnifiedInboxTests {
    let patient = UUID()
    let messageID = UUID()
    let assignmentID = UUID()
    func notice(_ type: AppNotificationType, resource: String, id: UUID, patientID: UUID? = nil) -> AppNotification {
        AppNotification(id: UUID(), type: type, patientId: (patientID ?? patient).uuidString,
            sessionId: nil, assignmentId: resource == "assignment" ? id.uuidString : nil,
            resourceType: resource, resourceId: id.uuidString, createdAt: Date(timeIntervalSince1970: 20), seenAt: nil, readAt: nil)
    }
    @Test func deduplicatesMessagesAndUsesMessageReceipt() {
        let message = PatientMessage(id: messageID, patientId: patient, body: "hello", createdAt: Date(), readAt: Date())
        let notification = notice(.messageReceived, resource: "message", id: messageID)
        let items = PatientInboxItem.items(patientID: patient, messages: [message], notifications: [notification])
        #expect(items.count == 1)
        #expect(!items[0].isUnread)
    }
    @Test func filtersOtherPatientsAndTherapistEvents() {
        let items = PatientInboxItem.items(patientID: patient, messages: [], notifications: [
            notice(.diaryOneAssigned, resource: "assignment", id: assignmentID),
            notice(.questionnaireAssigned, resource: "assignment", id: UUID(), patientID: UUID()),
            notice(.questionnaireCompleted, resource: "questionnaire", id: UUID())
        ])
        #expect(items.count == 1)
        #expect(items[0].notification?.exactAssignmentID == assignmentID)
    }
    @Test func ongoingQuestionnaireIgnoresCompletedAtButRejectsCancellationAndWrongIDs() {
        let active = PatientAssignment(id: assignmentID, patientId: patient, therapistId: nil, sessionId: nil,
            typeValue: "questionnaire", createdAt: Date(), completedAt: Date(), cancelledAt: nil)
        let payload = AppNotificationPayload.from(notification: notice(.questionnaireAssigned, resource: "assignment", id: assignmentID))
        #expect(PatientInboxItem.assignment(payload: payload, patientID: patient, assignments: [active])?.id == assignmentID)
        let cancelled = PatientAssignment(id: assignmentID, patientId: patient, therapistId: nil, sessionId: nil,
            typeValue: "questionnaire", createdAt: Date(), completedAt: nil, cancelledAt: Date())
        #expect(PatientInboxItem.assignment(payload: payload, patientID: patient, assignments: [cancelled]) == nil)
        #expect(PatientInboxItem.assignment(payload: payload, patientID: UUID(), assignments: [active]) == nil)
        #expect(PatientInboxItem.assignment(payload: payload, patientID: patient, assignments: []) == nil)
    }
    @Test func seeingDoesNotReadAndConflictingIdsAreRejected() {
        let notification = notice(.questionnaireAssigned, resource: "assignment", id: assignmentID)
        #expect(notification.acknowledged(at: Date()).isUnread)
        #expect(notification.exactAssignmentID == assignmentID)
        let conflict = AppNotification(id: UUID(), type: .diaryOneAssigned, patientId: patient.uuidString,
            sessionId: nil, assignmentId: assignmentID.uuidString, resourceType: "assignment", resourceId: UUID().uuidString,
            createdAt: Date(), seenAt: nil, readAt: nil)
        #expect(conflict.exactAssignmentID == nil)
    }
}
