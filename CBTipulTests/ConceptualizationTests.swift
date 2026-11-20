import Foundation
import Supabase
import Testing
@testable import CBTipul

struct ConceptualizationTests {
    @Test func payloadsAndLimits() throws {
        var draft = ConceptDocument(); draft.core_beliefs = ["משפט סינתטי"]
        let first = try ConceptRequest.body(action: "save", patientID: "patient", revision: nil, document: draft)
        #expect(first["expected_revision"] == .null)
        if case .object(let document) = first["document"] { #expect(document.count == 5) } else { Issue.record("Missing complete document") }
        let next = try ConceptRequest.body(action: "save", patientID: "patient", revision: "opaque-revision", document: draft)
        #expect(next["expected_revision"] == .string("opaque-revision"))
        let published = try ConceptRequest.body(action: "load_published", patientID: "must-not-be-sent", revision: "ignored", document: draft)
        #expect(published == ["action": .string("load_published")])
        #expect(throws: (any Error).self) { try ConceptRequest.body(action: "publish", patientID: "patient", revision: nil, document: draft) }
        draft.rules = [" "]; #expect(!draft.isValid)
        draft.rules = Array(repeating: "משפט", count: 31); #expect(!draft.isValid)
        draft.rules = [String(repeating: "א", count: 1501)]; #expect(!draft.isValid)
        draft.rules = []; #expect(draft.isValid)
    }
    @Test func nullableDocumentAndPublishedSnapshot() throws {
        let empty = try JSONDecoder().decode(ConceptRecord.self, from: Data(#"{"patient_id":"p","document":null,"revision":null,"published_at":null}"#.utf8))
        #expect(empty.document == nil)
        var a = ConceptDocument(); a.core_beliefs = ["A"]
        let published = a
        var b = a; b.core_beliefs = ["B"]
        #expect(published.core_beliefs == ["A"])
        #expect(b != a)
    }
}
