import Foundation

/// One named feeling and its intensity. Group/category is UI-only and is
/// never persisted.
nonisolated struct DiaryFeeling: Codable, Equatable, Hashable, Sendable {
    var name: String
    var intensity: Int
}

/// Editor row. A newly added feeling has no intensity until the therapist
/// moves the slider. A persisted feeling keeps its saved intensity.
struct DiaryFeelingDraft: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var intensity: Int?

    init(id: UUID = UUID(), name: String, intensity: Int? = nil) {
        self.id = id
        self.name = name
        self.intensity = intensity
    }

    /// Existing JSONB feeling — already answered, including 0%.
    init(persisted feeling: DiaryFeeling) {
        self.id = UUID()
        self.name = feeling.name
        self.intensity = feeling.intensity
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum DiaryOneEditorMode: Equatable {
    case create
    case edit(DiaryOneEntry)

    var existing: DiaryOneEntry? {
        switch self {
        case .create: nil
        case .edit(let entry): entry
        }
    }

    var identity: String {
        switch self {
        case .create: "create"
        case .edit(let entry): entry.id.uuidString
        }
    }
}

struct DiaryAutomaticThoughtDraft: Identifiable, Equatable, Codable {
    var id: UUID
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

/// Single editable source of truth for create and edit.
struct DiaryOneEntryDraft: Equatable, Codable {
    var event: String
    var automaticThoughts: [DiaryAutomaticThoughtDraft]
    var feelings: [DiaryFeelingDraft]
    var behaviour: String
    var physicalSymptoms: String

    static let empty = DiaryOneEntryDraft(
        event: "",
        automaticThoughts: [DiaryAutomaticThoughtDraft()],
        feelings: [],
        behaviour: "",
        physicalSymptoms: ""
    )

    static func from(_ entry: DiaryOneEntry) -> DiaryOneEntryDraft {
        let thoughts = entry.automaticThoughts.isEmpty
            ? [DiaryAutomaticThoughtDraft()]
            : entry.automaticThoughts.map { DiaryAutomaticThoughtDraft(text: $0) }
        return DiaryOneEntryDraft(
            event: entry.event,
            automaticThoughts: thoughts,
            feelings: entry.feelings.map(DiaryFeelingDraft.init(persisted:)),
            behaviour: entry.behaviour,
            physicalSymptoms: entry.physicalSymptoms ?? ""
        )
    }

    var persistedAutomaticThoughts: [String] {
        automaticThoughts
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var comparableSnapshot: Snapshot {
        Snapshot(
            event: event.trimmingCharacters(in: .whitespacesAndNewlines),
            automaticThoughts: persistedAutomaticThoughts,
            feelings: feelings.map {
                Snapshot.Feeling(
                    name: $0.trimmedName,
                    intensity: $0.intensity
                )
            },
            behaviour: behaviour.trimmingCharacters(in: .whitespacesAndNewlines),
            physicalSymptoms: physicalSymptoms.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    mutating func addAutomaticThought() {
        automaticThoughts.append(DiaryAutomaticThoughtDraft())
    }

    mutating func removeAutomaticThought(id: UUID) {
        guard automaticThoughts.count > 1 else { return }
        automaticThoughts.removeAll { $0.id == id }
        if automaticThoughts.isEmpty {
            automaticThoughts = [DiaryAutomaticThoughtDraft()]
        }
    }

    func validationMessage() -> String? {
        if event.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return L10n.diaryOneValidationEvent
        }
        if persistedAutomaticThoughts.isEmpty {
            return L10n.diaryOneValidationThought
        }
        if feelings.isEmpty {
            return L10n.diaryOneValidationFeelingsRequired
        }
        for feeling in feelings {
            if feeling.trimmedName.isEmpty {
                return L10n.diaryOneValidationFeelingName
            }
            guard let intensity = feeling.intensity else {
                return L10n.diaryOneValidationFeelingIntensity(feeling.trimmedName)
            }
            guard (0...100).contains(intensity) else {
                return L10n.diaryOneValidationFeelingIntensity(feeling.trimmedName)
            }
        }
        if behaviour.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return L10n.diaryOneValidationBehaviour
        }
        return nil
    }

    func persistedFeelings() -> [DiaryFeeling]? {
        guard validationMessage() == nil else { return nil }
        return feelings.map {
            DiaryFeeling(name: $0.trimmedName, intensity: $0.intensity ?? 0)
        }
    }

    struct Snapshot: Equatable {
        var event: String
        var automaticThoughts: [String]
        var feelings: [Feeling]
        var behaviour: String
        var physicalSymptoms: String

        struct Feeling: Equatable {
            var name: String
            var intensity: Int?
        }
    }
}

nonisolated struct DiaryFeelingGroup: Equatable, Sendable, Identifiable {
    let title: String
    let feelings: [String]
    var id: String { title }
}

/// Shared predefined vocabulary for therapist and (later) Patient Mode.
enum DiaryFeelingVocabulary {
    static let groups: [DiaryFeelingGroup] = [
        DiaryFeelingGroup(
            title: "עצב",
            feelings: ["עצוב", "מדוכא", "אומלל", "נוגה", "מדוכדך"]
        ),
        DiaryFeelingGroup(
            title: "חרדה",
            feelings: ["חרד", "מודאג", "מבוהל", "מפוחד", "מבועת", "מתוח", "לחוץ"]
        ),
        DiaryFeelingGroup(
            title: "אשמה ובושה",
            feelings: ["אשמה", "חרטה", "בושה", "ייסורי מצפון"]
        ),
        DiaryFeelingGroup(
            title: "חוסר ערך",
            feelings: ["נחות", "דפוק", "חסר ערך", "לקוי", "פגום", "לא יוצלח"]
        ),
        DiaryFeelingGroup(
            title: "בדידות ודחייה",
            feelings: ["בודד", "לבד", "דחוי", "נטוש", "לא אהוב"]
        ),
        DiaryFeelingGroup(
            title: "מבוכה",
            feelings: ["מבוכה", "אווילי", "מושפל", "לא בנוח", "מובך"]
        ),
        DiaryFeelingGroup(
            title: "חוסר תקווה",
            feelings: ["חסר תקווה", "מיואש", "פסימי", "ייאוש"]
        ),
        DiaryFeelingGroup(
            title: "תסכול",
            feelings: ["מתוסכל", "תקוע", "מובס", "מנוצח"]
        ),
        DiaryFeelingGroup(
            title: "כעס",
            feelings: ["כועס", "ממורמר", "רגוז", "מעוצבן", "זועם", "רותח", "פגוע"]
        ),
    ]

    static let allNames: [String] = groups.flatMap(\.feelings)

    static func contains(_ name: String) -> Bool {
        allNames.contains(name)
    }

    static func matching(_ query: String) -> [String] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        return allNames.filter { $0.localizedStandardContains(needle) }
    }
}
