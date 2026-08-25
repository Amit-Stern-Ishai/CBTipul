import SwiftUI

/// A primary-key value returned by Supabase.
///
/// Decodes both integer and UUID/text `id` columns so the app doesn't depend
/// on how the table's primary key is defined.
nonisolated enum DatabaseID: Codable, Hashable, Sendable {
    case integer(Int)
    case text(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else {
            self = .text(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let value): try container.encode(value)
        case .text(let value): try container.encode(value)
        }
    }

    /// The value used when filtering queries by this ID.
    var queryValue: String {
        switch self {
        case .integer(let value): return String(value)
        case .text(let value): return value
        }
    }
}

/// Whether a patient is currently in active treatment.
enum PatientStatus: String, CaseIterable, Identifiable {
    case active = "Active"
    case inactive = "Inactive"

    var id: String { rawValue }
}

/// The app-wide CBT cycle shape, defined by the AI response models and
/// reused for the therapist's own formulation.
typealias CBTCycle = WhisperService.NextSessionPreparation.CBTCycle

/// The therapist's own clinical formulation of a patient. Therapist-owned:
/// the AI never writes into it — future AI suggestions must be explicitly
/// accepted by the therapist. Stored in the local patient cache, not the DB.
nonisolated struct PatientFormulation: Codable, Equatable {
    var treatmentGoal: String?
    var coreBelief: String?
    var keyAutomaticThoughts: [String]
    var maintainingBehaviors: [String]
    var keyCBTCycle: CBTCycle?
    var therapistHypothesis: String?

    static let empty = PatientFormulation(
        treatmentGoal: nil,
        coreBelief: nil,
        keyAutomaticThoughts: [],
        maintainingBehaviors: [],
        keyCBTCycle: nil,
        therapistHypothesis: nil
    )
}

/// A patient tracked by the therapist.
@Observable
final class Patient: Identifiable {
    /// The row's primary key in the Supabase `Patients` table. Always
    /// assigned by the server; a patient object never exists without one.
    let id: DatabaseID
    var firstName: String
    var lastName: String
    var status: PatientStatus
    var notes: String
    var sessions: [Session]
    /// The therapist's own clinical formulation; kept out of `init` because
    /// it is loaded from the local cache, never from the database.
    var formulation: PatientFormulation?
    /// The name from the local identity store (Keychain); kept out of `init`
    /// because it is resolved after the store is updated, never passed in.
    /// Will become the only name once names are removed from the backend.
    var localName: String?

    init(id: DatabaseID,
         firstName: String = "",
         lastName: String = "",
         status: PatientStatus = .active,
         notes: String = "",
         sessions: [Session] = []) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.status = status
        self.notes = notes
        self.sessions = sessions
    }

    /// Full name as loaded from the backend; empty once the backend no
    /// longer stores names. This is what gets saved to the identity store,
    /// so it must never be derived from `localName`.
    var backendName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Full name for display: only the locally stored name. Deliberately no
    /// backend fallback (temporary), so a failing Keychain read is visible
    /// immediately instead of being masked by the server name.
    var displayName: String {
        if let localName, !localName.isEmpty { return localName }
        return L10n.unnamedPatient
    }

    /// The number of the most recent session (0 when there are none yet).
    var currentSessionNumber: Int { sessions.count }
}

extension Patient: Hashable {
    static func == (lhs: Patient, rhs: Patient) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// The stage of the treatment protocol a session belongs to. Raw values are
/// stored in the `type` column of the Supabase `Sessions` table.
nonisolated enum SessionType: String, Codable, CaseIterable {
    case firstPhoneCall = "first_phone_call"
    case intake
    case psychoEducation = "psycho_education"
    case diaryOne = "diary_one"
    case diaryTwo = "diary_two"
    case diaryThree = "diary_three"
    case caseFormulation = "case_formulation"
    case behavioralInterventions = "behavioral_interventions"
    case relapsePreventionAndTermination = "relapse_prevention_and_termination"
}

/// A single therapy session for a patient.
@Observable
final class Session: Identifiable {
    let id: UUID
    /// The row's primary key in the Supabase `Sessions` table, once saved.
    var databaseID: DatabaseID?
    var date: Date
    var notes: String
    /// The protocol stage of the session, once one has been picked.
    var type: SessionType?
    var questionnaire: CombinedMoodQuestionnaire
    /// AI-generated structured summary of the notes, once one has been saved.
    var structuredNotes: WhisperService.CBTSessionAnalysis?

