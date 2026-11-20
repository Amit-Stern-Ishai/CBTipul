import Foundation
import Supabase

enum ConceptSection: String, CaseIterable, Codable {
    case childhood_experiences, core_beliefs, assumptions, rules, biased_expectations
    var title: String {
        switch self {
        case .childhood_experiences: "חוויות ילדות"
        case .core_beliefs: "אמונת יסוד"
        case .assumptions: "הנחות בסיס"
        case .rules: "חוקים וכללים"
        case .biased_expectations: "ציפיות מוטות"
        }
    }
}
struct ConceptDocument: Codable, Equatable {
    var childhood_experiences: [String] = []
    var core_beliefs: [String] = []
    var assumptions: [String] = []
    var rules: [String] = []
    var biased_expectations: [String] = []
    subscript(_ section: ConceptSection) -> [String] {
        get { switch section { case .childhood_experiences: childhood_experiences; case .core_beliefs: core_beliefs; case .assumptions: assumptions; case .rules: rules; case .biased_expectations: biased_expectations } }
        set { switch section { case .childhood_experiences: childhood_experiences = newValue; case .core_beliefs: core_beliefs = newValue; case .assumptions: assumptions = newValue; case .rules: rules = newValue; case .biased_expectations: biased_expectations = newValue } }
    }
    var isValid: Bool { ConceptSection.allCases.allSatisfy { self[$0].count <= 30 && self[$0].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.unicodeScalars.count <= 1500 } } }
}
struct ConceptRecord: Decodable {
    let patient_id: String
    let document: ConceptDocument?
    let revision: String?
    let published_at: String?
    let published_revision: String?
    let updated_at: String?
}
enum ConceptFailure: Error { case conflict, access, failed, invalid }
enum ConceptRequest {
    static func body(action: String, patientID: String?, revision: String?, document: ConceptDocument) throws -> [String: AnyJSON] {
        if action == "load_published" { return ["action": .string(action)] }
        guard ["load_draft", "save", "publish"].contains(action), let patientID else { throw ConceptFailure.invalid }
        var result: [String: AnyJSON] = ["action": .string(action), "patient_id": .string(patientID)]
        if action != "load_draft" { result["expected_revision"] = revision.map(AnyJSON.string) ?? .null }
        if action == "publish", revision == nil { throw ConceptFailure.invalid }
        if action == "save" {
            guard document.isValid else { throw ConceptFailure.invalid }
            result["document"] = .object(Dictionary(uniqueKeysWithValues: ConceptSection.allCases.map { ($0.rawValue, .array(document[$0].map(AnyJSON.string))) }))
        }
        return result
    }
    @MainActor static func send(client: SupabaseClient, action: String, patientID: String?, revision: String?, document: ConceptDocument) async throws -> ConceptRecord {
        guard let owner = client.auth.currentUser?.id else { throw ConceptFailure.access }
        let body = try body(action: action, patientID: patientID, revision: revision, document: document)
        do {
            let result: ConceptRecord = try await client.functions.invoke("patient-conceptualization", options: .init(body: body))
            guard !Task.isCancelled, client.auth.currentUser?.id == owner else { throw CancellationError() }
            guard patientID == nil || result.patient_id.lowercased() == patientID?.lowercased(),
                  result.document == nil || (result.document!.isValid && result.revision?.isEmpty == false) else { throw ConceptFailure.failed }
            return result
        } catch let error as FunctionsError {
            if case let .httpError(status, data) = error {
                let detail = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                if status == 409, detail?["error"] as? String == "revision_conflict" { throw ConceptFailure.conflict }
                if status == 403 || status == 401 { throw ConceptFailure.access }
            }
            throw ConceptFailure.failed
        }
    }
}
