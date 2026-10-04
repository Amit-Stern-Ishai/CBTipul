import Foundation
import OSLog
import Supabase

enum PatientDiaryThreeSubmitError: LocalizedError {
    case notActive(String)
    case accessDenied(String)
    case invalid(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notActive(let message),
             .accessDenied(let message),
             .invalid(let message),
             .failed(let message):
            message
        }
    }
}

/// CamelCase body for `submit-diary-three-entry`. No patient, therapist,
/// assignment, session, or provenance IDs.
struct SubmitDiaryThreeEntryRequest: Encodable {
    let situation: String
    let automaticThoughts: [DiaryThreeAutomaticThought]
    let feelings: [DiaryThreeFeeling]
    let thinkingErrors: [ThinkingError]
    let alternativeThoughts: [DiaryThreeAlternativeThought]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(situation, forKey: .situation)
        try container.encode(automaticThoughts, forKey: .automaticThoughts)
        try container.encode(feelings, forKey: .feelings)
        try container.encode(thinkingErrors, forKey: .thinkingErrors)
        try container.encode(alternativeThoughts, forKey: .alternativeThoughts)
    }

    enum CodingKeys: String, CodingKey {
        case situation, automaticThoughts, feelings, thinkingErrors, alternativeThoughts
    }
}

struct SubmitDiaryThreeEntryResponse: Decodable, Sendable {
    let success: Bool
    let entryId: UUID
}

enum PatientDiaryThreeHistory {
    static func visible(_ entries: [DiaryThreeEntry], patientId: UUID) -> [DiaryThreeEntry] {
        entries
            .filter { $0.createdBy == .patient && $0.patientId.uuidValue == patientId }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

/// Patient Mode history (patient-created rows only) and Edge Function submit.
@MainActor
final class PatientDiaryThreeService {
    static let functionName = "submit-diary-three-entry"
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadPatientCreatedEntries(patientId: UUID) async throws -> [DiaryThreeEntry] {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        do {
            let rows: [DiaryThreeEntry] = try await client.from("diary_three_entries")
                .select(diaryThreeSelectColumns)
                .eq("patient_id", value: patientId)
                .eq("created_by", value: DiaryOneEntryCreator.patient.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
            return PatientDiaryThreeHistory.visible(rows, patientId: patientId)
        } catch {
            AppLog.store.error(
                "Patient Diary 3 history load failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    func submitEntry(
        situation: String,
        automaticThoughts: [DiaryThreeAutomaticThought],
        feelings: [DiaryThreeFeeling],
        thinkingErrors: [ThinkingError],
        alternativeThoughts: [DiaryThreeAlternativeThought]
    ) async throws -> UUID {
        try await EntitlementState.shared.requireWrite()
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        do {
            let response: SubmitDiaryThreeEntryResponse = try await client.functions.invoke(
                Self.functionName,
                options: FunctionInvokeOptions(
                    body: SubmitDiaryThreeEntryRequest(
                        situation: situation,
                        automaticThoughts: automaticThoughts,
                        feelings: feelings,
                        thinkingErrors: thinkingErrors,
                        alternativeThoughts: alternativeThoughts
                    )
                )
            )
            guard response.success else {
                throw PatientDiaryThreeSubmitError.failed(L10n.patientDiaryOneSubmitError)
            }
            return response.entryId
        } catch let error as PatientDiaryThreeSubmitError {
            throw error
        } catch let FunctionsError.httpError(code, data) {
            throw Self.submitError(from: data, statusCode: code)
        } catch {
            AppLog.store.error(
                "Patient Diary 3 submit failed: \(error.localizedDescription, privacy: .public)"
            )
            throw PatientDiaryThreeSubmitError.failed(L10n.patientDiaryOneSubmitError)
        }
    }

    static func submitError(from data: Data, statusCode: Int) -> PatientDiaryThreeSubmitError {
        let payload = edgePayload(from: data)
        switch payload.code {
        case "diary_three_not_active": return .notActive(L10n.patientDiaryThreeNotActive)
        case "unauthorized", "patient_mode_required", "patient_access_not_found", "patient_therapist_mismatch":
            return .accessDenied(L10n.patientDiaryTwoAccessDenied)
        case "invalid_situation": return .invalid(L10n.diaryThreeValidationSituation)
        case "invalid_automatic_thoughts": return .invalid(L10n.diaryOneValidationThought)
        case "invalid_feelings": return .invalid(L10n.diaryThreeValidationRatings)
        case "duplicate_feeling": return .invalid(L10n.diaryFeelingAlreadySelected)
        case "invalid_thinking_errors": return .invalid(L10n.diaryTwoValidationErrors)
        case "duplicate_thinking_error": return .invalid(L10n.diaryTwoDuplicateThinkingError)
        case "invalid_alternative_thoughts": return .invalid(L10n.diaryTwoValidationAlternatives)
        default:
            if statusCode == 401 || statusCode == 403 { return .accessDenied(L10n.patientDiaryTwoAccessDenied) }
            return .failed(L10n.patientDiaryOneSubmitError)
        }
    }

    private static func edgePayload(from data: Data) -> (code: String, message: String) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ("", "")
        }
        let code: String
        if let error = json["error"] as? String {
            code = error
        } else if let nested = json["error"] as? [String: Any],
                  let nestedCode = nested["code"] as? String {
            code = nestedCode
        } else if let value = json["code"] as? String {
            code = value
        } else {
            code = ""
        }
        let message = (json["message"] as? String)
            ?? ((json["error"] as? [String: Any])?["message"] as? String)
            ?? ""
        return (code, message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
