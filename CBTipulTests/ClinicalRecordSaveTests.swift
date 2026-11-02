import Foundation
import Supabase
import Testing
@testable import CBTipul

@MainActor struct ClinicalRecordSaveTests {
    let old = ClinicalLoadedRecord(values: ["id": .string("9223372036854775807"), "_version": .string("v1"), "notes": .null, "combined_notes": .object(["gad7": .array([.string("old")])])])
    @Test func changedFieldsAndExplicitClears() throws {
        let body = try ClinicalRecordSave.request(previous: old, proposed: ["notes": .string(""), "combined_notes": .null, "patient_id": .string("immutable")])
        #expect(body["id"] == .string("9223372036854775807"))
        #expect(body["expected_version"] == .string("v1"))
        #expect(body["changes"] == .object(["notes": .string(""), "combined_notes": .null]))
        let unchanged = try ClinicalRecordSave.request(previous: old, proposed: ["notes": .null])
        #expect(unchanged["changes"] == .object([:]))
        let shared = try ClinicalRecordSave.request(previous: old, proposed: ["notes": .string("private"), "combined_notes": .null], shared: true)
        #expect(shared["view"] == .string("shared")); #expect(shared["changes"] == .object([:]))
    }
    @Test func originalTextAndReturnedVersion() async throws {
        let text = "  טקסט סינתטי!\nבדיוק.  "
        let saved = try await ClinicalRecordSave.save(endpoint: "save-session", previous: old, proposed: ["notes": .string(text)], checkpoint: {}, invoke: { _, body in
            #expect(body["changes"] == .object(["notes": .string(text)]))
            return ["record": .object(["id": .string(old.id), "_version": .string("v2"), "notes": .string(text)])]
        })
        #expect(saved.version == "v2"); #expect(saved.values["notes"] == .string(text)); #expect(old.version == "v1")
    }
    @Test func conflictAndUncertainCreateNeverRetry() async {
        for code in ["record_changed", "save_outcome_unknown", "save_not_confirmed"] {
            var calls = 0
            await #expect(throws: code == "record_changed" ? ClientFailure.conflict : ClientFailure.uncertainCreation) {
                _ = try await ClinicalRecordSave.save(endpoint: "save-session", previous: nil, proposed: ["notes": .string("draft")], checkpoint: {}, invoke: { _, _ in
                    calls += 1
                    throw FunctionsError.httpError(code: 409, data: try JSONEncoder().encode(["error":code]))
                })
            }
            #expect(calls == 1)
        }
        await #expect(throws: ClientFailure.uncertainCreation) {
            _ = try await ClinicalRecordSave.save(endpoint: "save-session", previous: nil, proposed: [:], checkpoint: {}, invoke: { _, _ in throw URLError(.timedOut) })
        }
    }
    @Test func accountSwitchDiscardsSaveResponse() async {
        var current = true
        await #expect(throws: CancellationError.self) {
            _ = try await ClinicalRecordSave.save(endpoint: "save-session", previous: old, proposed: [:], checkpoint: { if !current { throw CancellationError() } }, invoke: { _, _ in
                current = false; return ["record": .object(old.values)]
            })
        }
    }
}
