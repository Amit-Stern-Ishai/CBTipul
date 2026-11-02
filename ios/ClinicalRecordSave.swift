import Foundation
import Supabase

/// Versioned writes through the encrypted clinical APIs.
@MainActor
final class ClinicalRecordSave {
    static func request(previous: ClinicalLoadedRecord?, proposed: [String: AnyJSON], shared: Bool = false) throws -> [String: AnyJSON] {
        if let previous, previous.id.isEmpty || previous.version.isEmpty { throw ClientFailure.conflict }
        var changes = proposed.filter { key, value in previous?.values[key] != value }
        if previous != nil { changes.removeValue(forKey: "patient_id") }
        if shared { changes.removeValue(forKey: "notes"); changes.removeValue(forKey: "combined_notes") }
        var body: [String: AnyJSON] = ["mode": .string(previous == nil ? "create" : "update"), "changes": .object(changes)]
        if let previous { body["id"] = .string(previous.id); body["expected_version"] = .string(previous.version) }
        if shared { body["view"] = .string("shared") }
        return body
    }
    static func save(endpoint: String, previous: ClinicalLoadedRecord?, proposed: [String: AnyJSON],
                     checkpoint: () throws -> Void,
                     invoke: (String, [String: AnyJSON]) async throws -> [String: AnyJSON]) async throws -> ClinicalLoadedRecord {
        let body = try request(previous: previous, proposed: proposed)
        try checkpoint()
        let result: [String: AnyJSON]
        do { result = try await invoke(endpoint, body) }
        catch {
            try checkpoint()
            if case let FunctionsError.httpError(status, data) = error {
                let json = (try? JSONDecoder().decode([String: AnyJSON].self, from: data)) ?? [:]
                let code = json["code"]?.stringValue ?? json["error"]?.stringValue
                if code == "record_changed" { throw ClientFailure.conflict }
                if ["save_outcome_unknown", "save_not_confirmed"].contains(code ?? "") { throw ClientFailure.uncertainCreation }
                throw ClientFailure.classify(status: status, code: code)
            }
            if error is CancellationError { throw error }
            throw ClientFailure.uncertainCreation
        }
        try checkpoint()
        guard case .object(let values) = result["record"], case .string(let id) = values["id"], case .string(let version) = values["_version"], !version.isEmpty,
              previous == nil || previous?.id == id,
              proposed["patient_id"] == nil || proposed["patient_id"] == values["patient_id"] else { throw ClientFailure.uncertainCreation }
        return ClinicalLoadedRecord(values: values)
    }
}
