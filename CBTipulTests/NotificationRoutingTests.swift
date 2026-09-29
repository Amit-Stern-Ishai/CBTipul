import Foundation
import Testing
@testable import CBTipul

struct NotificationRoutingTests {
    @MainActor @Test func inboxJourneyReturnsToInboxAndCanBeOpenedAgain() {
        let coordinator = TherapistNotificationCoordinator.shared
        coordinator.resetOnLogout()
        defer { coordinator.resetOnLogout() }
        let patient = Patient(id: .text("inbox-patient"))
        let item = AppNotification(
            id: UUID(), type: .questionnaireCompleted,
            patientId: "inbox-patient", sessionId: nil, assignmentId: nil,
            resourceType: "questionnaire", resourceId: "42",
            createdAt: Date(), seenAt: nil, readAt: nil
        )
        coordinator.selectedTab = .notifications
        coordinator.handleInboxTap(item, patients: [patient])
        #expect(coordinator.selectedTab == .patients)
        #expect(coordinator.consumePatientNavigation()?.questionnairesRoute?.focusQuestionnaireID == .integer(42))
        coordinator.finishInboxNavigation()
        #expect(coordinator.selectedTab == .notifications)
        #expect(!coordinator.returnsToInbox)
        coordinator.handleInboxTap(item, patients: [patient])
        #expect(coordinator.consumePatientNavigation() != nil)
        coordinator.cancelInboxReturn()
        coordinator.finishInboxNavigation()
        #expect(coordinator.selectedTab == .patients)
        coordinator.handleInboxTap(item, patients: [])
        #expect(coordinator.selectedTab == .notifications)
        #expect(coordinator.unavailableTarget)
        #expect(coordinator.consumePatientNavigation() == nil)
        #expect(!coordinator.returnsToInbox)
    }

