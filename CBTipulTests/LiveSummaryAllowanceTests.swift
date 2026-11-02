import XCTest
import Supabase
@testable import CBTipul

/// Explicit opt-in only: performs one authenticated read, never a mutation.
@MainActor
final class LiveSummaryAllowanceTests: XCTestCase {
    func testAuthenticatedAllowanceContract() async throws {
        guard ProcessInfo.processInfo.environment["CBTIPUL_VERIFY_LIVE_ALLOWANCE"] == "1" else {
            throw XCTSkip("Live account check is opt-in")
        }
        let client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
        let session = try await client.auth.session
        XCTAssertFalse(session.user.isAnonymous, "A therapist test account is required")
        guard !session.user.isAnonymous else { return }
        let receipt = try await SummaryAIAllowance.fetch(client: client)
        // Decode and validation happen in the same implementation used by the editor.
        XCTAssertFalse(receipt.checkedAt.isEmpty)
        XCTAssertFalse(receipt.resetsAt.isEmpty)
        print("LIVE_ALLOWANCE_CONTRACT_VERIFIED; tokens exhausted=\(receipt.chatTokens.exhausted); transcription exhausted=\(receipt.transcriptionSeconds.exhausted)")
    }
}
