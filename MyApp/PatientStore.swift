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
    let structuredNotes: WhisperService.CBTSessionAnalysis?

    enum CodingKeys: String, CodingKey {
        case patientID = "patient_id"
        case sessionDate = "session_date"
        case notes
        case structuredNotes = "structured_notes"
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
    let notes: String?
    let patientFormulation: PatientFormulation?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case active
        case notes
        case patientFormulation = "formulation"
    }
}

/// Row shape for updates of a patient's formulation.
private nonisolated struct UpdatedPatientFormulationRecord: Encodable {
    let patientFormulation: PatientFormulation

    enum CodingKeys: String, CodingKey {
        case patientFormulation = "formulation"
    }
}

/// Row shape for selects from the `Sessions` table.
private nonisolated struct SessionRow: Decodable {
    let id: DatabaseID
    let patientID: DatabaseID
    let sessionDate: String
    let notes: String?
    let structuredNotes: WhisperService.CBTSessionAnalysis?

    enum CodingKeys: String, CodingKey {
        case id
        case patientID = "patient_id"
        case sessionDate = "session_date"
        case notes
        case structuredNotes = "structured_notes"
    }
}

/// Row shape for updates of a patient's notes.
private nonisolated struct UpdatedPatientNotesRecord: Encodable {
    let notes: String?
}