    @Test func unknownTypeDoesNotCrashAndDoesNotRoute() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "diary_entry_submitted",
            "patientId": "p1",
        ])
        #expect(payload?.type == .unknown("diary_entry_submitted"))
        #expect(NotificationRouter.destination(from: payload!) == .none)
    }

    @Test func questionnaireAssignedDoesNotUseTherapistNavigation() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "questionnaire_assigned",
            "notificationId": "11111111-1111-1111-1111-111111111111",
            "patientId": "patient-1",
            "assignmentId": "assign-1",
            "resourceType": "assignment",
            "resourceId": "assign-1",
        ])
        #expect(payload?.type == .questionnaireAssigned)
        #expect(payload?.resourceType == "assignment")
        #expect(payload?.sessionId == nil)
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
            "resourceType": "questionnaire",
            "resourceId": "42",
        ])
        #expect(payload != nil)
        #expect(payload?.sessionId == nil)
        #expect(
            NotificationRouter.destination(from: payload!)
                == .completedQuestionnaire(
                    patientId: "patient-1",
                    resourceType: "questionnaire",
                    resourceId: "42"
                )
        )
        #expect(
            QuestionnaireNotificationFocus.combinedMoodID(
                resourceType: "questionnaire",
                resourceId: "42"
            ) == .integer(42)
        )
    }

    @Test func snakeCaseKeysAreAccepted() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "questionnaire_completed",
            "patient_id": "patient-1",
            "session_id": "session-1",
            "assignment_id": "assign-1",
            "resource_type": "questionnaire",
            "resource_id": "mood-9",
            "notification_id": "11111111-1111-1111-1111-111111111111",
        ])
        #expect(payload?.patientId == "patient-1")
        #expect(payload?.sessionId == "session-1")
        #expect(payload?.assignmentId == "assign-1")
        #expect(payload?.resourceType == "questionnaire")
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
            resourceType: "questionnaire",
            resourceId: "42",
            createdAt: Date(),
            seenAt: nil,
            readAt: nil
        )
        let fromRecord = NotificationRouter.destination(from: notification)
        let fromPush = NotificationRouter.destination(from: AppNotificationPayload.from(userInfo: [
            "type": "questionnaire_completed",
            "patientId": "patient-1",
            "assignmentId": "assign-1",
            "resourceType": "questionnaire",
            "resourceId": "42",
        ])!)
        #expect(fromRecord == fromPush)
        if case .completedQuestionnaire(let patientId, let resourceType, let resourceId) = fromRecord {
            #expect(patientId == "patient-1")
            #expect(resourceType == "questionnaire")
            #expect(resourceId == "42")
            #expect(
                QuestionnaireNotificationFocus.combinedMoodID(
                    resourceType: resourceType,
                    resourceId: resourceId
                ) == .integer(42)
            )
        } else {
            Issue.record("expected completedQuestionnaire destination")
        }
    }

    @Test func malformedResourceIdFallsBackToQuestionnaireList() {
        #expect(
            QuestionnaireNotificationFocus.combinedMoodID(
                resourceType: "questionnaire",
                resourceId: "not-a-number"
            ) == nil
        )
        #expect(
            QuestionnaireNotificationFocus.combinedMoodID(
                resourceType: "assignment",
                resourceId: "42"
            ) == nil
        )
        #expect(
            QuestionnaireNotificationFocus.combinedMoodID(
                resourceType: "questionnaire",
                resourceId: nil
            ) == nil
        )
    }

    @Test func combinedMoodIntegerAndTextIdentitiesMatch() {
        #expect(DatabaseID.integer(42).isSameIdentity(as: .text("42")))
        #expect(DatabaseID.parseCombinedMoodID("42") == .integer(42))
        #expect(DatabaseID.parseCombinedMoodID("11111111-1111-1111-1111-111111111111") == nil)
    }

    @Test func questionnaireCompletedWithoutPatientDoesNotRoute() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "questionnaire_completed",
            "assignmentId": "assign-1",
            "resourceType": "questionnaire",
            "resourceId": "42",
        ])!
        #expect(NotificationRouter.destination(from: payload) == .none)
    }

    @Test func assignmentIdAloneIsNotAQuestionnaireResource() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "questionnaire_completed",
            "patientId": "patient-1",
            "assignmentId": "assign-1",
        ])!
        if case .completedQuestionnaire(_, let resourceType, let resourceId) =
            NotificationRouter.destination(from: payload)
        {
            #expect(resourceType == nil)
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
                "resourceType": "questionnaire",
                "resourceId": "42",
            ],
        ])
        #expect(payload?.patientId == "patient-1")
        #expect(payload?.resourceType == "questionnaire")
        #expect(payload?.resourceId == "42")
    }

    @Test func patientConnectedDecodesAndDoesNotUseQuestionnaireRoute() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "patient_connected",
            "notificationId": "11111111-1111-1111-1111-111111111111",
            "patientId": "patient-1",
        ])
        #expect(payload?.type == .patientConnected)
        #expect(payload?.patientId == "patient-1")
        #expect(payload?.sessionId == nil)
        #expect(payload?.resourceId == nil)
        #expect(
            NotificationRouter.destination(from: payload!) == .patientDetail(patientId: "patient-1")
        )
        #expect(
            NotificationInboxCopy.message(for: .patientConnected) == L10n.notificationPatientConnected
        )
        #expect(
            NotificationInboxCopy.message(for: .patientConnected) != L10n.notificationGenericTitle
        )
        #expect(
            NotificationInboxCopy.message(for: .questionnaireCompleted)
                == L10n.notificationQuestionnaireCompleted
        )
    }

    @Test func patientConnectedInboxAndPushSharePatientDetailRoute() {
        let notification = AppNotification(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            type: .patientConnected,
            patientId: "patient-1",
            sessionId: nil,
            assignmentId: nil,
            resourceType: nil,
            resourceId: nil,
            createdAt: Date(),
            seenAt: nil,
            readAt: nil
        )
        let fromRecord = NotificationRouter.destination(from: notification)
        let fromPush = NotificationRouter.destination(from: AppNotificationPayload.from(userInfo: [
            "type": "patient_connected",
            "notificationId": "11111111-1111-1111-1111-111111111111",
            "patientId": "patient-1",
        ])!)
        #expect(fromRecord == fromPush)
        #expect(fromRecord == .patientDetail(patientId: "patient-1"))
    }

    @Test func patientConnectedWithoutPatientDoesNotRoute() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "patient_connected",
            "notificationId": "11111111-1111-1111-1111-111111111111",
        ])!
        #expect(NotificationRouter.destination(from: payload) == .none)
    }

    @Test func patientConnectedResolvesLocalNameAndGenericFallback() {
        let named = Patient(id: .text("patient-1"))
        named.localName = "דני"
        #expect(
            NotificationPatientName.resolve(patientId: "patient-1", patients: [named]) == "דני"
        )
        #expect(
            NotificationPatientName.resolve(patientId: "missing", patients: [named])
                == L10n.notificationGenericPatient
        )
        #expect(
            NotificationPatientName.resolve(patientId: nil, patients: [named])
                == L10n.notificationGenericPatient
        )
    }
}

