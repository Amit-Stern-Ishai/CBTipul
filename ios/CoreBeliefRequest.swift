import Foundation
import Supabase

enum CoreBeliefFailure: Error { case conflict, access, failed, invalid }
enum CoreBeliefRequest {
    static func body(action: String, patientID: String?, revision: String?, document: CoreBeliefWorksheet) throws -> [String: AnyJSON] {
        if action == "load_published" { return ["action": .string(action)] }
        guard ["load_draft", "save", "publish"].contains(action), let patientID else { throw CoreBeliefFailure.invalid }
        var result: [String: AnyJSON] = ["action": .string(action), "patient_id": .string(patientID)]
        if action != "load_draft" { result["expected_revision"] = revision.map(AnyJSON.string) ?? .null }
        if action == "publish", revision == nil { throw CoreBeliefFailure.invalid }
        if action == "save" {
            let data = try CoreBeliefWorksheetCodec.encodeDocument(document)
            result["document"] = try JSONDecoder().decode(AnyJSON.self, from: data)
        }
        return result
    }
    @MainActor static func send(client: SupabaseClient, action: String, patientID: String?, revision: String?, document: CoreBeliefWorksheet) async throws -> CoreBeliefWorksheetRecord {
        guard let owner = client.auth.currentUser?.id else { throw CoreBeliefFailure.access }
        let body = try body(action: action, patientID: patientID, revision: revision, document: document)
        do {
            let data: Data = try await client.functions.invoke("core-belief-restructuring", options: .init(body: body), decode: { data, _ in data })
            let result = try CoreBeliefWorksheetCodec.decodeRecord(data)
            guard !Task.isCancelled, client.auth.currentUser?.id == owner else { throw CancellationError() }
            guard patientID == nil || result.patientId.lowercased() == patientID?.lowercased(),
                  result.document == nil || (result.revision?.isEmpty == false) else { throw CoreBeliefFailure.failed }
            return result
        } catch let error as FunctionsError {
            if case let .httpError(status, data) = error {
                let detail = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                if status == 409, detail?["error"] as? String == "revision_conflict" { throw CoreBeliefFailure.conflict }
                if status == 403 || status == 401 { throw CoreBeliefFailure.access }
            }
            throw CoreBeliefFailure.failed
        }
    }
}
