import SwiftUI
import Supabase

/// Errors from saving patients, sessions, and questionnaires.
enum PatientStoreError: LocalizedError {
    case patientNotSaved
    case sessionNotSaved
    case updateRejected

    var errorDescription: String? {
        switch self {
        case .patientNotSaved:
            return "This patient hasn't been saved to the database yet."
        case .sessionNotSaved:
            return "This session hasn't been saved to the database yet."
        case .updateRejected:
            return "The server accepted the request but didn't change any row. Check the table's row-level security policies (UPDATE is likely missing)."
        }
    }
}

/// The `id` column of a freshly inserted row.
private nonisolated struct InsertedRow: Decodable {
    let id: DatabaseID
}

/// Row shape for inserts into the `Patients` table.
private nonisolated struct NewPatientRecord: Encodable {
    let firstName: String
    let lastName: String
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case active
    }
}

/// Row shape for inserts into the `Sessions` table.
private nonisolated struct NewSessionRecord: Encodable {
    let patientID: DatabaseID
    let sessionDate: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case patientID = "patient_id"
        case sessionDate = "session_date"
        case notes
    }
}

/// Row shape for inserts into the combined questionnaire table.
private nonisolated struct NewQuestionnaireRecord: Encodable {
    let patientID: DatabaseID
    let sessionID: DatabaseID
    let answeredDate: String
    let gad7Answers: [Int]
    let phq9Answers: [Int]
    let interferenceLevel: Int?
    let combinedNotes: QuestionnaireNotes

    enum CodingKeys: String, CodingKey {
        case patientID = "patient_id"
        case sessionID = "session_id"
        case answeredDate = "answered_date"
        case gad7Answers = "gad7_answers"
        case phq9Answers = "phq9_answers"
        case interferenceLevel = "interference_level"
        case combinedNotes = "combined_notes"
    }
}

/// Row shape for selects from the `Patients` table.
private nonisolated struct PatientRow: Decodable {
    let id: DatabaseID
    let firstName: String?
    let lastName: String?
    let active: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case active
    }
}

/// Row shape for selects from the `Sessions` table.
private nonisolated struct SessionRow: Decodable {
    let id: DatabaseID
    let patientID: DatabaseID
    let sessionDate: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case patientID = "patient_id"
        case sessionDate = "session_date"
        case notes
    }
}

/// Row shape for updates of an existing `Sessions` row.
private nonisolated struct UpdatedSessionRecord: Encodable {
    let sessionDate: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case sessionDate = "session_date"
        case notes
    }
}

/// Row shape for selects from the combined questionnaire table.
private nonisolated struct QuestionnaireRow: Decodable {
    let id: DatabaseID
    let sessionID: DatabaseID?
    let answeredDate: String?
    let gad7Answers: [Int]?
    let phq9Answers: [Int]?
    let interferenceLevel: Int?
    let combinedNotes: QuestionnaireNotes?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case answeredDate = "answered_date"
        case gad7Answers = "gad7_answers"
        case phq9Answers = "phq9_answers"
        case interferenceLevel = "interference_level"
        case combinedNotes = "combined_notes"
    }
}

/// Store of the therapist's patients, backed by the Supabase `Patients` table.
///
/// Patients and their sessions are loaded from the database when the patient
/// list appears; adding a patient, session, or questionnaire inserts a row.
@Observable
@MainActor
final class PatientStore {
    private let client: SupabaseClient

    var patients: [Patient] = []

    /// Cache of each patient's saved questionnaires (newest first), keyed by
    /// the patient's database ID. Filled by `loadQuestionnaires` and kept in
    /// sync by `saveQuestionnaire`.
    private(set) var questionnairesByPatient: [DatabaseID: [CompletedQuestionnaire]] = [:]

    init(client: SupabaseClient) {
        self.client = client
    }