struct DiaryOneNotificationRoutingTests {
    private let patientID = "22222222-2222-2222-2222-222222222222"
    private let entryID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    private let assignmentID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!

    @Test func diaryOneAssignedDecodesExplicitTypeAndRoutesInPatientMode() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "diary_1_assigned",
            "notificationId": "11111111-1111-1111-1111-111111111111",
            "patientId": patientID,
            "assignmentId": assignmentID.uuidString,
            "resourceType": "assignment",
            "resourceId": assignmentID.uuidString,
        ])
        #expect(payload?.type == .diaryOneAssigned)
        #expect(payload?.type.routesInPatientMode == true)
        #expect(NotificationRouter.destination(from: payload!) == .none)
        #expect(
            PatientDiaryOneAssignedRouter.destination(from: payload!)
                == .entryForm(assignmentId: assignmentID)
        )
        #expect(PatientMessageRouter.destination(from: payload!) == .none)
    }

    @Test func diaryOneEntryAddedDecodesExplicitTypeAndExactEntryDestination() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "diary_1_entry_added",
            "notificationId": "11111111-1111-1111-1111-111111111111",
            "patientId": patientID,
            "resourceType": "diary_one_entry",
            "resourceId": entryID.uuidString,
        ])
        #expect(payload?.type == .diaryOneEntryAdded)
        #expect(payload?.type.routesInPatientMode == false)
        #expect(
            NotificationRouter.destination(from: payload!)
                == .diaryOneEntry(
                    patientId: patientID,
                    resourceType: "diary_one_entry",
                    resourceId: entryID.uuidString
                )
        )
        #expect(
            DiaryOneNotificationFocus.entryID(
                resourceType: "diary_one_entry",
                resourceId: entryID.uuidString
            ) == entryID
        )
        #expect(PatientMessageRouter.destination(from: payload!) == .none)
        #expect(PatientDiaryOneAssignedRouter.destination(from: payload!) == .none)
        #expect(
            NotificationInboxCopy.message(for: .diaryOneEntryAdded)
                == L10n.notificationDiaryOneEntryAdded
        )
    }

    @Test func invalidResourceIdDoesNotCrashAndDoesNotOpenEntry() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "diary_1_entry_added",
            "patientId": patientID,
            "resourceType": "diary_one_entry",
            "resourceId": "not-a-uuid",
        ])!
        #expect(payload.type == .diaryOneEntryAdded)
        #expect(
            NotificationRouter.destination(from: payload)
                == .diaryOneEntry(
                    patientId: patientID,
                    resourceType: "diary_one_entry",
                    resourceId: "not-a-uuid"
                )
        )
        #expect(
            DiaryOneNotificationFocus.entryID(
                resourceType: "diary_one_entry",
                resourceId: "not-a-uuid"
            ) == nil
        )
    }

    @Test func wrongOrMissingResourceTypeDoesNotOpenEntry() {
        #expect(
            DiaryOneNotificationFocus.entryID(
                resourceType: "assignment",
                resourceId: entryID.uuidString
            ) == nil
        )
        #expect(
            DiaryOneNotificationFocus.entryID(
                resourceType: nil,
                resourceId: entryID.uuidString
            ) == nil
        )
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "diary_1_entry_added",
            "patientId": patientID,
            "assignmentId": assignmentID.uuidString,
            "resourceType": "assignment",
            "resourceId": assignmentID.uuidString,
        ])!
        let destination = NotificationRouter.destination(from: payload)
        #expect(
            destination == .diaryOneEntry(
                patientId: patientID,
                resourceType: "assignment",
                resourceId: assignmentID.uuidString
            )
        )
        if case .diaryOneEntry(_, let resourceType, let resourceId) = destination {
            #expect(DiaryOneNotificationFocus.entryID(resourceType: resourceType, resourceId: resourceId) == nil)
        } else {
            Issue.record("expected diaryOneEntry destination")
        }
    }

    @Test func entryLookupValidatesPatientOwnershipAndMissingEntry() {
        let patient = DatabaseID.text(patientID)
        let other = DatabaseID.text("33333333-3333-3333-3333-333333333333")
        let owned = DiaryOneEntry(
            id: entryID,
            patientId: patient,
            therapistId: UUID(),
            createdBy: .patient,
            event: "e",
            thought: "t",
            feelings: [],
            behaviour: "b",
            physicalSymptoms: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        #expect(DiaryOneEntryLookup.accepted(owned, for: patient)?.id == entryID)
        #expect(DiaryOneEntryLookup.accepted(owned, for: other) == nil)
        #expect(DiaryOneEntryLookup.accepted(nil, for: patient) == nil)
    }

    @Test func missingPatientDoesNotRouteTherapistDiaryEntry() {
        let payload = AppNotificationPayload.from(userInfo: [
            "type": "diary_1_entry_added",
            "resourceType": "diary_one_entry",
            "resourceId": entryID.uuidString,
        ])!
        #expect(NotificationRouter.destination(from: payload) == .none)
    }

    @Test func matchingAssignmentRequiresExactOpenDiaryOne() {
        let matching = PatientAssignment(
            id: assignmentID,
            patientId: UUID(uuidString: patientID)!,
            therapistId: nil,
            sessionId: nil,
            typeValue: PatientAssignmentType.diaryOne.rawValue,
            createdAt: Date(),
            completedAt: nil,
            cancelledAt: nil
        )
        let otherType = PatientAssignment(
            id: assignmentID,
            patientId: UUID(uuidString: patientID)!,
            therapistId: nil,
            sessionId: nil,
            typeValue: PatientAssignmentType.questionnaire.rawValue,
            createdAt: Date(),
            completedAt: nil,
            cancelledAt: nil
        )
        let cancelled = PatientAssignment(
            id: assignmentID,
            patientId: UUID(uuidString: patientID)!,
            therapistId: nil,
            sessionId: nil,
            typeValue: PatientAssignmentType.diaryOne.rawValue,
            createdAt: Date(),
            completedAt: nil,
            cancelledAt: Date()
        )
        let differentID = PatientAssignment(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            patientId: UUID(uuidString: patientID)!,
            therapistId: nil,
            sessionId: nil,
            typeValue: PatientAssignmentType.diaryOne.rawValue,
            createdAt: Date(),
            completedAt: nil,
            cancelledAt: nil
        )
        #expect(
            PatientDiaryOneAssignedRouter.matchingAssignment(
                in: [differentID, matching],
                assignmentId: assignmentID
            )?.id == assignmentID
        )
        #expect(
            PatientDiaryOneAssignedRouter.matchingAssignment(
                in: [otherType],
                assignmentId: assignmentID
            ) == nil
        )
        #expect(
            PatientDiaryOneAssignedRouter.matchingAssignment(
                in: [cancelled],
                assignmentId: assignmentID
            ) == nil
        )
        #expect(
            PatientDiaryOneAssignedRouter.matchingAssignment(
                in: [differentID],
                assignmentId: assignmentID
            ) == nil
        )
    }

    @Test func existingQuestionnaireConnectedAndMessageRoutingUnchanged() {
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
        #expect(questionnaire.type.routesInPatientMode == false)
        let connected = AppNotificationPayload.from(userInfo: [
            "type": "patient_connected",
            "patientId": "patient-1",
        ])!
        #expect(
            NotificationRouter.destination(from: connected) == .patientDetail(patientId: "patient-1")
        )
        let message = AppNotificationPayload.from(userInfo: [
            "type": "message_received",
            "patientId": patientID,
            "resourceType": "message",
            "resourceId": entryID.uuidString,
        ])!
        #expect(NotificationRouter.destination(from: message) == .none)
        #expect(message.type.routesInPatientMode == true)
        #expect(PatientMessageRouter.destination(from: message) == .exact(entryID))
    }

    @Test func diaryOneEntryAddedSeenReadSemanticsUnchanged() {
        let unread = AppNotification(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            type: .diaryOneEntryAdded,
            patientId: patientID,
            sessionId: nil,
            assignmentId: nil,
            resourceType: "diary_one_entry",
            resourceId: entryID.uuidString,
            createdAt: Date(timeIntervalSince1970: 100),
            seenAt: nil,
            readAt: nil
        )
        #expect(unread.isUnseen)
        #expect(unread.isUnread)
        let seenAt = Date(timeIntervalSince1970: 150)
        let afterSeen = NotificationSeenAcknowledgement.applying([unread], seenAt: seenAt)
        #expect(NotificationCounts.unseen(afterSeen) == 0)
        #expect(NotificationCounts.unread(afterSeen) == 1)
        #expect(afterSeen[0].readAt == nil)
        let opened = unread.opened(at: Date(timeIntervalSince1970: 200))
        #expect(!opened.isUnread)
        #expect(!opened.isUnseen)
        #expect(NotificationRouter.destination(from: opened) != .none)
        #expect(
            NotificationInboxSeenPolicy.shouldMarkSeen(isInboxVisible: true, unseenCount: 1)
        )
    }
}

