import Foundation
import Supabase

struct ExposureItem: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var situation = ""
    var difficulty: Int? = nil
    enum CodingKeys: String, CodingKey { case id, situation, difficulty }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(situation, forKey: .situation)
        if let difficulty { try c.encode(difficulty, forKey: .difficulty) } else { try c.encodeNil(forKey: .difficulty) }
    }
}
struct ExposureDocument: Codable, Equatable {
    var items: [ExposureItem] = []
    var isValid: Bool { items.count <= 100 && Set(items.map(\.id)).count == items.count && items.allSatisfy { !$0.situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.situation.unicodeScalars.count <= 1000 && ($0.difficulty == nil || (0...100).contains($0.difficulty!)) } }
    mutating func move(_ id: UUID, to: Int) { guard let from = items.firstIndex(where: { $0.id == id }), items.indices.contains(to) else { return }; let item = items.remove(at: from); items.insert(item, at: to) }
}
struct ExposureRecord: Decodable {
    let patient_id: UUID
    let document: ExposureDocument?
    let revision: String?
    let updated_at: String?
}
enum ExposureFailure: Error { case conflict, access, invalid, failed }
enum ExposureRequest {
    static func body(action: String, patientID: String?, revision: String?, document: ExposureDocument) throws -> [String: AnyJSON] {
        guard ["load", "save"].contains(action) else { throw ExposureFailure.invalid }
        var body: [String: AnyJSON] = ["action": .string(action)]
        if let patientID { body["patient_id"] = .string(patientID) }
        if action == "save" { guard document.isValid else { throw ExposureFailure.invalid }; body["expected_revision"] = revision.map(AnyJSON.string) ?? .null; body["document"] = try JSONDecoder().decode(AnyJSON.self, from: JSONEncoder().encode(document)) }
        return body
    }
    @MainActor static func send(client: SupabaseClient, action: String, patientID: String?, revision: String?, document: ExposureDocument) async throws -> ExposureRecord {
        guard let owner = client.auth.currentUser?.id else { throw ExposureFailure.access }
        do {
            let result: ExposureRecord = try await client.functions.invoke("patient-exposure-hierarchy", options: .init(body: try body(action: action, patientID: patientID, revision: revision, document: document)))
            guard !Task.isCancelled, client.auth.currentUser?.id == owner else { throw CancellationError() }
            guard patientID == nil || result.patient_id.uuidString.lowercased() == patientID?.lowercased(), result.document == nil || (result.document!.isValid && result.revision?.isEmpty == false) else { throw ExposureFailure.failed }
            return result
        } catch let e as FunctionsError {
            if case let .httpError(status, data) = e {
                let code = (try? JSONDecoder().decode([String: AnyJSON].self, from: data))?["error"]
                if status == 409, code == .string("revision_conflict") { throw ExposureFailure.conflict }
                if status == 401 || status == 403 { throw ExposureFailure.access }
            }
            throw ExposureFailure.failed
        }
    }
    @MainActor static func enabled(client: SupabaseClient, patient: UUID) async throws -> Bool {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client.from("patient_assignments").select("id").eq("patient_id", value: patient.uuidString).eq("type", value: "exposure_hierarchy").is("cancelled_at", value: nil).limit(1).execute().value
        return !rows.isEmpty
    }
    @MainActor static func setEnabled(client: SupabaseClient, patient: UUID, enabled: Bool) async throws {
        struct Parameters: Encodable { let p_patient_id: UUID; let p_enabled: Bool }
        _ = try await client.rpc("set_patient_exposure_hierarchy_enabled", params: Parameters(p_patient_id: patient, p_enabled: enabled)).execute()
        guard try await self.enabled(client: client, patient: patient) == enabled else { throw ExposureFailure.failed }
    }
}