    init(id: UUID = UUID(),
         databaseID: DatabaseID? = nil,
         date: Date = .now,
         notes: String = "",
         type: SessionType? = nil,
         questionnaire: CombinedMoodQuestionnaire = CombinedMoodQuestionnaire(),
         structuredNotes: WhisperService.CBTSessionAnalysis? = nil) {
        self.id = id
        self.databaseID = databaseID
        self.date = date
        self.notes = notes
        self.type = type
        self.questionnaire = questionnaire
        self.structuredNotes = structuredNotes
    }
}

/// Severity classification of a GAD-7 score.
enum GAD7Severity {
    case minimal      // 0–4
    case mild         // 5–9
    case substantial  // 10–14
    case extreme      // 15+

    init(score: Int) {
        switch score {
        case ..<5: self = .minimal
        case ..<10: self = .mild
        case ..<15: self = .substantial
        default: self = .extreme
        }
    }
}

/// Severity classification of a PHQ-9 score.
enum PHQ9Severity {
    case minimal          // 0–4
    case mild             // 5–9
    case moderate         // 10–14
    case moderatelySevere // 15–19
    case severe           // 20+

    init(score: Int) {
        switch score {
        case ..<5: self = .minimal
        case ..<10: self = .mild
        case ..<15: self = .moderate
        case ..<20: self = .moderatelySevere
        default: self = .severe
        }
    }
}

/// The combined mood questionnaire of a session: GAD-7 followed by PHQ-9.
///
/// Answers are stored as optional integers so an unanswered question can be
/// distinguished from an answer of `0`. Each answer is in the range 0...3.
struct CombinedMoodQuestionnaire {
    /// The Supabase table combined questionnaires are saved to.
    static let tableName = "CombinedMood"

    /// The valid answer values for every scored question.
    static let answerValues = Array(0...3)

    var gad7Answers: [Int?] = Array(repeating: nil, count: L10n.gad7Questions.count)
    var phq9Answers: [Int?] = Array(repeating: nil, count: L10n.phq9Questions.count)
    /// Answer to the PHQ-9 interference question (0–3), saved to the
    /// `interference_level` column.
    var interferenceLevel: Int?
    /// Per-question notes, one slot per question (empty string = no note).
    /// Saved together as the `combined_notes` JSON column.
    var gad7Notes: [String] = Array(repeating: "", count: L10n.gad7Questions.count)
    var phq9Notes: [String] = Array(repeating: "", count: L10n.phq9Questions.count)
    /// Note for the PHQ-9 interference question, stored alongside the others.
    var interferenceNote: String = ""

    var gad7Score: Int { gad7Answers.compactMap { $0 }.reduce(0, +) }
    var phq9Score: Int { phq9Answers.compactMap { $0 }.reduce(0, +) }

    var gad7Severity: GAD7Severity { GAD7Severity(score: gad7Score) }
    var phq9Severity: PHQ9Severity { PHQ9Severity(score: phq9Score) }

    /// True once every GAD-7 and PHQ-9 question has an answer.
    var isComplete: Bool {
        !gad7Answers.contains(nil) && !phq9Answers.contains(nil)
    }

    /// True while nothing has been filled in yet.
    var isEmpty: Bool {
        gad7Answers.allSatisfy { $0 == nil }
            && phq9Answers.allSatisfy { $0 == nil }
            && interferenceLevel == nil
    }
}

/// JSON payload of the `combined_notes` column: one note per question, plus
/// one for the interference question.
nonisolated struct QuestionnaireNotes: Codable {
    let gad7: [String]
    let phq9: [String]
    let interference: String?
}

/// A filled-in questionnaire loaded back from the database.
struct CompletedQuestionnaire: Identifiable {
    let databaseID: DatabaseID
    let sessionID: DatabaseID?
    let answeredDate: Date
    let questionnaire: CombinedMoodQuestionnaire

    var id: DatabaseID { databaseID }
}
