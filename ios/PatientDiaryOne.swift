import Foundation
import OSLog
import Supabase

enum PatientDiaryOneSubmitError: LocalizedError {
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

/// CamelCase body for `submit-diary-one-entry`. No patient, therapist,
/// assignment, session, or provenance IDs.
struct SubmitDiaryOneEntryRequest: Encodable {
    let event: String
    let automaticThoughts: [String]
    let feelings: [DiaryFeeling]
    let behaviour: String
    let physicalSymptoms: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(event, forKey: .event)
        try container.encode(automaticThoughts, forKey: .automaticThoughts)
        try container.encode(feelings, forKey: .feelings)
        try container.encode(behaviour, forKey: .behaviour)
        try container.encode(physicalSymptoms, forKey: .physicalSymptoms)
    }

    enum CodingKeys: String, CodingKey {
        case event, automaticThoughts, feelings, behaviour, physicalSymptoms
    }
}

private struct SubmitDiaryOneEntryResponse: Decodable, Sendable {
    let success: Bool?
    let entryId: UUID?
}

enum PatientDiaryOneHistory {
    static func visible(_ entries: [DiaryOneEntry]) -> [DiaryOneEntry] {
        entries
            .filter { $0.createdBy == .patient }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

/// Patient Mode history (patient-created rows only) and Edge Function submit.
@MainActor
final class PatientDiaryOneService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadPatientCreatedEntries(patientId: UUID) async throws -> [DiaryOneEntry] {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        do {
            let rows: [DiaryOneEntry] = try await client.from("diary_one_entries")
                .select(diaryOneSelectColumns)
                .eq("patient_id", value: patientId)
                .eq("created_by", value: DiaryOneEntryCreator.patient.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
            return PatientDiaryOneHistory.visible(rows)
        } catch {
            AppLog.store.error(
                "Patient Diary 1 history load failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    func submitEntry(
        event: String,
        automaticThoughts: [String],
        feelings: [DiaryFeeling],
        behaviour: String,
        physicalSymptoms: String?
    ) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        do {
            let response: SubmitDiaryOneEntryResponse = try await client.functions.invoke(
                "submit-diary-one-entry",
                options: FunctionInvokeOptions(
                    body: SubmitDiaryOneEntryRequest(
                        event: event,
                        automaticThoughts: automaticThoughts,
                        feelings: feelings,
                        behaviour: behaviour,
                        physicalSymptoms: physicalSymptoms
                    )
                )
            )
            guard response.success != false else {
                throw PatientDiaryOneSubmitError.failed(L10n.patientDiaryOneSubmitError)
            }
            AppLog.store.info("Patient Diary 1 entry submitted")
        } catch let error as PatientDiaryOneSubmitError {
            throw error
        } catch let FunctionsError.httpError(code, data) {
            throw Self.submitError(from: data, statusCode: code)
        } catch {
            AppLog.store.error(
                "Patient Diary 1 submit failed: \(error.localizedDescription, privacy: .public)"
            )
            throw PatientDiaryOneSubmitError.failed(L10n.patientDiaryOneSubmitError)
        }
    }

    static func submitError(from data: Data, statusCode: Int) -> PatientDiaryOneSubmitError {
        let payload = edgePayload(from: data)
        let fallback = L10n.patientDiaryOneSubmitError
        let message = payload.message.isEmpty ? fallback : payload.message
        switch payload.code {
        case "diary_one_not_active":
            return .notActive(message)
        case "unauthorized", "patient_mode_required", "patient_access_not_found":
            return .accessDenied(message)
        case "patient_therapist_mismatch":
            return .accessDenied(message)
        case "invalid_automatic_thoughts":
            return .invalid(L10n.diaryOneValidationThought)
        case "invalid_event", "invalid_behaviour",
             "invalid_feelings", "duplicate_feeling", "invalid_request":
            return .invalid(message)
        default:
            if statusCode == 401 || statusCode == 403 {
                return .accessDenied(message)
            }
            AppLog.store.error("Patient Diary 1 submit failed")
            return .failed(message)
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
