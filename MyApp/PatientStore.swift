import SwiftUI
import OSLog
import Supabase

/// Errors from saving patients, sessions, and questionnaires.
enum PatientStoreError: LocalizedError {
    case patientNotSaved
    case sessionNotSaved
    case updateRejected

    var errorDescription: String? {
        switch self {
        case .patientNotSaved:
            return L10n.patientNotSavedError
        case .sessionNotSaved:
            return L10n.sessionNotSavedError
        case .updateRejected:
            return L10n.updateRejectedError
        }
    }
}

/// The `id` column of a freshly inserted row.
private nonisolated struct InsertedRow: Decodable {
    let id: DatabaseID
}

/// Row shape for inserts into the `Patients` table. The name is deliberately
/// not sent: it lives only in the local identity store.
private nonisolated struct NewPatientRecord: Encodable {
    let active: Bool
}

/// Row shape for inserts into the `Sessions` table.
private nonisolated struct NewSessionRecord: Encodable {
    let patientID: DatabaseID
    let sessionDate: String
    let notes: String?
    let sessionType: SessionType?
    let structuredNotes: WhisperService.CBTSessionAnalysis?

    enum CodingKeys: String, CodingKey {
        case patientID = "patient_id"
        case sessionDate = "session_date"
        case notes
        case sessionType = "type"
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

/// Row shape for selects from the `Patients` table. Names are deliberately
/// not selected: they come from the local identity store, and are being
/// removed from the backend entirely.
private nonisolated struct PatientRow: Decodable {
    let id: DatabaseID
    let active: Bool?
    let notes: String?
    let patientFormulation: PatientFormulation?

    enum CodingKeys: String, CodingKey {
        case id
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
    let sessionType: SessionType?
    let structuredNotes: WhisperService.CBTSessionAnalysis?

    enum CodingKeys: String, CodingKey {
        case id
        case patientID = "patient_id"
        case sessionDate = "session_date"
        case notes
        case sessionType = "type"
        case structuredNotes = "structured_notes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(DatabaseID.self, forKey: .id)
        patientID = try container.decode(DatabaseID.self, forKey: .patientID)
        sessionDate = try container.decode(String.self, forKey: .sessionDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        sessionType = try container.decodeIfPresent(SessionType.self, forKey: .sessionType)
        // Fail-soft: analyses saved under the old schema don't decode and
        // are deliberately dropped instead of failing the whole fetch.
        structuredNotes = (try? container.decodeIfPresent(
            WhisperService.CBTSessionAnalysis.self, forKey: .structuredNotes)) ?? nil
        if structuredNotes == nil, container.contains(.structuredNotes) {
            let sessionID = id.queryValue
            AppLog.store.warning("Dropped undecodable structured notes on session \(sessionID, privacy: .public) (old schema)")
        }
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
    let sessionType: SessionType?
    let structuredNotes: WhisperService.CBTSessionAnalysis?

    enum CodingKeys: String, CodingKey {
        case sessionDate = "session_date"
        case notes
        case sessionType = "type"
        case structuredNotes = "structured_notes"
    }

    // Encode the type explicitly so clearing it writes NULL instead of
    // leaving the column untouched (synthesized encoding skips nil keys).
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionDate, forKey: .sessionDate)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(sessionType, forKey: .sessionType)
        try container.encodeIfPresent(structuredNotes, forKey: .structuredNotes)
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
    /// Optional so cache files written before session types existed decode.
    let type: SessionType?
    /// Optional so cache files written before structured notes existed decode.
    let structuredNotes: WhisperService.CBTSessionAnalysis?

    init(databaseID: DatabaseID?, date: Date, notes: String,
         type: SessionType?, structuredNotes: WhisperService.CBTSessionAnalysis?) {
        self.databaseID = databaseID
        self.date = date
        self.notes = notes
        self.type = type
        self.structuredNotes = structuredNotes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        databaseID = try container.decodeIfPresent(DatabaseID.self, forKey: .databaseID)
        date = try container.decode(Date.self, forKey: .date)
        notes = try container.decode(String.self, forKey: .notes)
        type = try container.decodeIfPresent(SessionType.self, forKey: .type)
        // Fail-soft: analyses cached under the old schema don't decode and
        // are deliberately dropped instead of failing the whole cache.
        structuredNotes = (try? container.decodeIfPresent(
            WhisperService.CBTSessionAnalysis.self, forKey: .structuredNotes)) ?? nil
        if structuredNotes == nil, container.contains(.structuredNotes) {
            AppLog.store.warning("Dropped undecodable cached structured notes (old schema)")
        }
    }
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

    /// Gate every patient-related free text must pass before an upload:
    /// unchanged text loaded from Supabase goes through untouched, anything
    /// new or edited is anonymized first. Kept here — the app's single
    /// Supabase write path — so no screen can bypass it.
    private let textGate: ClinicalTextGate

    var patients: [Patient] = []

    /// Local patientID → name store, populated whenever the patient list
    /// loads (Phase 1 of moving patient names off the backend).
    private let identityStore = PatientIdentityStore()

    /// Cache of each patient's saved questionnaires (newest first), keyed by
    /// the patient's database ID. Filled by `loadQuestionnaires` and kept in
    /// sync by `saveQuestionnaire`.
    private(set) var questionnairesByPatient: [DatabaseID: [CompletedQuestionnaire]] = [:]

    /// `anonymizeText` overrides the anonymization call, for tests only;
    /// the app always uses `ClinicalTextAnonymizer` on the shared client.
    init(client: SupabaseClient,
         anonymizeText: (@Sendable (String) async throws -> String)? = nil) {
        self.client = client
        let anonymizer = ClinicalTextAnonymizer(client: client)
        textGate = ClinicalTextGate(
            anonymize: anonymizeText ?? { try await anonymizer.anonymize($0) }
        )
    }

    // MARK: - Anonymization gate helpers

    /// Marks a formulation's free-text fields as already safely stored.
    private func markFormulationSafe(_ formulation: PatientFormulation?) {
        guard let formulation else { return }
        textGate.markSafe(formulation.treatmentGoal)
        textGate.markSafe(formulation.coreBelief)
        formulation.keyAutomaticThoughts.forEach { textGate.markSafe($0) }
        formulation.maintainingBehaviors.forEach { textGate.markSafe($0) }
        textGate.markSafe(formulation.therapistHypothesis)
        if let cycle = formulation.keyCBTCycle {
            markCycleSafe(cycle)
        }
    }

    private func markCycleSafe(_ cycle: CBTCycle) {
        textGate.markSafe(cycle.triggerSituation)
        textGate.markSafe(cycle.automaticThought)
        textGate.markSafe(cycle.emotion)
        textGate.markSafe(cycle.behavior)
        textGate.markSafe(cycle.shortTermConsequence)
        textGate.markSafe(cycle.longTermConsequence)
        textGate.markSafe(cycle.evidence)
    }

    /// Marks an AI analysis' text fields as safe to persist. Called for
    /// analyses loaded back from the database and — via
    /// `registerAIAnalysis` — for fresh Edge Function output, so only the
    /// therapist's own edits to a summary go through anonymization.
    private func markAnalysisSafe(_ analysis: WhisperService.CBTSessionAnalysis?) {
        guard let analysis else { return }
        textGate.markSafe(analysis.sessionSummary)
        for situation in analysis.keySituations {
            textGate.markSafe(situation.situation)
            textGate.markSafe(situation.whyItMatters)
        }
        for nat in analysis.possibleNats {
            textGate.markSafe(nat.thought)
            textGate.markSafe(nat.situation)
            textGate.markSafe(nat.emotion)
            textGate.markSafe(nat.behavior)
        }
        for question in analysis.followUpQuestions {
            textGate.markSafe(question.question)
            textGate.markSafe(question.reason)
        }
    }

    /// Anonymizes text on behalf of a view flow (e.g. a fresh voice
    /// transcription) through the same gate every save uses, so the result
    /// can be shown in a field and saved afterwards without a second call.
    func anonymizedText(_ text: String) async throws -> String {
        try await textGate.prepare(text) ?? ""
    }

    /// Registers a fresh AI-generated session analysis so its unedited text
    /// is not sent back through the anonymizer when it is saved. The
    /// analysis was produced server-side, not entered by the user; any field
    /// the therapist later edits leaves this set and is anonymized on save.
    func registerAIAnalysis(_ analysis: WhisperService.CBTSessionAnalysis) {
        markAnalysisSafe(analysis)
    }

    /// A copy of the formulation in which every free-text field is safe to
    /// upload. Throws before anything was sent if any field fails.
    private func anonymized(_ formulation: PatientFormulation) async throws -> PatientFormulation {
        var result = formulation
        result.treatmentGoal = try await textGate.prepare(formulation.treatmentGoal ?? "")
        result.coreBelief = try await textGate.prepare(formulation.coreBelief ?? "")
        result.keyAutomaticThoughts = try await textGate.prepare(notes: formulation.keyAutomaticThoughts)
        result.maintainingBehaviors = try await textGate.prepare(notes: formulation.maintainingBehaviors)
        result.therapistHypothesis = try await textGate.prepare(formulation.therapistHypothesis ?? "")
        if let cycle = formulation.keyCBTCycle {
            // `evidence` is immutable, so the anonymized copy is rebuilt.
            result.keyCBTCycle = CBTCycle(
                triggerSituation: try await textGate.prepare(cycle.triggerSituation ?? ""),
                automaticThought: try await textGate.prepare(cycle.automaticThought ?? ""),
                emotion: try await textGate.prepare(cycle.emotion ?? ""),
                behavior: try await textGate.prepare(cycle.behavior ?? ""),
                shortTermConsequence: try await textGate.prepare(cycle.shortTermConsequence ?? ""),
                longTermConsequence: try await textGate.prepare(cycle.longTermConsequence ?? ""),
                evidence: try await textGate.prepare(cycle.evidence) ?? "",
                confidence: cycle.confidence
            )
        }
        return result
    }

    /// A copy of the analysis in which every therapist-editable text field
    /// is safe to upload. Fields still holding the untouched AI output are
    /// registered as safe and skip the Edge Function.
    private func anonymized(
        _ analysis: WhisperService.CBTSessionAnalysis?
    ) async throws -> WhisperService.CBTSessionAnalysis? {
        guard var result = analysis else { return nil }
        result.sessionSummary = try await textGate.prepare(result.sessionSummary) ?? ""
        for index in result.keySituations.indices {
            result.keySituations[index].situation =
                try await textGate.prepare(result.keySituations[index].situation) ?? ""
            result.keySituations[index].whyItMatters =
                try await textGate.prepare(result.keySituations[index].whyItMatters) ?? ""
        }
        for index in result.possibleNats.indices {
            result.possibleNats[index].thought =
                try await textGate.prepare(result.possibleNats[index].thought) ?? ""
            result.possibleNats[index].situation =
                try await textGate.prepare(result.possibleNats[index].situation) ?? ""
            result.possibleNats[index].emotion =
                try await textGate.prepare(result.possibleNats[index].emotion ?? "")
            result.possibleNats[index].behavior =
                try await textGate.prepare(result.possibleNats[index].behavior ?? "")
        }
        for index in result.followUpQuestions.indices {
            result.followUpQuestions[index].question =
                try await textGate.prepare(result.followUpQuestions[index].question) ?? ""
            result.followUpQuestions[index].reason =
                try await textGate.prepare(result.followUpQuestions[index].reason) ?? ""
        }
        return result
    }

    /// The cached questionnaires of a patient, if they were loaded before.
    func cachedQuestionnaires(for patient: Patient) -> [CompletedQuestionnaire]? {
        questionnairesByPatient[patient.id]
    }

    /// Replaces the in-memory patient list with the contents of the
    /// `Patients` and `Sessions` tables.
    func loadPatients() async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }

        let patientRows: [PatientRow] = try await client.from("Patients")
            .select("id, active, notes, formulation")
            .execute()
            .value
        let sessionRows: [SessionRow] = try await client.from("Sessions")
            .select("id, patient_id, session_date, notes, type, structured_notes")
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
        let loadedPatients = patientRows.map { row in
            let patient = existingPatients.first { $0.id == row.id }
                ?? Patient(id: row.id)
            patient.status = (row.active ?? true) ? .active : .inactive
            patient.notes = row.notes ?? ""
            // Everything read back from Supabase is already anonymized, so
            // re-saving it unchanged must not call the Edge Function again.
            textGate.markSafe(row.notes)
            markFormulationSafe(row.patientFormulation)
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
                    session.type = sessionRow.sessionType
                    session.structuredNotes = sessionRow.structuredNotes
                    textGate.markSafe(sessionRow.notes)
                    markAnalysisSafe(sessionRow.structuredNotes)
                    return session
                }
                .sorted { $0.date < $1.date }
            return patient
        }
        // Names are never loaded from the backend — the identity store is
        // their only source.
        for patient in loadedPatients {
            patient.localName = identityStore.name(for: patient.id)
        }
        patients = loadedPatients
        AppLog.store.info("Patients loaded from server: \(patientRows.count), sessions: \(sessionRows.count)")
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
        // Entries without a database ID (pre-migration cache formats) are
        // dropped: patient identity is always server-assigned, and the next
        // network load restores them anyway.
        patients = cached.compactMap { cachedPatient in
            guard let id = cachedPatient.databaseID else { return nil }
            let patient = Patient(
                id: id,
                firstName: cachedPatient.firstName,
                lastName: cachedPatient.lastName,
                status: cachedPatient.active ? .active : .inactive,
                notes: cachedPatient.notes ?? "",
                sessions: cachedPatient.sessions.map {
                    Session(databaseID: $0.databaseID, date: $0.date, notes: $0.notes,
                            type: $0.type, structuredNotes: $0.structuredNotes)
                }
            )
            patient.formulation = cachedPatient.formulation
            // Cache loads only read names, never write them: the identity
            // store is filled exclusively from fresh server data.
            patient.localName = identityStore.name(for: patient.id)
            return patient
        }
        AppLog.store.info("Patients restored from disk cache: \(self.patients.count)")
    }

    /// Writes the current patient list to the cache file. Patient data is
    /// sensitive, so the file is written with complete file protection.
    private func saveCachedPatients() {
        let snapshot = patients.map { patient in
            CachedPatient(
                databaseID: patient.id,
                firstName: patient.firstName,
                lastName: patient.lastName,
                active: patient.status == .active,
                notes: patient.notes,
                sessions: patient.sessions.map {
                    CachedSession(databaseID: $0.databaseID, date: $0.date, notes: $0.notes,
                                  type: $0.type, structuredNotes: $0.structuredNotes)
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
    }

    /// Removes everything stored locally for the signed-in user — caches,
    /// saved preparations, and the locally kept patient names — used after
    /// the account itself is deleted.
    func wipeLocalData() {
        for patient in patients {
            try? identityStore.delete(patientID: patient.id)
            SavedPreparation.delete(for: patient.id)
        }
        clearAllCaches()
        AppLog.store.notice("Local data wiped after account deletion")
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

        let record = NewPatientRecord(active: status == .active)
        let inserted: InsertedRow = try await client.from("Patients")
            .insert(record)
            .select("id")
            .single()
            .execute()
            .value

        let patient = Patient(id: inserted.id, firstName: firstName, lastName: lastName, status: status)
        // The local store will eventually be the only place the name exists
        // (it is being removed from the backend), so it must be written the
        // moment the patient is created — before the name is read back.
        identityStore.upsertIdentities(for: [patient])
        patient.localName = identityStore.name(for: patient.id)
        patients.append(patient)
        AppLog.store.info("Patient added: \(inserted.id.queryValue, privacy: .public)")
        saveCachedPatients()
    }

    /// Renames a patient. The name lives only in the local Keychain identity
    /// store — it is never sent to the backend.
    func renamePatient(_ patient: Patient, firstName: String, lastName: String) throws {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !name.isEmpty else { return }
        try identityStore.save(patientID: patient.id, name: name)
        patient.localName = name
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
        let patientID = patient.id

        // Anonymize every field before anything is sent; a failure aborts
        // the whole insert without uploading any original text.
        let anonymizedNotes = try await textGate.prepare(session.notes)
        let anonymizedAnalysis = try await anonymized(session.structuredNotes)
        let record = NewSessionRecord(
            patientID: patientID,
            sessionDate: Self.dateOnlyFormatter.string(from: session.date),
            notes: anonymizedNotes,
            sessionType: session.type,
            structuredNotes: anonymizedAnalysis
        )
        let inserted: InsertedRow = try await client.from("Sessions")
            .insert(record)
            .select("id")
            .single()
            .execute()
            .value

        // The local model mirrors what the server now stores.
        session.notes = anonymizedNotes ?? ""
        session.structuredNotes = anonymizedAnalysis
        session.databaseID = inserted.id
        patient.sessions.append(session)
        AppLog.store.info("Session added: \(inserted.id.queryValue, privacy: .public) for patient \(patientID.queryValue, privacy: .public)")
        saveCachedPatients()
    }

    /// Persists the therapist's formulation: in memory and the local cache
    /// immediately, then the patient's `patient_formulation` column.
    func saveFormulation(_ formulation: PatientFormulation, for patient: Patient) async throws {
        patient.formulation = formulation
        saveCachedPatients()

        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        let patientID = patient.id

        // Anonymize every free-text field before anything is sent; a
        // failure aborts the update without uploading any original text.
        // (The local write above is unaffected — it never leaves the device.)
        let anonymizedFormulation = try await anonymized(formulation)
        // Select the updated rows back: with row-level security a blocked
        // update "succeeds" with zero rows, which must not pass as saved.
        let updated: [InsertedRow] = try await client.from("Patients")
            .update(UpdatedPatientFormulationRecord(patientFormulation: anonymizedFormulation))
            .eq("id", value: patientID.queryValue)
            .select("id")
            .execute()
            .value
        guard !updated.isEmpty else { throw PatientStoreError.updateRejected }
        // The local model mirrors what the server now stores.
        patient.formulation = anonymizedFormulation
        saveCachedPatients()
    }

    /// Persists notes changes of an already-saved patient.
    func updatePatientNotes(_ patient: Patient) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        let patientID = patient.id

        // Anonymize before anything is sent; a failure aborts the update
        // without uploading the original text.
        let anonymizedNotes = try await textGate.prepare(patient.notes)
        // Select the updated rows back: with row-level security a blocked
        // update "succeeds" with zero rows, which must not pass as saved.
        let updated: [InsertedRow] = try await client.from("Patients")
            .update(UpdatedPatientNotesRecord(notes: anonymizedNotes))
            .eq("id", value: patientID.queryValue)
            .select("id")
            .execute()
            .value
        guard !updated.isEmpty else { throw PatientStoreError.updateRejected }
        // The local model mirrors what the server now stores.
        patient.notes = anonymizedNotes ?? ""
        saveCachedPatients()
    }

    /// Persists date and notes changes of an already-saved session.
    func updateSession(_ session: Session) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let sessionID = session.databaseID else { throw PatientStoreError.sessionNotSaved }

        // Anonymize every field before anything is sent; a failure aborts
        // the whole update without uploading any original text.
        let anonymizedNotes = try await textGate.prepare(session.notes)
        let anonymizedAnalysis = try await anonymized(session.structuredNotes)
        let record = UpdatedSessionRecord(
            sessionDate: Self.dateOnlyFormatter.string(from: session.date),
            notes: anonymizedNotes,
            sessionType: session.type,
            structuredNotes: anonymizedAnalysis
        )
        // Select the updated rows back: with row-level security a blocked
        // update "succeeds" with zero rows, which must not pass as saved.
        let updated: [InsertedRow] = try await client.from("Sessions")
            .update(record)
            .eq("id", value: sessionID.queryValue)
            .select("id")
            .execute()
            .value
        guard !updated.isEmpty else {
            AppLog.store.error("Session update rejected: \(sessionID.queryValue, privacy: .public)")
            throw PatientStoreError.updateRejected
        }
        // The local model mirrors what the server now stores.
        session.notes = anonymizedNotes ?? ""
        session.structuredNotes = anonymizedAnalysis
        AppLog.store.info("Session updated: \(sessionID.queryValue, privacy: .public)")
        saveCachedPatients()
    }

    /// Deletes a saved session's row and removes it from its patient.
    func deleteSession(_ session: Session, for patient: Patient) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let sessionID = session.databaseID else { throw PatientStoreError.sessionNotSaved }

        // Select the deleted rows back: with row-level security a blocked
        // delete "succeeds" with zero rows, which must not pass as deleted.
        let deleted: [InsertedRow] = try await client.from("Sessions")
            .delete()
            .eq("id", value: sessionID.queryValue)
            .select("id")
            .execute()
            .value
        guard !deleted.isEmpty else {
            AppLog.store.error("Session delete rejected: \(sessionID.queryValue, privacy: .public)")
            throw PatientStoreError.updateRejected
        }

        patient.sessions.removeAll { $0.id == session.id }
        AppLog.store.notice("Session deleted: \(sessionID.queryValue, privacy: .public)")
        saveCachedPatients()
    }

    /// Deletes a patient's row and removes the patient locally, including
    /// the locally stored name and any cached questionnaires and images.
    func deletePatient(_ patient: Patient) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }

        // Select the deleted rows back: with row-level security a blocked
        // delete "succeeds" with zero rows, which must not pass as deleted.
        let deleted: [InsertedRow] = try await client.from("Patients")
            .delete()
            .eq("id", value: patient.id.queryValue)
            .select("id")
            .execute()
            .value
        guard !deleted.isEmpty else {
            AppLog.store.error("Patient delete rejected: \(patient.id.queryValue, privacy: .public)")
            throw PatientStoreError.updateRejected
        }

        questionnairesByPatient[patient.id] = nil
        try? identityStore.delete(patientID: patient.id)
        patients.removeAll { $0.id == patient.id }
        AppLog.store.notice("Patient deleted: \(patient.id.queryValue, privacy: .public)")
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
        let patientID = patient.id
        guard let sessionID = session.databaseID else { throw PatientStoreError.sessionNotSaved }

        // Anonymize every changed, non-empty note separately — each stays at
        // its own question index — before anything is sent. One failure
        // aborts the whole save without uploading any original text.
        var anonymizedQuestionnaire = questionnaire
        anonymizedQuestionnaire.gad7Notes = try await textGate.prepare(notes: questionnaire.gad7Notes)
        anonymizedQuestionnaire.phq9Notes = try await textGate.prepare(notes: questionnaire.phq9Notes)
        anonymizedQuestionnaire.interferenceNote =
            try await textGate.prepare(questionnaire.interferenceNote) ?? ""

        let record = NewQuestionnaireRecord(
            patientID: patientID,
            sessionID: sessionID,
            answeredDate: Self.dateOnlyFormatter.string(from: session.date),
            gad7Answers: anonymizedQuestionnaire.gad7Answers.compactMap { $0 },
            phq9Answers: anonymizedQuestionnaire.phq9Answers.compactMap { $0 },
            interferenceLevel: anonymizedQuestionnaire.interferenceLevel,
            combinedNotes: QuestionnaireNotes(
                gad7: anonymizedQuestionnaire.gad7Notes,
                phq9: anonymizedQuestionnaire.phq9Notes,
                interference: anonymizedQuestionnaire.interferenceNote
            )
        )
        let saved: InsertedRow = try await client.from(CombinedMoodQuestionnaire.tableName)
            .upsert(record, onConflict: "session_id")
            .select("id")
            .single()
            .execute()
            .value

        // The in-memory copy mirrors what the server now stores.
        session.questionnaire = anonymizedQuestionnaire
        // Keep the cache in sync so the history views stay fresh offline.
        let completed = CompletedQuestionnaire(
            databaseID: saved.id,
            sessionID: sessionID,
            answeredDate: session.date,
            questionnaire: anonymizedQuestionnaire
        )
        var cached = questionnairesByPatient[patientID] ?? []
        cached.removeAll { $0.sessionID == sessionID }
        cached.append(completed)
        cached.sort { $0.answeredDate > $1.answeredDate }
        questionnairesByPatient[patientID] = cached
        AppLog.store.info("Questionnaire saved for session \(sessionID.queryValue, privacy: .public)")
    }

    /// Deletes a session's saved questionnaire row and removes it from the
    /// cache.
    func deleteQuestionnaire(for patient: Patient, session: Session) async throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let sessionID = session.databaseID else { throw PatientStoreError.sessionNotSaved }

        // Select the deleted rows back: with row-level security a blocked
        // delete "succeeds" with zero rows, which must not pass as deleted.
        let deleted: [InsertedRow] = try await client.from(CombinedMoodQuestionnaire.tableName)
            .delete()
            .eq("session_id", value: sessionID.queryValue)
            .select("id")
            .execute()
            .value
        guard !deleted.isEmpty else {
            AppLog.store.error("Questionnaire delete rejected for session \(sessionID.queryValue, privacy: .public)")
            throw PatientStoreError.updateRejected
        }

        questionnairesByPatient[patient.id]?.removeAll { $0.sessionID == sessionID }
        AppLog.store.notice("Questionnaire deleted for session \(sessionID.queryValue, privacy: .public)")
    }

    /// Loads all saved questionnaires of a patient, newest first, and
    /// refreshes the cache.
    func loadQuestionnaires(for patient: Patient) async throws -> [CompletedQuestionnaire] {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        let patientID = patient.id

        let rows: [QuestionnaireRow] = try await client.from(CombinedMoodQuestionnaire.tableName)
            .select("id, session_id, answered_date, gad7_answers, phq9_answers, interference_level, combined_notes")
            .eq("patient_id", value: patientID.queryValue)
            .order("answered_date", ascending: false)
            .execute()
            .value

        let questionnaires = rows.map { row in
            var questionnaire = CombinedMoodQuestionnaire()
            questionnaire.gad7Answers = Self.paddedAnswers(row.gad7Answers, count: L10n.gad7Questions.count)
            questionnaire.phq9Answers = Self.paddedAnswers(row.phq9Answers, count: L10n.phq9Questions.count)
            questionnaire.interferenceLevel = row.interferenceLevel
            questionnaire.gad7Notes = Self.paddedNotes(row.combinedNotes?.gad7, count: L10n.gad7Questions.count)
            questionnaire.phq9Notes = Self.paddedNotes(row.combinedNotes?.phq9, count: L10n.phq9Questions.count)
            questionnaire.interferenceNote = row.combinedNotes?.interference ?? ""
            // Notes read back from Supabase are already anonymized, so
            // re-saving them unchanged must not call the Edge Function again.
            questionnaire.gad7Notes.forEach { textGate.markSafe($0) }
            questionnaire.phq9Notes.forEach { textGate.markSafe($0) }
            textGate.markSafe(questionnaire.interferenceNote)
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
