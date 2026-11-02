import Foundation
import Supabase

// Retains the server representation (including nulls and opaque version) alongside
// the existing presentation models. Never serialized into the legacy save bodies.
nonisolated struct ClinicalLoadedRecord: Codable, Equatable, Sendable {
    let values: [String: AnyJSON]
    var version: String { if case .string(let v) = values["_version"] { return v }; return "" }
    var id: String { if case .string(let v) = values["id"] { return v }; return "" }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(values))
    }
}
@MainActor
enum ClinicalRecordLoad {
    static func pages(endpoint: String, parameters: [String: AnyJSON] = [:],
                      checkpoint: () throws -> Void,
                      invoke: (String, [String: AnyJSON]) async throws -> [String: AnyJSON]) async throws -> [ClinicalLoadedRecord] {
        precondition(["load-patients", "load-sessions", "load-questionnaires"].contains(endpoint))
        var result: [ClinicalLoadedRecord] = [], seen = Set<String>()
        var ids = Set<String>()
        var cursor: String?
        repeat {
            try checkpoint()
            var body = parameters; body["limit"] = .integer(100)
            if let cursor { body["cursor"] = .string(cursor) }
            let page = try await invoke(endpoint, body)
            try checkpoint()
            guard case .array(let records) = page["records"], let next = page["next_cursor"] else { throw ClientFailure.service }
            for value in records {
                guard case .object(let row) = value, case .string = row["id"], case .string(let version) = row["_version"], !version.isEmpty else { throw ClientFailure.service }
                for field in ["patient_id", "session_id", "therapist_id", "assignment_id"] {
                    if let id = row[field], id != .null { guard case .string = id else { throw ClientFailure.service } }
                }
                if let id = parameters["id"], row["id"] != id { throw ClientFailure.service }
                if let patient = parameters["patient_id"], row["patient_id"] != patient { throw ClientFailure.service }
                let record = ClinicalLoadedRecord(values: row)
                guard ids.insert(record.id).inserted else { throw ClientFailure.service }
                result.append(record)
            }
            if next == .null { cursor = nil }
            else if case .string(let token) = next, !token.isEmpty, parameters["id"] == nil, seen.insert(token).inserted { cursor = token }
            else { throw ClientFailure.service }
        } while cursor != nil
        return result
    }
}
