import Foundation
import Supabase

@MainActor
extension AppContextService {
    convenience init(client: SupabaseClient) {
        self.init(identity: { client.auth.currentUser?.id.uuidString }, request: {
            guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
            return try await client.functions.invoke("get-app-context")
        })
    }
}
