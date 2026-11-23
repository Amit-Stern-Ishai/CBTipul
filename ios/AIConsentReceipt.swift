import Foundation
import Supabase

nonisolated struct AIConsentReceipt: Decodable {
    let therapist_id: String, consent_type: String, required_version: String
    let accepted_version: String?, accepted_at: String?, revoked_at: String?
    let status: String
    let revision: Int64
    static func decode(_ data: Data, account: String) throws -> Self {
        let fields = ["therapist_id", "consent_type", "required_version", "accepted_version", "accepted_at", "revoked_at", "status", "revision"]
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], fields.allSatisfy({object.keys.contains($0)}) else { throw NameSyncFailure(code: "invalid_response") }
        let value = try JSONDecoder().decode(Self.self, from: data)
        func date(_ text: String?) -> Bool {
            guard let text else { return false }
            let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: text) != nil || ISO8601DateFormatter().date(from: text) != nil
        }
        guard value.therapist_id.lowercased() == account.lowercased(), value.consent_type == "ai_data_sharing", value.required_version == "2026-11-22", (0...9_007_199_254_740_991).contains(value.revision), ["required","accepted","declined","revoked"].contains(value.status), value.accepted_at == nil || date(value.accepted_at), value.revoked_at == nil || date(value.revoked_at), value.status != "accepted" || (value.accepted_version == value.required_version && date(value.accepted_at) && value.revoked_at == nil), value.status != "revoked" || date(value.revoked_at) else { throw NameSyncFailure(code: "invalid_response") }
        return value
    }
}
nonisolated struct AIConsentDecision {
    let revision: Int64
    let request = UUID().uuidString
    var params: [String: AnyJSON] { ["p_consent_type": .string("ai_data_sharing"), "p_required_version": .string("2026-11-22"), "p_decision": .string("accepted"), "p_request_id": .string(request), "p_expected_revision": .integer(Int(revision))] }
}
