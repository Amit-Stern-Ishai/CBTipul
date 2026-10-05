import Foundation
import Supabase

/// Deliberately excludes combined_notes and all therapist/AI content.
struct PatientQuestionnaireHistoryRow: Decodable {
    let patientId: UUID
    let createdBy: String
    let assignmentId: UUID?
    let id: DatabaseID
    let answeredDate: String
    let gad7Answers: [Int]
    let phq9Answers: [Int]
    let interferenceLevel: Int?
    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case createdBy = "created_by"
        case assignmentId = "assignment_id"
        case answeredDate = "answered_date"
        case gad7Answers = "gad7_answers"
        case phq9Answers = "phq9_answers"
        case interferenceLevel = "interference_level"
    }
    func completed() throws -> CompletedQuestionnaire {
        let dateOnly = DateFormatter()
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.isLenient = false
        let date = PatientAssignmentService.parseEdgeTimestamp(answeredDate)
            ?? (answeredDate.count == 10 ? dateOnly.date(from: answeredDate) : nil)
        guard let date else {
            throw PatientAssignmentError.invalidIdentifier
        }
        var answers = CombinedMoodQuestionnaire()
        answers.gad7Answers = (0..<7).map { gad7Answers.indices.contains($0) ? gad7Answers[$0] : nil }
        answers.phq9Answers = (0..<9).map { phq9Answers.indices.contains($0) ? phq9Answers[$0] : nil }
        answers.interferenceLevel = interferenceLevel
        return CompletedQuestionnaire(databaseID: id, sessionID: nil, answeredDate: date, questionnaire: answers, createdBy: "patient")
    }
}

struct PatientQuestionnaireHistoryService {
    let client: SupabaseClient
    func history(patientId: UUID) async throws -> [CompletedQuestionnaire] {
        let rows: [PatientQuestionnaireHistoryRow] = try await client.from(CombinedMoodQuestionnaire.tableName)
            .select("id, patient_id, created_by, assignment_id, answered_date, gad7_answers, phq9_answers, interference_level")
            .eq("patient_id", value: patientId)
            .eq("created_by", value: "patient")
            .order("answered_date", ascending: false)
            .order("id", ascending: false)
            .execute().value
        return try rows.filter { $0.patientId == patientId && $0.createdBy == "patient" }
            .map { try $0.completed() }.sorted {
                if $0.answeredDate != $1.answeredDate { return $0.answeredDate > $1.answeredDate }
                return (Int64($0.databaseID.queryValue) ?? 0) > (Int64($1.databaseID.queryValue) ?? 0)
            }
    }
}
