import Foundation
import Testing
import UserNotifications
@testable import CBTipul

@MainActor @Suite(.serialized)
struct DiaryTwoNotificationTests {
    let patient = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let target = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    func payload(_ type: String = "diary_2_assigned", resource: String = "assignment", id: String? = nil) -> AppNotificationPayload {
        AppNotificationPayload(typeRaw: type, notificationId: UUID().uuidString, patientId: patient.uuidString,
            sessionId: nil, assignmentId: id ?? target.uuidString, resourceType: resource, resourceId: id ?? target.uuidString)
    }
    func assignment(type: String = "diary_two", id: UUID? = nil, patientId: UUID? = nil, cancelled: Bool = false) -> PatientAssignment {
        PatientAssignment(id: id ?? target, patientId: patientId ?? patient, therapistId: nil, sessionId: nil,
            typeValue: type, createdAt: Date(), completedAt: Date(), cancelledAt: cancelled ? Date() : nil)
    }
    @Test func explicitParsingAndPatientTherapistSeparation() throws {
        let assigned = try #require(AppNotificationPayload.from(userInfo: ["data": ["type": "diary_2_assigned", "patientId": patient.uuidString, "assignmentId": target.uuidString, "resourceType": "assignment", "resourceId": target.uuidString]]))
        #expect(assigned.type == .diaryTwoAssigned)
        #expect(assigned.type.routesInPatientMode)
        #expect(NotificationRouter.destination(from: assigned) == .none)
        let entry = payload("diary_2_entry_added", resource: "diary_two_entry")
        #expect(entry.type == .diaryTwoEntryAdded)
        #expect(!entry.type.routesInPatientMode)
        #expect(NotificationRouter.destination(from: entry) == .diaryTwoEntry(patientId: patient.uuidString, resourceType: "diary_two_entry", resourceId: target.uuidString))
        #expect(NotificationRouter.destination(from: payload("future")) == .none)
    }
    @Test func assignmentRefreshResolvesExactActiveTypeAndIdentityOrFallsBack() async {
        var calls = 0
        let resolved = await PatientDiaryTwoAssignedRouter.resolve(payload: payload(), patientId: patient) {
            calls += 1; return [assignment(id: UUID()), assignment()]
        }
        #expect(calls == 1)
        #expect(resolved?.id == target) // ongoing activity is cancelledAt, not completedAt
        for rows in [[], [assignment(type: "diary_one")], [assignment(cancelled: true)], [assignment(patientId: UUID())], [assignment(id: UUID())]] as [[PatientAssignment]] {
            let rejected = await PatientDiaryTwoAssignedRouter.resolve(payload: payload(), patientId: patient) { calls += 1; return rows }
            #expect(rejected == nil)
        }
        #expect(calls == 6)
        let failed = await PatientDiaryTwoAssignedRouter.resolve(payload: payload(), patientId: patient) { throw URLError(.notConnectedToInternet) }
        #expect(failed == nil)
        #expect(PatientDiaryTwoAssignedRouter.matchingAssignment(in: [assignment()], payload: payload(id: "bad"), patientId: patient) == nil)
        #expect(PatientDiaryTwoAssignedRouter.matchingAssignment(in: [assignment()], payload: payload(resource: "diary_one_entry"), patientId: patient) == nil)
    }
    @Test func coldPatientRouteWaitsForReadinessAndConsumesOnlyOnce() {
        let coordinator = PatientModeMessageCoordinator.shared
        coordinator.markNotReady()
        let info: [AnyHashable: Any] = ["type": "diary_2_assigned", "notificationId": UUID().uuidString,
            "patientId": patient.uuidString, "assignmentId": target.uuidString, "resourceType": "assignment", "resourceId": target.uuidString]
        coordinator.handlePushTap(userInfo: info)
        #expect(coordinator.consumePending() == nil)
        coordinator.markReady()
        guard case .diaryTwoAssigned(let pending) = coordinator.consumePending() else { Issue.record("Missing direct Diary 2 route"); return }
        #expect(pending.assignmentId == target.uuidString)
        #expect(coordinator.consumePending() == nil)
        coordinator.handlePushTap(userInfo: info)
        #expect(coordinator.consumePending() == nil)
        coordinator.markNotReady()
    }
    @Test func therapistFocusRejectsWrongResourceAndMalformedId() {
        #expect(DiaryTwoNotificationFocus.entryID(resourceType: "diary_two_entry", resourceId: target.uuidString) == target)
        #expect(DiaryTwoNotificationFocus.entryID(resourceType: "diary_one_entry", resourceId: target.uuidString) == nil)
        #expect(DiaryTwoNotificationFocus.entryID(resourceType: "diary_two_entry", resourceId: "1-1-1-1-1") == nil)
        #expect(DiaryTwoNotificationFocus.entryID(resourceType: "diary_two_entry", resourceId: nil) == nil)
    }
    @Test func exactEntryValidationRejectsWrongPatientWrongEntryAndDeletedEntry() {
        let entry = DiaryTwoEntry(id: target, patientId: .text(patient.uuidString), therapistId: UUID(), createdBy: .patient,
            event: "private", automaticThoughts: ["private"], feelings: [], thinkingErrors: [], alternativeThoughts: [], createdAt: Date(), updatedAt: Date())
        #expect(DiaryTwoEntryLookup.accepted(entry, id: target, patientId: entry.patientId) == entry)
        #expect(DiaryTwoEntryLookup.accepted(entry, id: UUID(), patientId: entry.patientId) == nil)
        #expect(DiaryTwoEntryLookup.accepted(entry, id: target, patientId: .text(UUID().uuidString)) == nil)
        #expect(DiaryTwoEntryLookup.accepted(nil, id: target, patientId: entry.patientId) == nil)
    }
    @Test func inboxSeenDoesNotReadAndTapReadsOnlyOneDiaryTwoRow() {
        let items = (0..<2).map { index in AppNotification(id: UUID(), type: .diaryTwoEntryAdded, patientId: patient.uuidString,
            sessionId: nil, assignmentId: nil, resourceType: "diary_two_entry", resourceId: target.uuidString,
            createdAt: Date(timeIntervalSince1970: Double(index)), seenAt: nil, readAt: nil) }
        #expect(NotificationCounts.unseen(items) == 2)
        var seen = NotificationSeenAcknowledgement.applying(items, seenAt: Date())
        #expect(NotificationCounts.unseen(seen) == 0)
        #expect(NotificationInboxSections.unread(seen).count == 2)
        seen[0] = seen[0].opened(at: Date())
        #expect(NotificationInboxSections.unread(seen).map(\.id) == [items[1].id])
        #expect(NotificationInboxSections.read(seen).map(\.id) == [items[0].id])
        #expect(NotificationInboxCopy.message(for: .diaryTwoEntryAdded) == "הוסיף/ה רשומה חדשה ליומן מחשבות 2")
    }
    @Test func pushCopyUsesLocalNameAndGenericFallbackNeverClinicalServerCopy() {
        for localName in ["דני", nil] as [String?] {
            let content = UNMutableNotificationContent()
            content.title = "server name"; content.body = "private clinical text"; content.subtitle = "private"
            content.userInfo = ["type": "diary_2_entry_added", "patientId": patient.uuidString, "resourceId": target.uuidString]
            PatientPushPersonalizer.apply(to: content, nameForPatientId: { _ in localName })
            #expect(content.title == (localName ?? "מטופל/ת"))
            #expect(content.body == "הוסיף/ה רשומה חדשה ליומן מחשבות 2")
            #expect(content.subtitle.isEmpty)
            #expect(content.userInfo.count == 3)
        }
    }
}