    /// The cached questionnaires of a patient, if they were loaded before.
    func cachedQuestionnaires(for patient: Patient) -> [CompletedQuestionnaire]? {
        patient.databaseID.flatMap { questionnairesByPatient[$0] }
    }

    /// Replaces the in-memory patient list with the contents of the
    /// `Patients` and `Sessions` tables.
    func loadPatients() async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }

        let patientRows: [PatientRow] = try await client.from("Patients")
            .select("id, first_name, last_name, active")
            .execute()
            .value
        let sessionRows: [SessionRow] = try await client.from("Sessions")
            .select("id, patient_id, session_date, notes")
            .execute()
            .value

        var sessionsByPatient: [DatabaseID: [Session]] = [:]
        for row in sessionRows {
            let session = Session(
                databaseID: row.id,
                date: parseDate(row.sessionDate),
                notes: row.notes ?? ""
            )
            sessionsByPatient[row.patientID, default: []].append(session)
        }

        patients = patientRows.map { row in
            Patient(
                databaseID: row.id,
                firstName: row.firstName ?? "",
                lastName: row.lastName ?? "",
                status: (row.active ?? true) ? .active : .inactive,
                sessions: (sessionsByPatient[row.id] ?? []).sorted { $0.date < $1.date }
            )
        }
    }

    /// Parses a Postgres `date` value, falling back to timestamp formats in
    /// case the column was created as `timestamp`/`timestamptz`.
    private func parseDate(_ raw: String) -> Date {
        if let date = Self.dateOnlyFormatter.date(from: raw) {
            return date
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw) ?? .now
    }

    func addPatient(firstName: String, lastName: String, status: PatientStatus = .active) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }

        let record = NewPatientRecord(
            firstName: firstName,
            lastName: lastName,
            active: status == .active
        )
        let inserted: InsertedRow = try await client.from("Patients")
            .insert(record)
            .select("id")
            .single()
            .execute()
            .value

        patients.append(Patient(databaseID: inserted.id, firstName: firstName, lastName: lastName, status: status))
    }

    /// Formatter for Postgres `date` columns (no time component).
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Inserts the session into the `Sessions` table and, on success, attaches
    /// it to the patient with the database ID returned by Supabase.
    func addSession(_ session: Session, for patient: Patient) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let patientID = patient.databaseID else { throw PatientStoreError.patientNotSaved }

        let trimmedNotes = session.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = NewSessionRecord(
            patientID: patientID,
            sessionDate: Self.dateOnlyFormatter.string(from: session.date),
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        let inserted: InsertedRow = try await client.from("Sessions")
            .insert(record)
            .select("id")
            .single()
            .execute()
            .value

        session.databaseID = inserted.id
        patient.sessions.append(session)
    }

    /// Persists date and notes changes of an already-saved session.
    func updateSession(_ session: Session) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let sessionID = session.databaseID else { throw PatientStoreError.sessionNotSaved }

        let trimmedNotes = session.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = UpdatedSessionRecord(
            sessionDate: Self.dateOnlyFormatter.string(from: session.date),
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        // Select the updated rows back: with row-level security a blocked
        // update "succeeds" with zero rows, which must not pass as saved.
        let updated: [InsertedRow] = try await client.from("Sessions")
            .update(record)
            .eq("id", value: sessionID.queryValue)
            .select("id")
            .execute()
            .value
        guard !updated.isEmpty else { throw PatientStoreError.updateRejected }
    }

    /// Saves a completed combined mood questionnaire for a session as a
    /// single row with the GAD-7 and PHQ-9 answers side by side.
    ///
    /// Upserts on `session_id`, so re-saving a session's questionnaire
    /// updates its existing row instead of adding a duplicate.
    func saveQuestionnaire(_ questionnaire: CombinedMoodQuestionnaire,
                           for patient: Patient,
                           session: Session) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let patientID = patient.databaseID else { throw PatientStoreError.patientNotSaved }
        guard let sessionID = session.databaseID else { throw PatientStoreError.sessionNotSaved }

        let record = NewQuestionnaireRecord(
            patientID: patientID,
            sessionID: sessionID,
            answeredDate: Self.dateOnlyFormatter.string(from: session.date),
            gad7Answers: questionnaire.gad7Answers.compactMap { $0 },
            phq9Answers: questionnaire.phq9Answers.compactMap { $0 },
            interferenceLevel: questionnaire.interferenceLevel,
            combinedNotes: QuestionnaireNotes(
                gad7: questionnaire.gad7Notes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                phq9: questionnaire.phq9Notes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                interference: questionnaire.interferenceNote.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        let saved: InsertedRow = try await client.from(CombinedMoodQuestionnaire.tableName)
            .upsert(record, onConflict: "session_id")
            .select("id")
            .single()
            .execute()
            .value

        // Keep the cache in sync so the history views stay fresh offline.
        let completed = CompletedQuestionnaire(
            databaseID: saved.id,
            sessionID: sessionID,
            answeredDate: session.date,
            questionnaire: questionnaire
        )
        var cached = questionnairesByPatient[patientID] ?? []
        cached.removeAll { $0.sessionID == sessionID }
        cached.append(completed)
        cached.sort { $0.answeredDate > $1.answeredDate }
        questionnairesByPatient[patientID] = cached
    }

    /// Loads all saved questionnaires of a patient, newest first, and
    /// refreshes the cache.
    func loadQuestionnaires(for patient: Patient) async throws -> [CompletedQuestionnaire] {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let patientID = patient.databaseID else { throw PatientStoreError.patientNotSaved }

        let rows: [QuestionnaireRow] = try await client.from(CombinedMoodQuestionnaire.tableName)
            .select("id, session_id, answered_date, gad7_answers, phq9_answers, interference_level, combined_notes")
            .eq("patient_id", value: patientID.queryValue)
            .order("answered_date", ascending: false)
            .execute()
            .value

        let questionnaires = rows.map { row in
            var questionnaire = CombinedMoodQuestionnaire()
            questionnaire.gad7Answers = Self.paddedAnswers(row.gad7Answers, count: QuestionnaireText.gad7Questions.count)
            questionnaire.phq9Answers = Self.paddedAnswers(row.phq9Answers, count: QuestionnaireText.phq9Questions.count)
            questionnaire.interferenceLevel = row.interferenceLevel
            questionnaire.gad7Notes = Self.paddedNotes(row.combinedNotes?.gad7, count: QuestionnaireText.gad7Questions.count)
            questionnaire.phq9Notes = Self.paddedNotes(row.combinedNotes?.phq9, count: QuestionnaireText.phq9Questions.count)
            questionnaire.interferenceNote = row.combinedNotes?.interference ?? ""
            return CompletedQuestionnaire(
                databaseID: row.id,
                sessionID: row.sessionID,
                answeredDate: row.answeredDate.map(parseDate) ?? .now,
                questionnaire: questionnaire
            )
        }
        questionnairesByPatient[patientID] = questionnaires
        return questionnaires
    }

    /// Fits a stored notes array to the expected question count.
    private static func paddedNotes(_ values: [String]?, count: Int) -> [String] {
        var result = values ?? []
        if result.count > count {
            result.removeLast(result.count - count)
        } else if result.count < count {
            result.append(contentsOf: Array(repeating: "", count: count - result.count))
        }
        return result
    }

    /// Fits a stored answers array to the expected question count, padding
    /// missing slots with `nil` so old or malformed rows still display.
    private static func paddedAnswers(_ values: [Int]?, count: Int) -> [Int?] {
        var result: [Int?] = (values ?? []).map { $0 }
        if result.count > count {
            result.removeLast(result.count - count)
        } else if result.count < count {
            result.append(contentsOf: Array(repeating: nil, count: count - result.count))
        }
        return result
    }
}
