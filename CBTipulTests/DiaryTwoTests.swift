import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor
struct DiaryTwoTests {
    private let patient = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private var raw: String { """
    {"id":"11111111-1111-1111-1111-111111111111","patient_id":"\(patient)",
    "therapist_id":"33333333-3333-3333-3333-333333333333","created_by":"patient",
    "event":"event","automatic_thoughts":["first","second"],"feelings":[{"name":"עצוב","intensity":0}],
    "thinking_errors":["mind_reading","all_or_nothing"],"alternative_thoughts":["alternative one","alternative two"],
    "created_at":"2026-09-01T12:00:00Z","updated_at":"2026-09-02T12:00:00Z"}
    """ }
    private func decoded() throws -> DiaryTwoEntry {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DiaryTwoEntry.self, from: Data(raw.utf8))
    }
    @Test func decodingAndEditRestoreEveryClinicalArray() throws {
        let entry = try decoded()
        #expect(entry.createdBy == .patient)
        #expect(entry.updatedAt > entry.createdAt)
        #expect(entry.patientId.uuidValue == patient)
        #expect(entry.automaticThoughts == ["first", "second"])
        #expect(entry.alternativeThoughts == ["alternative one", "alternative two"])
        #expect(entry.thinkingErrors == [.mindReading, .allOrNothing])
        let draft = DiaryTwoEntryDraft.from(entry)
        #expect(draft.persistedAutomaticThoughts == entry.automaticThoughts)
        #expect(draft.persistedAlternativeThoughts == entry.alternativeThoughts)
        #expect(draft.persistedFeelings() == entry.feelings)
        #expect(draft.thinkingErrors == entry.thinkingErrors)
    }
    @Test func everyThinkingErrorRoundTripsAndUnknownFails() throws {
        let codes = ["all_or_nothing", "overgeneralization", "negative_filter", "discounting_positives", "jumping_to_conclusions", "mind_reading", "fortune_telling", "magnification_minimization", "emotional_reasoning", "should_statements", "labeling", "blame"]
        #expect(ThinkingError.allCases.map(\.rawValue) == codes)
        for error in ThinkingError.allCases {
            #expect(!error.title.isEmpty && !error.explanation.isEmpty)
            #expect(try JSONDecoder().decode(ThinkingError.self, from: JSONEncoder().encode(error)) == error)
        }
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ThinkingError.self, from: Data("\"unknown\"".utf8)) }
    }
    @Test func validationTrimsArraysAndRequiresAllFiveSections() throws {
        var draft = DiaryTwoEntryDraft.from(try decoded())
        draft.automaticThoughts = [.init(text: " first "), .init(text: "  "), .init(text: "second")]
        draft.alternativeThoughts.append(.init(text: "\n"))
        #expect(draft.validationMessage() == nil)
        #expect(draft.persistedAutomaticThoughts == ["first", "second"])
        #expect(draft.persistedAlternativeThoughts.count == 2)
        draft.feelings.append(draft.feelings[0])
        #expect(draft.validationMessage() == L10n.diaryFeelingAlreadySelected)
        draft.feelings.removeLast(); draft.feelings[0].intensity = 101
        #expect(draft.validationMessage() != nil)
        draft.feelings[0].intensity = 100; draft.thinkingErrors = []
        #expect(draft.validationMessage() == L10n.diaryTwoValidationErrors)
        draft.thinkingErrors = [.blame]; draft.alternativeThoughts = [.init()]
        #expect(draft.validationMessage() == L10n.diaryTwoValidationAlternatives)
    }
    @Test func insertAndUpdatePayloadsPreserveProvenanceBoundary() throws {
        let entry = try decoded()
        let insert = NewDiaryTwoEntry(patientId: patient, therapistId: entry.therapistId, createdBy: .therapist,
            event: entry.event, automaticThoughts: entry.automaticThoughts, feelings: entry.feelings,
            thinkingErrors: entry.thinkingErrors, alternativeThoughts: entry.alternativeThoughts)
        let created = try JSONSerialization.jsonObject(with: JSONEncoder().encode(insert)) as! [String: Any]
        #expect(created["created_by"] as? String == "therapist")
        #expect(created["thinking_errors"] as? [String] == ["mind_reading", "all_or_nothing"])
        #expect(created["automatic_thoughts"] as? [String] == entry.automaticThoughts)
        #expect(created["alternative_thoughts"] as? [String] == entry.alternativeThoughts)
        let update = DiaryTwoEntryClinicalUpdate(event: entry.event, automaticThoughts: entry.automaticThoughts,
            feelings: entry.feelings, thinkingErrors: entry.thinkingErrors, alternativeThoughts: entry.alternativeThoughts, updatedAt: "2026-09-02T12:00:00Z")
        let edited = try JSONSerialization.jsonObject(with: JSONEncoder().encode(update)) as! [String: Any]
        #expect(Set(edited.keys) == ["event", "automatic_thoughts", "feelings", "thinking_errors", "alternative_thoughts", "updated_at"])
    }
    @Test func activationContractAndIdempotence() throws {
        #expect(PatientDiaryTwoActivation.functionName == "request-patient-diary-two")
        #expect(PatientDiaryTwoActivation.usesEdgeFunction(.diaryTwo))
        #expect(!PatientDiaryOneActivation.usesDirectInsert(.diaryTwo))
        let body = try JSONSerialization.jsonObject(with: PatientDiaryTwoActivation.requestJSON(patientId: patient)) as! [String: String]
        #expect(body == ["patientId": patient.uuidString])
        for created in [true, false] {
            let data = Data("""
            {"success":true,"createdNew":\(created),"assignment":{"id":"11111111-1111-1111-1111-111111111111","patientId":"\(patient)","therapistId":"33333333-3333-3333-3333-333333333333","sessionId":null,"type":"diary_two","createdAt":"2026-09-01T12:00:00Z","completedAt":null,"cancelledAt":null}}
            """.utf8)
            let assignment = try PatientDiaryTwoActivation.assignment(fromResponseData: data)
            #expect(assignment.type == .diaryTwo && assignment.isOpen && assignment.sessionId == nil)
        }
        #expect(PatientDiaryTwoActivation.mapError(from: Data(#"{"error":"patient_not_connected"}"#.utf8), statusCode: 400) == .patientNotConnected)
    }
    @Test func localCRUDUpdatesHistoryWithoutAssignmentOperations() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        let store = DiaryTwoStore(client: SupabaseClient(supabaseURL: URL(string: "https://example.invalid")!, supabaseKey: "test"))
        let id = DatabaseID.text("demo-diary-two-test")
        #expect(try await store.loadEntries(for: id).isEmpty)
        let first = try await store.createEntry(patientId: id, event: "first", automaticThoughts: ["one", "two"], feelings: [.init(name: "עצוב", intensity: 10)], thinkingErrors: [.blame], alternativeThoughts: ["a", "b"])
        let second = try await store.createEntry(patientId: id, event: "second", automaticThoughts: ["one"], feelings: [.init(name: "עצוב", intensity: 20)], thinkingErrors: [.mindReading], alternativeThoughts: ["a"])
        #expect(store.entries(for: id).map(\.id) == [second.id, first.id])
        let edited = try await store.updateEntry(id: first.id, patientId: id, event: "edited", automaticThoughts: ["two", "one"], feelings: first.feelings, thinkingErrors: [.mindReading, .blame], alternativeThoughts: ["b", "a"])
        #expect(edited.createdBy == first.createdBy && edited.createdBy == .therapist)
        #expect(edited.createdAt == first.createdAt && edited.therapistId == first.therapistId)
        #expect(edited.automaticThoughts == ["two", "one"] && edited.alternativeThoughts == ["b", "a"])
        try await store.deleteEntry(id: first.id, patientId: id)
        #expect(store.entries(for: id).map(\.id) == [second.id])
    }
}
