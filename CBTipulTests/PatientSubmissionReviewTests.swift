import Foundation
import Testing
@testable import CBTipul

@MainActor
struct PatientSubmissionReviewTests {
    @Test func questionnaireReviewContainsAllAnswersButNoTherapistNotes() {
        var questionnaire = CombinedMoodQuestionnaire()
        questionnaire.gad7Answers = Array(repeating: 1, count: 7)
        questionnaire.phq9Answers = Array(repeating: 2, count: 9)
        questionnaire.interferenceLevel = 3
        questionnaire.gad7Notes = Array(repeating: "Private clinician note", count: 7)
        let review = questionnaire.reviewSections
        #expect(review.count == 17)
        #expect(review.first?.lines == [L10n.answerDescriptions[1]])
        #expect(review[7].lines == [L10n.answerDescriptions[2]])
        #expect(review.last?.lines == [L10n.phq9InterferenceOptions[3]])
        #expect(!review.flatMap(\.lines).contains("Private clinician note"))
    }

    @Test func diaryReviewIncludesOptionalBodySensationsAndEveryThought() {
        var diary = DiaryOneEntryDraft.empty
        diary.event = "Event"
        diary.automaticThoughts = [.init(text: "First"), .init(text: "Second")]
        diary.behaviour = "Response"
        diary.physicalSymptoms = "Tension"
        let sections = diary.reviewSections
        #expect(sections.count == 5)
        #expect(sections[1].lines == ["First", "Second"])
        #expect(sections[4].lines == ["Tension"])
    }

    @Test func sessionRecoverySurvivesNewDraftInstanceAndStaysAccountScoped() throws {
        let storage = DeviceDraftStorage(service: "CBTipul.tests.session-recovery.\(UUID())")
        let value = SessionRecovery(date: Date(timeIntervalSince1970: 1234567), notes: "Unfinished notes", type: .intake, structuredNotes: nil, selectedPatientID: .text("patient-a"))
        let first = DeviceFormDraft<SessionRecovery>(storage: storage)
        #expect(first.restore(userID: "account-a", kind: "therapist-session", target: "new:global") == nil)
        #expect(first.save(value, isEmpty: false))
        let restored = DeviceFormDraft<SessionRecovery>(storage: storage)
        #expect(restored.restore(userID: "account-a", kind: "therapist-session", target: "new:global") == value)
        let other = DeviceFormDraft<SessionRecovery>(storage: storage)
        #expect(other.restore(userID: "account-b", kind: "therapist-session", target: "new:global") == nil)
        #expect(restored.discard())
        let cleared = DeviceFormDraft<SessionRecovery>(storage: storage)
        #expect(cleared.restore(userID: "account-a", kind: "therapist-session", target: "new:global") == nil)
    }
}
