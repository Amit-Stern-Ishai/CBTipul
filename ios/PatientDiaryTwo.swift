import Foundation
import OSLog
import Supabase

enum PatientDiaryTwoSubmitError: LocalizedError {
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

/// CamelCase body for `submit-diary-two-entry`. No patient, therapist,
/// assignment, session, or provenance IDs.
struct SubmitDiaryTwoEntryRequest: Encodable {
    let event: String
    let automaticThoughts: [String]
    let feelings: [DiaryFeeling]
    let thinkingErrors: [ThinkingError]
    let alternativeThoughts: [String]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(event, forKey: .event)
        try container.encode(automaticThoughts, forKey: .automaticThoughts)
        try container.encode(feelings, forKey: .feelings)
        try container.encode(thinkingErrors, forKey: .thinkingErrors)
        try container.encode(alternativeThoughts, forKey: .alternativeThoughts)
    }

    enum CodingKeys: String, CodingKey {
        case event, automaticThoughts, feelings, thinkingErrors, alternativeThoughts
    }
}

struct SubmitDiaryTwoEntryResponse: Decodable, Sendable {
    let success: Bool
    let entryId: UUID
}

enum PatientDiaryTwoHistory {
    static func visible(_ entries: [DiaryTwoEntry], patientId: UUID) -> [DiaryTwoEntry] {
        entries
            .filter { $0.patientId.uuidValue == patientId }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

/// Full patient-linked history and Edge Function creation. Editing uses the shared authenticated diary store.
@MainActor
final class PatientDiaryTwoService {
    static let functionName = "submit-diary-two-entry"
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadPatientCreatedEntries(patientId: UUID) async throws -> [DiaryTwoEntry] {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        do {
            var rows: [DiaryTwoEntry] = []
            var offset = 0
            while true {
                let page: [DiaryTwoEntry] = try await client.from("diary_two_entries")
                    .select(diaryTwoSelectColumns)
                    .eq("patient_id", value: patientId)
                    .order("created_at", ascending: false).order("id", ascending: false)
                    .range(from: offset, to: offset + 249).execute().value
                rows.append(contentsOf: page)
                if page.count < 250 { break }
                offset += page.count
            }
            return PatientDiaryTwoHistory.visible(rows, patientId: patientId)
        } catch {
            AppLog.store.error(
                "Patient Diary 2 history load failed"
            )
            throw error
        }
    }

    func submitEntry(
        event: String,
        automaticThoughts: [String],
        feelings: [DiaryFeeling],
        thinkingErrors: [ThinkingError],
        alternativeThoughts: [String]
    ) async throws -> UUID {
        try await TelemetryMeasure.run(.submission, form: .diaryTwo) { [self] in
            try await EntitlementState.shared.requireWrite()
            guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
            do {
                let response: SubmitDiaryTwoEntryResponse = try await TelemetryRequests.run(.diaryTwoSubmit) { [self] in try await client.functions.invoke(
                    Self.functionName,
                    options: FunctionInvokeOptions(
                        body: SubmitDiaryTwoEntryRequest(
                            event: event,
                            automaticThoughts: automaticThoughts,
                            feelings: feelings,
                            thinkingErrors: thinkingErrors,
                            alternativeThoughts: alternativeThoughts
                        )
                    )
                ) }
                guard response.success else {
                    throw PatientDiaryTwoSubmitError.failed(L10n.patientDiaryOneSubmitError)
                }
                return response.entryId
            } catch let error as PatientDiaryTwoSubmitError {
                throw error
            } catch let FunctionsError.httpError(code, data) {
                throw Self.submitError(from: data, statusCode: code)
            } catch {
                // Preserve transport errors; the screen supplies safe, contextual copy.
                throw error
            }

        }
    }

    static func submitError(from data: Data, statusCode: Int) -> PatientDiaryTwoSubmitError {
        let payload = edgePayload(from: data)
        switch payload.code {
        case "diary_two_not_active": return .notActive(L10n.patientDiaryTwoNotActive)
        case "unauthorized", "patient_mode_required", "patient_access_not_found", "patient_therapist_mismatch":
            return .accessDenied(L10n.patientDiaryTwoAccessDenied)
        case "invalid_event": return .invalid(L10n.diaryOneValidationEvent)
        case "invalid_automatic_thoughts": return .invalid(L10n.diaryOneValidationThought)
        case "invalid_feelings": return .invalid(L10n.patientDiaryTwoInvalidFeelings)
        case "duplicate_feeling": return .invalid(L10n.diaryFeelingAlreadySelected)
        case "invalid_thinking_errors": return .invalid(L10n.diaryTwoValidationErrors)
        case "duplicate_thinking_error": return .invalid(L10n.diaryTwoDuplicateThinkingError)
        case "invalid_alternative_thoughts": return .invalid(L10n.diaryTwoValidationAlternatives)
        default:
            let classified = ClientFailure.from(FunctionsError.httpError(code: statusCode, data: data))
            if classified != .unknown && classified != .validation && statusCode != 401 && statusCode != 403 {
                return .failed(classified.localizedDescription)
            }
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
