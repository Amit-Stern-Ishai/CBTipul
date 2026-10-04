import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor
struct DiaryOneTherapistRegressionTests {
    @Test func automaticThoughtsFeelingsAndTherapistCRUDRemainUnchanged() async throws {
        await EntitlementTestIsolation.acquire()
        defer { EntitlementTestIsolation.release() }
        let store = DiaryOneStore(client: SupabaseClient(supabaseURL: URL(string: "https://example.invalid")!, supabaseKey: "test"))
        let patient = DatabaseID.text("demo-diary-one-regression")
        let entry = try await store.createEntry(patientId: patient, event: "test", automaticThoughts: ["first", "second"], feelings: [.init(name: "עצוב", intensity: 0)], behaviour: "test", physicalSymptoms: nil)
        var draft = DiaryOneEntryDraft.from(entry)
        #expect(draft.persistedAutomaticThoughts == ["first", "second"])
        #expect(draft.persistedFeelings() == entry.feelings)
        draft.automaticThoughts.append(.init(text: "  "))
        #expect(draft.validationMessage() == nil)
        #expect(draft.persistedAutomaticThoughts.count == 2)
        #expect(DiaryFeelingVocabulary.allNames.contains("עצוב"))
        let updated = try await store.updateEntry(id: entry.id, patientId: patient, event: "updated", automaticThoughts: ["second", "first"], feelings: [.init(name: "עצוב", intensity: 100)], behaviour: "updated", physicalSymptoms: "test")
        #expect(updated.createdBy == .therapist && updated.createdAt == entry.createdAt)
        #expect(updated.automaticThoughts == ["second", "first"])
        #expect(try await store.loadEntries(for: patient).count == 1)
        try await store.deleteEntry(id: entry.id, patientId: patient)
        #expect(store.entries(for: patient).isEmpty)
    }
}
