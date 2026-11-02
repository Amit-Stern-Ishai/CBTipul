import XCTest
import Supabase
@testable import CBTipul

@MainActor
final class LiveSessionCreationContractTests: XCTestCase {
    func testReadOnlyCreationSchema() async throws {
        guard ProcessInfo.processInfo.environment["CBTIPUL_VERIFY_SESSION_CONTRACT"] == "1" else {
            throw XCTSkip("Explicit authenticated metadata check only")
        }
        let client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
        let session = try await client.auth.session
        guard !session.user.isAnonymous else { throw XCTSkip("Therapist test account required") }
        var request = URLRequest(url: SupabaseConfig.url.appendingPathComponent("rest/v1/"))
        request.setValue("Bearer " + session.accessToken, forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/openapi+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            let rows = try await client.from("Sessions").select("id").limit(1).execute().data
            let array = try JSONSerialization.jsonObject(with: rows) as? [[String: Any]]
            if let id = array?.first?["id"] {
                print("SESSION_EXISTING_ID_JSON_TYPE=\(id is NSNumber ? "number" : "string")")
                if let id = id as? String { print("SESSION_EXISTING_ID_IS_UUID=\(UUID(uuidString: id) != nil)") }
            } else { print("SESSION_EXISTING_ID_JSON_TYPE=unavailable_no_rows") }
            print("SESSION_OPENAPI_UNAVAILABLE_HTTP=\(status)")
            throw XCTSkip("Authenticated OpenAPI metadata is unavailable; no backend capability inferred")
        }
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let definitions = try XCTUnwrap(document["definitions"] as? [String: Any])
        let sessions = try XCTUnwrap(definitions["Sessions"] as? [String: Any])
        let properties = try XCTUnwrap(sessions["properties"] as? [String: Any])
        for key in properties.keys.sorted() {
            let field = properties[key] as? [String: Any] ?? [:]
            // Metadata only: no records, tokens, or clinical values.
            print("SESSION_COLUMN \(key) type=\(field["type"] ?? "unknown") format=\(field["format"] ?? "none") default=\(field["default"] ?? "none")")
        }
        let paths = document["paths"] as? [String: Any] ?? [:]
        for path in paths.keys.sorted() where path.hasPrefix("/rpc/") && (path.lowercased().contains("session") || path.lowercased().contains("idempoten")) {
            print("SESSION_RPC \(path)")
        }
    }
}
