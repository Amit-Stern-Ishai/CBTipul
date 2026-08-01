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
}

/// Whether a patient is currently in active treatment.
enum PatientStatus: String, CaseIterable, Identifiable {
    case active = "Active"
    case inactive = "Inactive"

    var id: String { rawValue }
}

/// A patient tracked by the therapist.
@Observable
final class Patient: Identifiable {
    let id: UUID
    /// The row's primary key in the Supabase `Patients` table, once saved.
    var databaseID: DatabaseID?
    var firstName: String
    var lastName: String
    var status: PatientStatus
    var sessions: [Session]

    init(id: UUID = UUID(),
         databaseID: DatabaseID? = nil,
         firstName: String = "",
         lastName: String = "",
         status: PatientStatus = .active,
         sessions: [Session] = []) {
        self.id = id
        self.databaseID = databaseID
        self.firstName = firstName
        self.lastName = lastName
        self.status = status
        self.sessions = sessions
    }

    /// Full name for display, falling back when both parts are empty.
    var displayName: String {
        let full = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return full.isEmpty ? "Unnamed Patient" : full
    }

    /// The number of the most recent session (0 when there are none yet).
    var currentSessionNumber: Int { sessions.count }
}

extension Patient: Hashable {
    static func == (lhs: Patient, rhs: Patient) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A single therapy session for a patient.
@Observable
final class Session: Identifiable {
    let id: UUID
    /// The row's primary key in the Supabase `Sessions` table, once saved.
    var databaseID: DatabaseID?
    var date: Date
    var notes: String
    var questionnaire: CombinedMoodQuestionnaire

    init(id: UUID = UUID(),
         databaseID: DatabaseID? = nil,
         date: Date = .now,
         notes: String = "",
         questionnaire: CombinedMoodQuestionnaire = CombinedMoodQuestionnaire()) {
        self.id = id
        self.databaseID = databaseID
        self.date = date
        self.notes = notes
        self.questionnaire = questionnaire
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

    var gad7Answers: [Int?] = Array(repeating: nil, count: QuestionnaireText.gad7Questions.count)
    var phq9Answers: [Int?] = Array(repeating: nil, count: QuestionnaireText.phq9Questions.count)
    /// Answer to the PHQ-9 functional-impairment question (0–3).
    /// Currently kept locally only — not part of the saved row.
    var phq9Impairment: Int?
    var notes: String = ""

    var gad7Score: Int { gad7Answers.compactMap { $0 }.reduce(0, +) }
    var phq9Score: Int { phq9Answers.compactMap { $0 }.reduce(0, +) }

    var gad7Severity: GAD7Severity { GAD7Severity(score: gad7Score) }
    var phq9Severity: PHQ9Severity { PHQ9Severity(score: phq9Score) }

    /// True once every GAD-7 and PHQ-9 question has an answer.
    var isComplete: Bool {
        !gad7Answers.contains(nil) && !phq9Answers.contains(nil)
    }
}
