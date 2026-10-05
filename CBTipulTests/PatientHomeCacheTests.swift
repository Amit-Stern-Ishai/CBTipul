import Foundation
import Testing
@testable import CBTipul

@MainActor @Suite(.serialized)
struct PatientHomeCacheTests {
    @Test func visibilityRequiresActivationOrHistory() {
        let empty = PatientHomeSnapshot(questionnaires: [], diaryOne: [], diaryTwo: [], diaryThree: [])
        for type: PatientAssignmentType in [.questionnaire, .diaryOne, .diaryTwo, .diaryThree] {
            #expect(!empty.isVisible(type, active: false))
            #expect(empty.isVisible(type, active: true))
        }
        let history = PatientHomeSnapshot(questionnaires: [CompletedQuestionnaire(databaseID: .integer(91), sessionID: nil, answeredDate: Date(), questionnaire: CombinedMoodQuestionnaire())])
        #expect(history.isVisible(.questionnaire, active: false))
        #expect(!history.isVisible(.diaryOne, active: false))
    }

    @Test func cacheIsScopedAndRejectsLateResults() {
        defer { PatientHomeCache.clear() }
        _ = PatientHomeCache.read(key: "account:patient")
        PatientHomeCache.save(PatientHomeSnapshot(assignments: [], diaryOne: []), key: "account:patient")
        #expect(PatientHomeCache.read(key: "account:patient").diaryOne?.isEmpty == true)
        #expect(PatientHomeCache.read(key: "account:other").assignments == nil)
        PatientHomeCache.save(PatientHomeSnapshot(assignments: []), key: "account:patient")
        #expect(PatientHomeCache.read(key: "account:other").assignments == nil)
        PatientHomeCache.save(PatientHomeSnapshot(assignments: []), key: "account:other")
        #expect(PatientHomeCache.read(key: "other-account:other").assignments == nil)
    }
}
