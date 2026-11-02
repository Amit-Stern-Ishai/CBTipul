import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor struct ClinicalRecordLoadTests {
    private func row(_ id: String = "9223372036854775807") -> AnyJSON {
        .object(["id": .string(id), "_version": .string("opaque"), "notes": .null,
                 "combined_notes": .object(["gad7": .array([.string(""), .null])])])
    }
    @Test func shortPagesPreserveRawValuesAndVersion() async throws {
        var calls = 0
        let rows = try await ClinicalRecordLoad.pages(endpoint: "load-questionnaires", checkpoint: {}, invoke: { _, body in
            calls += 1
            if calls == 1 { return ["records": .array([row()]), "next_cursor": .string("next")] }
            #expect(body["cursor"] == .string("next"))
            return ["records": .array([]), "next_cursor": .null]
        })
        #expect(calls == 2); #expect(rows[0].id == "9223372036854775807")
        #expect(rows[0].version == "opaque"); #expect(rows[0].values["notes"] == .null)
        #expect(rows[0].values["combined_notes"] == .object(["gad7": .array([.string(""), .null])]))
        struct ID: Decodable { let id: DatabaseID }
        #expect(try rows[0].decode(ID.self).id == .text("9223372036854775807"))
    }
    @Test func accountChangeRejectsLatePage() async {
        var current = true
        await #expect(throws: CancellationError.self) {
            _ = try await ClinicalRecordLoad.pages(endpoint: "load-patients", checkpoint: { if !current { throw CancellationError() } }, invoke: { _, _ in
                current = false; return ["records": .array([row()]), "next_cursor": .null]
            })
        }
    }
    @Test func partialFailureAndLoopNeverReturnPartialRecords() async {
        var calls = 0
        await #expect(throws: (any Error).self) {
            _ = try await ClinicalRecordLoad.pages(endpoint: "load-patients", checkpoint: {}, invoke: { _, _ in
                calls += 1
                if calls > 1 { throw ClientFailure.service }
                return ["records": .array([row()]), "next_cursor": .string("next")]
            })
        }
        await #expect(throws: (any Error).self) {
            _ = try await ClinicalRecordLoad.pages(endpoint: "load-patients", checkpoint: {}, invoke: { _, _ in ["records": .array([]), "next_cursor": .string("same")] })
        }
    }
    @Test func rejectsNumericIdsAndWrongPatient() async {
        for bad: AnyJSON in [.object(["id": .integer(2), "_version": .string("v")]), row()] {
            await #expect(throws: (any Error).self) {
                _ = try await ClinicalRecordLoad.pages(endpoint: "load-questionnaires", parameters: ["patient_id": .string("expected")], checkpoint: {}, invoke: { _, _ in ["records": .array([bad]), "next_cursor": .null] })
            }
        }
    }
}