/// Row shape for updates of an existing `Sessions` row.
private nonisolated struct UpdatedSessionRecord: Encodable {
    let sessionDate: String
    let notes: String?
    let structuredNotes: WhisperService.CBTSessionAnalysis?

    enum CodingKeys: String, CodingKey {
        case sessionDate = "session_date"
        case notes
        case structuredNotes = "structured_notes"
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

/// Disk-cache snapshot of a session.
private nonisolated struct CachedSession: Codable {
    let databaseID: DatabaseID?
    let date: Date
    let notes: String
    /// Optional so cache files written before structured notes existed decode.
    let structuredNotes: WhisperService.CBTSessionAnalysis?
}

/// Disk-cache snapshot of a patient.
private nonisolated struct CachedPatient: Codable {
    let databaseID: DatabaseID?
    let firstName: String
    let lastName: String
    let active: Bool
    /// Optional so cache files written before notes existed still decode.
    let notes: String?
    let sessions: [CachedSession]
    /// The therapist's formulation lives only in this cache, never in the
    /// database. Optional so older cache files still decode.
    let formulation: PatientFormulation?
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
            .select("id, first_name, last_name, active, notes, formulation")
            .execute()
            .value
        let sessionRows: [SessionRow] = try await client.from("Sessions")
            .select("id, patient_id, session_date, notes, structured_notes")
            .execute()
            .value

        var sessionRowsByPatient: [DatabaseID: [SessionRow]] = [:]
        for row in sessionRows {
            sessionRowsByPatient[row.patientID, default: []].append(row)
        }

        // Update existing objects in place instead of replacing them: views
        // hold Patient/Session references across reloads, and replacing the
        // instances splits the object graph — edits land on an object the
        // store no longer shows (or vice versa).
        let existingPatients = patients
        patients = patientRows.map { row in
            let patient = existingPatients.first { $0.databaseID == row.id }
                ?? Patient(databaseID: row.id)
            patient.firstName = row.firstName ?? ""
            patient.lastName = row.lastName ?? ""
            patient.status = (row.active ?? true) ? .active : .inactive
            patient.notes = row.notes ?? ""
            // A null column never clears a local formulation: the app never
            // deletes formulations server-side, so null just means "not
            // saved to the DB yet" (e.g. written before this column existed).
            if let formulation = row.patientFormulation {
                patient.formulation = formulation
            }

            let existingSessions = patient.sessions
            patient.sessions = (sessionRowsByPatient[row.id] ?? [])
                .map { sessionRow in
                    let session = existingSessions.first { $0.databaseID == sessionRow.id }
                        ?? Session(databaseID: sessionRow.id)
                    session.date = parseDate(sessionRow.sessionDate)
                    session.notes = sessionRow.notes ?? ""
                    session.structuredNotes = sessionRow.structuredNotes
                    return session
                }
                .sorted { $0.date < $1.date }
            return patient
        }
        saveCachedPatients()
    }

    // MARK: - Patient disk cache

    /// Snapshot of the patient list, kept so the list shows instantly on the
    /// next launch (or offline) before the network load replaces it.
    private static var patientsCacheURL: URL {
        URL.cachesDirectory.appending(path: "patients-cache.json")
    }

    /// Fills the patient list from the last saved snapshot. Does nothing once
    /// patients are already loaded.
    func loadCachedPatients() {
        guard patients.isEmpty,
              let data = try? Data(contentsOf: Self.patientsCacheURL),
              let cached = try? JSONDecoder().decode([CachedPatient].self, from: data)
        else { return }
        patients = cached.map { cachedPatient in
            let patient = Patient(
                databaseID: cachedPatient.databaseID,
                firstName: cachedPatient.firstName,
                lastName: cachedPatient.lastName,
                status: cachedPatient.active ? .active : .inactive,
                notes: cachedPatient.notes ?? "",
                sessions: cachedPatient.sessions.map {
                    Session(databaseID: $0.databaseID, date: $0.date, notes: $0.notes,
                            structuredNotes: $0.structuredNotes)
                }
            )
            patient.formulation = cachedPatient.formulation
            return patient
        }
    }

    /// Writes the current patient list to the cache file. Patient data is
    /// sensitive, so the file is written with complete file protection.
    private func saveCachedPatients() {
        let snapshot = patients.map { patient in
            CachedPatient(
                databaseID: patient.databaseID,
                firstName: patient.firstName,
                lastName: patient.lastName,
                active: patient.status == .active,
                notes: patient.notes,
                sessions: patient.sessions.map {
                    CachedSession(databaseID: $0.databaseID, date: $0.date, notes: $0.notes,
                                  structuredNotes: $0.structuredNotes)
                },
                formulation: patient.formulation
            )
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: Self.patientsCacheURL, options: [.atomic, .completeFileProtection])
    }

    /// Removes the cached patient list, e.g. on sign-out.
    func clearCachedPatients() {
        try? FileManager.default.removeItem(at: Self.patientsCacheURL)
    }

    /// Clears everything cached for the signed-in user (disk snapshot and all
    /// in-memory data), so nothing leaks into the next session on sign-out.
    func clearAllCaches() {
        clearCachedPatients()
        patients = []
        questionnairesByPatient = [:]
        sessionImagesCache = [:]
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
        saveCachedPatients()
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
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            structuredNotes: session.structuredNotes
        )
        let inserted: InsertedRow = try await client.from("Sessions")
            .insert(record)
            .select("id")
            .single()
            .execute()
            .value

        session.databaseID = inserted.id
        patient.sessions.append(session)
        saveCachedPatients()
    }

    /// Persists the therapist's formulation: in memory and the local cache
    /// immediately, then the patient's `patient_formulation` column.
    func saveFormulation(_ formulation: PatientFormulation, for patient: Patient) async throws {
        patient.formulation = formulation
        saveCachedPatients()

        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let patientID = patient.databaseID else { throw PatientStoreError.patientNotSaved }

        // Select the updated rows back: with row-level security a blocked
        // update "succeeds" with zero rows, which must not pass as saved.
        let updated: [InsertedRow] = try await client.from("Patients")
            .update(UpdatedPatientFormulationRecord(patientFormulation: formulation))
            .eq("id", value: patientID.queryValue)
            .select("id")
            .execute()
            .value
        guard !updated.isEmpty else { throw PatientStoreError.updateRejected }
    }

    /// Persists notes changes of an already-saved patient.
    func updatePatientNotes(_ patient: Patient) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let patientID = patient.databaseID else { throw PatientStoreError.patientNotSaved }

        let trimmed = patient.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        // Select the updated rows back: with row-level security a blocked
        // update "succeeds" with zero rows, which must not pass as saved.
        let updated: [InsertedRow] = try await client.from("Patients")
            .update(UpdatedPatientNotesRecord(notes: trimmed.isEmpty ? nil : trimmed))
            .eq("id", value: patientID.queryValue)
            .select("id")
            .execute()
            .value
        guard !updated.isEmpty else { throw PatientStoreError.updateRejected }
        saveCachedPatients()
    }

    /// Persists date and notes changes of an already-saved session.
    func updateSession(_ session: Session) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let sessionID = session.databaseID else { throw PatientStoreError.sessionNotSaved }

        let trimmedNotes = session.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = UpdatedSessionRecord(
            sessionDate: Self.dateOnlyFormatter.string(from: session.date),
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            structuredNotes: session.structuredNotes
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
        saveCachedPatients()
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

    /// Name of the Supabase Storage bucket holding session images. Images
    /// live in one folder per session: `<session id>/<uuid>.jpg`.
    private static let sessionImagesBucket = "session-images"

    /// Cache of downloaded session images (file name + JPEG data), keyed by
    /// session database ID.
    private(set) var sessionImagesCache: [DatabaseID: [(fileName: String, data: Data)]] = [:]

    /// The cached images of a session, if they were loaded before.
    func cachedSessionImages(for session: Session) -> [(fileName: String, data: Data)]? {
        session.databaseID.flatMap { sessionImagesCache[$0] }
    }

    /// Downloads all images stored for a session and refreshes the cache.
    func loadSessionImages(for session: Session) async throws -> [(fileName: String, data: Data)] {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let sessionID = session.databaseID else { throw PatientStoreError.sessionNotSaved }

        let folder = sessionID.queryValue
        let bucket = client.storage.from(Self.sessionImagesBucket)
        let files = try await bucket.list(path: folder)

        var images: [(fileName: String, data: Data)] = []
        for file in files where file.name.lowercased().hasSuffix(".jpg") {
            let data = try await bucket.download(path: "\(folder)/\(file.name)")
            images.append((file.name, data))
        }
        sessionImagesCache[sessionID] = images
        return images
    }

    /// Uploads one session image and adds it to the cache.
    func uploadSessionImage(_ data: Data, fileName: String, for session: Session) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let sessionID = session.databaseID else { throw PatientStoreError.sessionNotSaved }

        _ = try await client.storage.from(Self.sessionImagesBucket).upload(
            "\(sessionID.queryValue)/\(fileName)",
            data: data,
            options: FileOptions(contentType: "image/jpeg")
        )
        sessionImagesCache[sessionID, default: []].append((fileName, data))
    }

    /// Deletes one stored session image and removes it from the cache.
    func deleteSessionImage(fileName: String, for session: Session) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let sessionID = session.databaseID else { throw PatientStoreError.sessionNotSaved }

        _ = try await client.storage.from(Self.sessionImagesBucket)
            .remove(paths: ["\(sessionID.queryValue)/\(fileName)"])
        sessionImagesCache[sessionID]?.removeAll { $0.fileName == fileName }
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
