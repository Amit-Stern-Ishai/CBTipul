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
    var questionnaire: Questionnaire

    init(id: UUID = UUID(),
         databaseID: DatabaseID? = nil,
         date: Date = .now,
         notes: String = "",
         questionnaire: Questionnaire = Questionnaire()) {
        self.id = id
        self.databaseID = databaseID
        self.date = date
        self.notes = notes
        self.questionnaire = questionnaire
    }
}

/// The two questionnaires that can be attached to a session.
enum QuestionnaireKind: String, CaseIterable, Identifiable {
    case gad7 = "GAD-7"
    case depression = "Depression"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gad7: return "GAD-7 Questionnaire"
        case .depression: return "Depression Questionnaire"
        }
    }

    var questions: [String] {
        switch self {
        case .gad7: return QuestionnaireContent.gad7
        case .depression: return QuestionnaireContent.depression
        }
    }

    /// The Supabase table this questionnaire's answers are saved to.
    var tableName: String {
        switch self {
        case .gad7: return "GAD7"
        case .depression: return "Depression"
        }
    }
}

/// The answers for both questionnaires of a session.
///
/// Answers are stored as optional integers so an unanswered question can be
/// distinguished from an answer of `0`. Each answer is in the range 0...3.
struct Questionnaire {
    var gad7: [Int?]
    var depression: [Int?]

    init(gad7: [Int?]? = nil, depression: [Int?]? = nil) {
        self.gad7 = gad7 ?? Array(repeating: nil, count: QuestionnaireContent.gad7.count)
        self.depression = depression ?? Array(repeating: nil, count: QuestionnaireContent.depression.count)
    }

    subscript(kind: QuestionnaireKind) -> [Int?] {
        get {
            switch kind {
            case .gad7: return gad7
            case .depression: return depression
            }
        }
        set {
            switch kind {
            case .gad7: gad7 = newValue
            case .depression: depression = newValue
            }
        }
    }

    /// True once every question of the given questionnaire has an answer.
    func isComplete(_ kind: QuestionnaireKind) -> Bool {
        !self[kind].contains(nil)
    }

    /// True once every question in both questionnaires has an answer.
    var isComplete: Bool {
        !gad7.contains(nil) && !depression.contains(nil)
    }
}

/// Placeholder questionnaire content. The real question text will be filled in later.
enum QuestionnaireContent {
    static let gad7: [String] = (1...7).map { "GAD-7 – Question \($0) (placeholder)" }
    static let depression: [String] = (1...9).map { "Depression – Question \($0) (placeholder)" }

    /// The valid answer values for every question.
    static let answerValues = Array(0...3)
}
