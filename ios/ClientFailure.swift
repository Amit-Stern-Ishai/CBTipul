import Foundation
import Supabase
import Auth

/// Classification uses transport status and machine codes, never translated text.
nonisolated enum ClientFailure: String, Error, LocalizedError {
    case connection, expiredLogin, restricted, monthlyAllowance, rateLimited
    case validation, conflict, service, unknown, localDraft, uncertainCreation

    static func classify(status: Int?, code: String?) -> ClientFailure {
        switch code {
        case "monthly_ai_limit_exceeded", "monthly_quota_exceeded", "monthly_allowance_exhausted": return .monthlyAllowance
        case "session_not_found", "session_expired", "refresh_token_not_found", "bad_jwt", "PGRST301": return .expiredLogin
        case "not_admin", "user_banned", "42501": return .restricted
        case "23505", "40001", "association_preview_changed": return .conflict
        case "validation_failed", "bad_json", "invalid_credentials", "weak_password": return .validation
        case "over_request_rate_limit", "over_email_send_rate_limit": return .rateLimited
        case "unexpected_failure": return .service
        default: break
        }
        switch status ?? 0 {
        case 401: return .expiredLogin
        case 403: return .restricted
        case 408: return .connection
        case 409: return .conflict
        case 400, 422: return .validation
        case 429: return .rateLimited
        case 500...599: return .service
        default: return .unknown
        }
    }

    /// Numeric contract supplied for monthly token exhaustion. No message matching.
    private struct MonthlyTokenAllowance: Decodable {
        let monthlyLimit: Int64
        let usedTokens: Int64
        let remainingTokens: Int64

        var exhausted: Bool {
            let largestExactJSONInteger: Int64 = 9_007_199_254_740_991
            return monthlyLimit >= 0 && monthlyLimit <= largestExactJSONInteger
                && usedTokens >= monthlyLimit && usedTokens <= largestExactJSONInteger
                && remainingTokens == 0
        }
    }

    static func from(_ error: Error) -> ClientFailure {
        if let failure = error as? ClientFailure { return failure }
        if let url = error as? URLError {
            return url.code == .userAuthenticationRequired ? .expiredLogin : .connection
        }
        if case let FunctionsError.httpError(status, data) = error {
            // A failed request carrying this complete, consistent numeric receipt
            // establishes exhaustion; a bare 429 still means temporary rate limiting.
            if status != 401,
               let allowance = try? JSONDecoder().decode(MonthlyTokenAllowance.self, from: data),
               allowance.exhausted {
                return .monthlyAllowance
            }
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let nested = body?["error"] as? [String: Any]
            // Only named code fields are interpreted; arbitrary error strings stay private.
            return classify(status: status, code: body?["code"] as? String ?? nested?["code"] as? String)
        }
        if let auth = error as? Auth.AuthError { return classify(status: nil, code: auth.errorCode.rawValue) }
        if let database = error as? PostgrestError { return classify(status: nil, code: database.code) }
        return .unknown
    }

    var errorDescription: String? {
        switch self {
        case .connection: return "לא ניתן להתחבר כרגע. בדקו את החיבור ונסו שוב."
        case .expiredLogin: return "ההתחברות פגה. התחברו מחדש כדי להמשיך."
        case .restricted: return "אין הרשאה לפעולה הזו. בדקו שאתם מחוברים לחשבון המתאים."
        case .monthlyAllowance: return "מכסת ה־AI לחודש זה נוצלה\nאפשר לחזור לפעולות AI לאחר חידוש המכסה."
        case .rateLimited: return "נדרשת הפסקה קצרה\nהמתינו מעט ונסו שוב. זו מגבלה זמנית, ולא הודעה על סיום המכסה החודשית."
        case .validation: return "לא ניתן להשלים את הפעולה עם הפרטים האלה. בדקו את השדות ונסו שוב."
        case .conflict: return "המידע השתנה. רעננו ובדקו את הפרטים לפני ניסיון נוסף."
        case .service: return "השירות אינו זמין כרגע. נסו שוב מאוחר יותר."
        case .unknown: return "לא ניתן להשלים את הפעולה כרגע. נסו שוב."
        case .localDraft: return "הטיוטה לא נשמרה במכשיר. השאירו את המסך פתוח ונסו שוב."
        case .uncertainCreation: return "לא התקבל אישור לשמירת המפגש. כדי למנוע כפילות, אין לשלוח אותו שוב. בדקו ברשימת הפגישות אם נוצר מפגש. הטיוטה נשארת במכשיר."
        }
    }
}


import SwiftUI

/// Curated copy only. The title/body split does not classify failures.
struct AIUsageNotice: View {
    let message: String
    var title: String = "הפעולה לא הושלמה"
    var body: some View {
        let parts = message.split(separator: "\n", maxSplits: 1).map(String.init)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(Theme.gold).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(parts.count > 1 ? parts[0] : title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textBright)
                Text(parts.count > 1 ? parts[1] : message).font(.subheadline).foregroundStyle(Theme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.borderDefault, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
