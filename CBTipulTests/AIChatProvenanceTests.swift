import Foundation
import Testing
@testable import CBTipul

@MainActor
struct AIChatProvenanceTests {
    @Test func clinicalContextCarriesProvenanceWithoutLosingContentOrIdentityLeak() throws {
        let analysis = try JSONDecoder().decode(WhisperService.CBTSessionAnalysis.self, from: Data(#"{"session_summary":"review-summary","key_situations":[],"possible_nats":[{"thought":"possible-thought","situation":"trigger","emotion":"emotion","behavior":"behavior","source":"inferred","confidence":"medium","cognitive_patterns":[]}],"cbt_cycles":[{"trigger_situation":"cycle-trigger","automatic_thought":"cycle-thought","emotion":"cycle-emotion","behavior":"cycle-behavior","short_term_consequence":"short-effect","long_term_consequence":"long-effect","evidence":"evidence","confidence":"medium"}],"therapist_hypotheses":[{"hypothesis":"ai-hypothesis","evidence":"evidence","confidence":"low"}],"follow_up_questions":[{"question":"open-question","reason":"reason"},{"question":"closed-question","reason":"reason","status":"discussed"}],"assignments_for_next_week":[{"assignment":"homework","details":"homework-details"}]}"#.utf8))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let patient = Patient(id: .integer(73), firstName: "PRIVATE_DISPLAY_NAME", notes: "general-notes",
            sessions: [Session(date: date, notes: "raw-notes", type: .intake, structuredNotes: analysis)])
        patient.formulation = PatientFormulation(treatmentGoal: "goal", coreBelief: "core-belief",
            keyAutomaticThoughts: ["key-thought"], maintainingBehaviors: ["maintaining-behavior"],
            keyCBTCycle: nil, therapistHypothesis: "formulation-hypothesis")
        var q = CombinedMoodQuestionnaire()
        q.gad7Answers[0] = 2
        q.phq9Answers[0] = 1
        q.gad7Notes[0] = "question-note"
        q.interferenceLevel = 1
        q.interferenceNote = "interference-note"
        let result = PatientAIView(patient: patient).fullContext(questionnaires: [
            CompletedQuestionnaire(databaseID: .integer(74), sessionID: nil, answeredDate: date, questionnaire: q)
        ])
        #expect(result.contains("Patient notes (general, not tied to a session):\nsource: therapist\ngeneral-notes"))
        #expect(result.contains("source: therapist\nmaterialType: therapist_formulation (clinical formulation, not established facts)"))
        #expect(result.contains("Raw session notes (source: therapist): raw-notes"))
        #expect(result.contains("Previous structured AI review (source: ai_generated; applies to all content in this review)"))
        #expect(result.contains("AI-generated hypotheses:"))
        #expect(result.contains("field-level edit history is unavailable"))
        #expect(!result.contains("Therapist hypotheses:"))
        #expect(result.contains("Questionnaires:\nsource: patient_reported_measurement"))
        #expect(result.contains("Session date: \(date.formatted(date: .numeric, time: .omitted))"))
        #expect(result.contains("GAD-7 total: 2"))
        #expect(result.contains("PHQ-9 total: 1"))
        #expect(!result.contains("PRIVATE_DISPLAY_NAME"))
        #expect(!result.contains("closed-question"))
        for value in ["review-summary", "possible-thought", "cycle-trigger", "cycle-thought", "cycle-emotion", "cycle-behavior", "short-effect", "long-effect", "ai-hypothesis", "open-question", "homework", "homework-details", "general-notes", "raw-notes", "goal", "core-belief", "formulation-hypothesis", "key-thought", "maintaining-behavior", "question-note", "interference-note"] {
            #expect(result.contains(value))
        }
    }

    @Test func diariesPreserveAuthorsRecordingTimeAndClinicalFields() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let id = DatabaseID.integer(73)
        let owner = UUID()
        let one = DiaryOneEntry(id: UUID(), patientId: id, therapistId: owner, createdBy: .patient,
            event: "event-one", automaticThoughts: ["thought-one"], feelings: [.init(name: "sad", intensity: 0)],
            behaviour: "behavior-one", physicalSymptoms: "physical-one", createdAt: date, updatedAt: date)
        let two = DiaryTwoEntry(id: UUID(), patientId: id, therapistId: owner, createdBy: .therapist,
            event: "event-two", automaticThoughts: ["thought-two"], feelings: [.init(name: "angry", intensity: 80)],
            thinkingErrors: [.allOrNothing], alternativeThoughts: ["alternative-two"], createdAt: date, updatedAt: date)
        let three = DiaryThreeEntry(id: UUID(), patientId: id, therapistId: owner, createdBy: .patient,
            situation: "situation-three", automaticThoughts: [.init(text: "thought-three", beliefBefore: 90, beliefAfter: 20)],
            feelings: [.init(name: "fear", intensityBefore: 80, intensityAfter: 10)], thinkingErrors: [.allOrNothing],
            alternativeThoughts: [.init(text: "alternative-three", belief: 70)], createdAt: date, updatedAt: date)
        let result = PatientAIView.diaryContext(one: [one], two: [two], three: [three], unavailable: [])
        #expect(result.contains("Diary 1\nauthor: patient\nrecordedAt:"))
        #expect(result.contains("Diary 2\nauthor: therapist\nrecordedAt:"))
        #expect(result.contains("Diary 3\nauthor: patient\nrecordedAt:"))
        #expect(result.components(separatedBy: "recordedAtMeaning: record creation time; the described event may have occurred at another time").count == 4)
        #expect(!result.contains(owner.uuidString))
        #expect(result.contains(date.ISO8601Format()))
        for value in ["event-one", "thought-one", "sad: 0%", "behavior-one", "physical-one", "event-two", "thought-two", "angry: 80%", "all_or_nothing", "alternative-two", "situation-three", "thought-three", "belief before: 90%, after: 20%", "intensity before: 80%, after: 10%", "alternative-three", "belief: 70%"] {
            #expect(result.contains(value))
        }
    }

    @Test func unavailableDiaryRemainsUnknown() {
        let warning = "Diary 2 could not be loaded. Its history is unknown; do not infer that it is empty."
        let result = PatientAIView.diaryContext(one: [], two: [], three: [], unavailable: [warning])
        #expect(result.contains(warning))
        #expect(result.contains("No entries in successfully loaded diaries."))
    }
}