struct NotificationInboxSemanticsTests {
    private func item(
        id: String,
        created: Date,
        seenAt: Date? = nil,
        readAt: Date? = nil
    ) -> AppNotification {
        AppNotification(
            id: UUID(uuidString: id)!,
            type: .questionnaireCompleted,
            patientId: "patient-1",
            sessionId: nil,
            assignmentId: nil,
            resourceType: "questionnaire",
            resourceId: "42",
            createdAt: created,
            seenAt: seenAt,
            readAt: readAt
        )
    }

    @Test func unseenUnreadSeenUnreadAndReadStates() {
        let unseenUnread = item(
            id: "11111111-1111-1111-1111-111111111111",
            created: Date(timeIntervalSince1970: 100)
        )
        let seenUnread = item(
            id: "22222222-2222-2222-2222-222222222222",
            created: Date(timeIntervalSince1970: 200),
            seenAt: Date(timeIntervalSince1970: 250)
        )
        let read = item(
            id: "33333333-3333-3333-3333-333333333333",
            created: Date(timeIntervalSince1970: 50),
            seenAt: Date(timeIntervalSince1970: 60),
            readAt: Date(timeIntervalSince1970: 80)
        )
        #expect(unseenUnread.isUnseen)
        #expect(unseenUnread.isUnread)
        #expect(!seenUnread.isUnseen)
        #expect(seenUnread.isUnread)
        #expect(!read.isUnseen)
        #expect(!read.isUnread)
        #expect(NotificationInboxSections.unread([unseenUnread, seenUnread, read]).map(\.id) == [
            seenUnread.id, unseenUnread.id
        ])
        #expect(NotificationInboxSections.read([unseenUnread, seenUnread, read]).map(\.id) == [read.id])
    }

    @Test func unseenCountIgnoresSeenRowsUnreadCountIgnoresReadRows() {
        let unseenUnread = item(
            id: "11111111-1111-1111-1111-111111111111",
            created: Date(timeIntervalSince1970: 100)
        )
        let seenUnread = item(
            id: "22222222-2222-2222-2222-222222222222",
            created: Date(timeIntervalSince1970: 200),
            seenAt: Date(timeIntervalSince1970: 250)
        )
        let read = item(
            id: "33333333-3333-3333-3333-333333333333",
            created: Date(timeIntervalSince1970: 50),
            seenAt: Date(timeIntervalSince1970: 60),
            readAt: Date(timeIntervalSince1970: 80)
        )
        let items = [unseenUnread, seenUnread, read]
        #expect(NotificationCounts.unseen(items) == 1)
        #expect(NotificationCounts.unread(items) == 2)
    }

    @Test func groupingPutsUnreadAndReadInNewestFirstSections() {
        let olderUnread = item(
            id: "11111111-1111-1111-1111-111111111111",
            created: Date(timeIntervalSince1970: 100)
        )
        let newerUnread = item(
            id: "22222222-2222-2222-2222-222222222222",
            created: Date(timeIntervalSince1970: 300)
        )
        let olderRead = item(
            id: "33333333-3333-3333-3333-333333333333",
            created: Date(timeIntervalSince1970: 50),
            readAt: Date(timeIntervalSince1970: 80)
        )
        let newerRead = item(
            id: "44444444-4444-4444-4444-444444444444",
            created: Date(timeIntervalSince1970: 200),
            readAt: Date(timeIntervalSince1970: 250)
        )
        let items = [olderUnread, newerRead, newerUnread, olderRead]
        let unread = NotificationInboxSections.unread(items)
        let read = NotificationInboxSections.read(items)
        #expect(unread.map(\.id) == [newerUnread.id, olderUnread.id])
        #expect(read.map(\.id) == [newerRead.id, olderRead.id])
    }

    @Test func acknowledgingInboxClearsUnseenWithoutChangingReadAt() {
        let unread = item(
            id: "11111111-1111-1111-1111-111111111111",
            created: Date(timeIntervalSince1970: 100)
        )
        let seenAt = Date(timeIntervalSince1970: 150)
        let after = NotificationSeenAcknowledgement.applying([unread], seenAt: seenAt)
        #expect(NotificationCounts.unseen(after) == 0)
        #expect(NotificationCounts.unread(after) == 1)
        #expect(after[0].readAt == nil)
        #expect(after[0].seenAt == seenAt)
        #expect(NotificationInboxSections.unread(after).map(\.id) == [unread.id])
    }

    @Test func newUnseenRowAfterAcknowledgementCountsAgain() {
        let first = item(
            id: "11111111-1111-1111-1111-111111111111",
            created: Date(timeIntervalSince1970: 100)
        )
        let acknowledged = NotificationSeenAcknowledgement.applying(
            [first],
            seenAt: Date(timeIntervalSince1970: 150)
        )
        let second = item(
            id: "22222222-2222-2222-2222-222222222222",
            created: Date(timeIntervalSince1970: 200)
        )
        let items = acknowledged + [second]
        #expect(NotificationCounts.unseen(items) == 1)
        #expect(NotificationCounts.unread(items) == 2)
    }

    @Test func markingOneReadLeavesOthersUnreadAndTreatsItAsSeen() {
        let first = item(
            id: "11111111-1111-1111-1111-111111111111",
            created: Date(timeIntervalSince1970: 100)
        )
        let second = item(
            id: "22222222-2222-2222-2222-222222222222",
            created: Date(timeIntervalSince1970: 200)
        )
        let opened = first.opened(at: Date(timeIntervalSince1970: 300))
        let items = [opened, second]
        #expect(opened.seenAt != nil)
        #expect(opened.readAt != nil)
        #expect(NotificationInboxSections.read(items).map(\.id) == [first.id])
        #expect(NotificationInboxSections.unread(items).map(\.id) == [second.id])
        #expect(second.readAt == nil)
        #expect(second.seenAt == nil)
        #expect(NotificationRouter.destination(from: opened) != .none)
    }

    @Test func failedMarkReadKeepsRowUnreadAndDestinationStillExists() {
        let unread = item(
            id: "11111111-1111-1111-1111-111111111111",
            created: Date(timeIntervalSince1970: 100)
        )
        let destination = NotificationRouter.destination(from: unread)
        #expect(unread.isUnread)
        #expect(unread.isUnseen)
        #expect(destination != .none)
    }

    @Test func refreshMappingDoesNotInventSeenAt() {
        let fetched = item(
            id: "11111111-1111-1111-1111-111111111111",
            created: Date(timeIntervalSince1970: 100),
            seenAt: nil,
            readAt: nil
        )
        #expect(fetched.isUnseen)
        #expect(NotificationCounts.unseen([fetched]) == 1)
    }

    @Test func enteringInboxMarksSeenWhenUnseenExistButDoesNotMarkRead() {
        #expect(
            NotificationInboxSeenPolicy.shouldMarkSeen(isInboxVisible: true, unseenCount: 3)
        )
        let items = [
            item(id: "11111111-1111-1111-1111-111111111111", created: Date(timeIntervalSince1970: 100)),
            item(id: "22222222-2222-2222-2222-222222222222", created: Date(timeIntervalSince1970: 200)),
        ]
        let after = NotificationSeenAcknowledgement.applying(items, seenAt: Date(timeIntervalSince1970: 300))
        #expect(NotificationCounts.unseen(after) == 0)
        #expect(NotificationCounts.unread(after) == 2)
        #expect(after.allSatisfy { $0.readAt == nil })
    }

    @Test func refreshOnAnotherTabDoesNotMarkSeen() {
        #expect(
            !NotificationInboxSeenPolicy.shouldMarkSeen(isInboxVisible: false, unseenCount: 3)
        )
        #expect(
            !NotificationInboxSeenPolicy.shouldMarkSeen(isInboxVisible: true, unseenCount: 0)
        )
    }
}
