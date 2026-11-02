import Foundation
import Supabase

nonisolated enum SummaryAllowanceError: Error, LocalizedError {
    case couldNotCheck, tokensExhausted, transcriptionExhausted, recordingTooLong
    var errorDescription: String? {
        switch self {
        case .couldNotCheck: return "לא הצלחנו לבדוק את המכסה\nאין כרגע מידע על היתרה. בדקו שוב לפני העיבוד."
        case .tokensExhausted: return "מכסת ה־AI לחודש זה נוצלה\nסיכום חדש והקלטה יהיו זמינים לאחר חידוש המכסה. אפשר להמשיך לערוך טיוטה קיימת."
        case .transcriptionExhausted: return "מכסת התמלול לחודש זה נוצלה\nאפשר לנסות לתמלל שוב לאחר חידוש המכסה."
        case .recordingTooLong: return "אין מספיק זמן תמלול להקלטה הזו\nמשך ההקלטה גדול מהיתרה החודשית. אפשר לנסות לאחר חידוש המכסה."
        }
    }
}

/// No balance is cached as permission to process. Every operation fetches again.
nonisolated struct SummaryAIAllowance: Decodable {
    let checkedAt: String
    let usageMonth: String
    let resetsAt: String
    let chatTokens: Balance
    let transcriptionSeconds: Balance
    struct Balance: Decodable {
        let limit: Double
        let used: Double
        let remaining: Double
        let exhausted: Bool
        let code: String?
        var valid: Bool {
            [limit, used, remaining].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 9_007_199_254_740_991 }
                && remaining <= limit && remaining == max(0, limit - used)
                && exhausted == (remaining == 0)
                && (exhausted || code == nil)
        }
    }
    enum CodingKeys: String, CodingKey {
        case checkedAt = "checked_at", usageMonth = "usage_month", resetsAt = "resets_at"
        case chatTokens = "chat_tokens", transcriptionSeconds = "transcription_seconds"
    }

    /// Configurable policy: warn at or below 10% of the applicable monthly limit.
    /// This is a client warning threshold, never an allowance reservation.
    static let lowRemainingFraction = 0.10

    func assess(needsTokens: Bool, recordingSeconds: TimeInterval?,
                lowFraction: Double = Self.lowRemainingFraction) throws -> Bool {
        let dates = ISO8601DateFormatter()
        dates.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plainDates = ISO8601DateFormatter()
        guard chatTokens.valid, transcriptionSeconds.valid,
              dates.date(from: checkedAt) ?? plainDates.date(from: checkedAt) != nil,
              dates.date(from: resetsAt) ?? plainDates.date(from: resetsAt) != nil,
              usageMonth.range(of: #"^\d{4}-(0[1-9]|1[0-2])(?:-01)?$"#, options: .regularExpression) != nil,
              lowFraction.isFinite, (0...1).contains(lowFraction) else {
            throw SummaryAllowanceError.couldNotCheck
        }
        if needsTokens && chatTokens.exhausted { throw SummaryAllowanceError.tokensExhausted }
        if let seconds = recordingSeconds {
            guard seconds.isFinite && seconds >= 0 else { throw SummaryAllowanceError.couldNotCheck }
            if transcriptionSeconds.exhausted { throw SummaryAllowanceError.transcriptionExhausted }
            if seconds > transcriptionSeconds.remaining { throw SummaryAllowanceError.recordingTooLong }
        }
        return (needsTokens && chatTokens.remaining <= chatTokens.limit * lowFraction)
            || (recordingSeconds != nil && transcriptionSeconds.remaining <= transcriptionSeconds.limit * lowFraction)
    }

    static func fetch(client: SupabaseClient) async throws -> Self {
        try await fetch { try await client.rpc("get_my_ai_allowance").execute().value }
    }

    /// Test seam for transport failures. Never turns a failed lookup into exhaustion.
    static func fetch(using lookup: () async throws -> Self) async throws -> Self {
        do { return try await lookup() }
        catch is CancellationError { throw CancellationError() }
        catch { throw SummaryAllowanceError.couldNotCheck }
    }
}
