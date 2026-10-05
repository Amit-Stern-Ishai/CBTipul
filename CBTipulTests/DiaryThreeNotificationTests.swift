import Foundation
import Testing
import UserNotifications
@testable import CBTipul

@MainActor @Suite(.serialized)
struct DiaryThreeNotificationTests {
    let patient = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let target = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    func payload(_ type: String = "diary_3_assigned", resource: String = "assignment", id: String? = nil) -> AppNotificationPayload {
        AppNotificationPayload(typeRaw: type, notificationId: UUID().uuidString, patientId: patient.uuidString,
            sessionId: nil, assignmentId: id ?? target.uuidString, resourceType: resource, resourceId: id ?? target.uuidString)
    }
    func assignment(type: String = "diary_three", id: UUID? = nil, patientId: UUID? = nil, cancelled: Bool = false) -> PatientAssignment {
        PatientAssignment(id: id ?? target, patientId: patientId ?? patient, therapistId: nil, sessionId: nil,
            typeValue: type, createdAt: Date(), completedAt: Date(), cancelledAt: cancelled ? Date() : nil)
    }
    @Test func explicitParsingAndPatientTherapistSeparation() throws {
        let assigned = try #require(AppNotificationPayload.from(userInfo: ["data": ["type": "diary_3_assigned", "patientId": patient.uuidString, "assignmentId": target.uuidString, "resourceType": "assignment", "resourceId": target.uuidString]]))
        #expect(assigned.type == .diaryThreeAssigned)
        #expect(assigned.type.routesInPatientMode)
        #expect(NotificationRouter.destination(from: assigned) == .none)
        let entry = payload("diary_3_entry_added", resource: "diary_three_entry")
        #expect(entry.type == .diaryThreeEntryAdded)
        #expect(!entry.type.routesInPatientMode)
        #expect(NotificationRouter.destination(from: entry) == .diaryThreeEntry(patientId: patient.uuidString, resourceType: "diary_three_entry", resourceId: target.uuidString))
        #expect(NotificationRouter.destination(from: payload("future")) == .none)
    }
    @Test func assignmentRefreshResolvesExactActiveTypeAndIdentityOrFallsBack() async {
        var calls = 0
        let resolved = await PatientDiaryThreeAssignedRouter.resolve(payload: payload(), patientId: patient) {
            calls += 1; return [assignment(id: UUID()), assignment()]
        }
        #expect(calls == 1)
        #expect(resolved?.id == target) // ongoing activity is cancelledAt, not completedAt
        for rows in [[], [assignment(type: "diary_one")], [assignment(cancelled: true)], [assignment(patientId: UUID())], [assignment(id: UUID())]] as [[PatientAssignment]] {
            let rejected = await PatientDiaryThreeAssignedRouter.resolve(payload: payload(), patientId: patient) { calls += 1; return rows }
            #expect(rejected == nil)
        }
        #expect(calls == 6)
        let failed = await PatientDiaryThreeAssignedRouter.resolve(payload: payload(), patientId: patient) { throw URLError(.notConnectedToInternet) }
        #expect(failed == nil)
        #expect(PatientDiaryThreeAssignedRouter.matchingAssignment(in: [assignment()], payload: payload(id: "bad"), patientId: patient) == nil)
        #expect(PatientDiaryThreeAssignedRouter.matchingAssignment(in: [assignment()], payload: payload(resource: "diary_one_entry"), patientId: patient) == nil)
    }
    @Test func coldPatientRouteWaitsForReadinessAndConsumesOnlyOnce() {
        let coordinator = PatientModeMessageCoordinator.shared
        coordinator.markNotReady()
        let info: [AnyHashable: Any] = ["type": "diary_3_assigned", "notificationId": UUID().uuidString,
            "patientId": patient.uuidString, "assignmentId": target.uuidString, "resourceType": "assignment", "resourceId": target.uuidString]
        coordinator.handlePushTap(userInfo: info)
        #expect(coordinator.consumePending() == nil)
        coordinator.markReady()
        guard case .diaryThreeAssigned(let pending) = coordinator.consumePending() else { Issue.record("Missing direct Diary 3 route"); return }
        #expect(pending.assignmentId == target.uuidString)
        #expect(coordinator.consumePending() == nil)
        coordinator.handlePushTap(userInfo: info)
        #expect(coordinator.consumePending() == nil)
        coordinator.markNotReady()
    }
    @Test func serializedDeviceDraftSurvivesAssignmentPushAndFreshDraftStartsAtOne() async throws {
        #expect(PatientDiaryThreeDraft().currentStep == 1)
        var workflow = PatientDiaryThreeDraft()
        workflow.currentStep = 7
        workflow.entry.situation = "device-only draft"
        workflow.entry.automaticThoughts = [.init(text: "original", beliefBefore: 90, beliefAfter: 35)]
        workflow.entry.feelings = [.init(name: "עצוב", intensityBefore: 85, intensityAfter: 40)]
        // Exercise the exact Codable snapshot used by device-only draft storage.
        let saved = try JSONEncoder().encode(workflow)
        let resolved = await PatientDiaryThreeAssignedRouter.resolve(payload: payload(), patientId: patient) { [assignment()] }
        #expect(resolved?.id == target)
        #expect(try JSONDecoder().decode(PatientDiaryThreeDraft.self, from: saved) == workflow)
    }
    @Test func therapistColdStartWaitsForPatientAndInboxReturnsCoherently() {
        let coordinator = TherapistNotificationCoordinator.shared
        coordinator.resetOnLogout()
        defer { coordinator.resetOnLogout() }
        let info: [AnyHashable: Any] = ["type": "diary_3_entry_added", "notificationId": UUID().uuidString,
            "patientId": patient.uuidString, "resourceType": "diary_three_entry", "resourceId": target.uuidString]
        coordinator.handlePushTap(userInfo: info)
        coordinator.processPending(patients: [])
        #expect(coordinator.consumePatientNavigation() == nil)
        coordinator.markTherapistRootReady(); coordinator.processPending(patients: [])
        #expect(coordinator.consumePatientNavigation() == nil)
        let person = Patient(id: .text(patient.uuidString))
        coordinator.processPending(patients: [person])
        #expect(coordinator.consumePatientNavigation()?.diaryThreeRoute?.focusEntryID == target)
        coordinator.handlePushTap(userInfo: info); coordinator.processPending(patients: [person])
        #expect(coordinator.consumePatientNavigation() == nil)
        let notification = AppNotification(id: UUID(), type: .diaryThreeEntryAdded, patientId: patient.uuidString,
            sessionId: nil, assignmentId: nil, resourceType: "diary_three_entry", resourceId: target.uuidString,
            createdAt: Date(), seenAt: nil, readAt: nil)
        coordinator.handleInboxTap(notification, patients: [person])
        #expect(coordinator.consumePatientNavigation()?.diaryThreeRoute?.focusEntryID == target)
        #expect(!coordinator.returnsToInbox)
        coordinator.finishInboxNavigation(); #expect(coordinator.selectedTab == .notifications)
        coordinator.markPatientsLoadSettled()
        coordinator.handleInboxTap(notification, patients: [])
        #expect(coordinator.unavailableTarget); #expect(coordinator.consumePatientNavigation() == nil)
    }
    @Test func therapistFocusRejectsWrongResourceAndMalformedId() {
        #expect(DiaryThreeNotificationFocus.entryID(resourceType: "diary_three_entry", resourceId: target.uuidString) == target)
        #expect(DiaryThreeNotificationFocus.entryID(resourceType: "diary_one_entry", resourceId: target.uuidString) == nil)
        #expect(DiaryThreeNotificationFocus.entryID(resourceType: "diary_three_entry", resourceId: "1-1-1-1-1") == nil)
        #expect(DiaryThreeNotificationFocus.entryID(resourceType: "diary_three_entry", resourceId: nil) == nil)
    }
    @Test func exactEntryValidationRejectsWrongPatientWrongEntryAndDeletedEntry() {
        let entry = DiaryThreeEntry(id: target, patientId: .text(patient.uuidString), therapistId: UUID(), createdBy: .patient,
            situation: "private", automaticThoughts: [], feelings: [], thinkingErrors: [], alternativeThoughts: [], createdAt: Date(), updatedAt: Date())
        #expect(DiaryThreeEntryLookup.accepted(entry, id: target, patientId: entry.patientId) == entry)
        #expect(DiaryThreeEntryLookup.accepted(entry, id: UUID(), patientId: entry.patientId) == nil)
        #expect(DiaryThreeEntryLookup.accepted(entry, id: target, patientId: .text(UUID().uuidString)) == nil)
        #expect(DiaryThreeEntryLookup.accepted(nil, id: target, patientId: entry.patientId) == nil)
    }
    @Test func inboxSeenDoesNotReadAndTapReadsOnlyOneDiaryThreeRow() {
        let items = (0..<2).map { index in AppNotification(id: UUID(), type: .diaryThreeEntryAdded, patientId: patient.uuidString,
            sessionId: nil, assignmentId: nil, resourceType: "diary_three_entry", resourceId: target.uuidString,
            createdAt: Date(timeIntervalSince1970: Double(index)), seenAt: nil, readAt: nil) }
        #expect(NotificationCounts.unseen(items) == 2)
        var seen = NotificationSeenAcknowledgement.applying(items, seenAt: Date())
        #expect(NotificationCounts.unseen(seen) == 0)
        #expect(NotificationInboxSections.unread(seen).count == 2)
        seen[0] = seen[0].opened(at: Date())
        #expect(NotificationInboxSections.unread(seen).map(\.id) == [items[1].id])
        #expect(NotificationInboxSections.read(seen).map(\.id) == [items[0].id])
        #expect(NotificationInboxCopy.message(for: .diaryThreeEntryAdded) == "הוסיף/ה רשומה חדשה ליומן מחשבות 3")
    }
    @Test func pushCopyUsesLocalNameAndGenericFallbackNeverClinicalServerCopy() {
        for localName in ["דני", nil] as [String?] {
            let content = UNMutableNotificationContent()
            content.title = "server name"; content.body = "private clinical text"; content.subtitle = "private"
            content.userInfo = ["type": "diary_3_entry_added", "patientId": patient.uuidString, "resourceId": target.uuidString]
            PatientPushPersonalizer.apply(to: content, nameForPatientId: { _ in localName })
            #expect(content.title == (localName ?? "מטופל/ת"))
            #expect(content.body == "הוסיף/ה רשומה חדשה ליומן מחשבות 3")
            #expect(content.subtitle.isEmpty)
            #expect(content.userInfo.count == 3)
        }
    }
}
