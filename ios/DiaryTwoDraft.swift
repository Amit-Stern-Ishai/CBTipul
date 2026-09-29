import Foundation

enum DiaryTwoEditorMode: Equatable {
    case create
    case edit(DiaryTwoEntry)

    var existing: DiaryTwoEntry? {
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

/// Single editable source of truth for create and edit.
struct DiaryTwoEntryDraft: Equatable, Codable {
    var event: String
    var automaticThoughts: [DiaryAutomaticThoughtDraft]
    var feelings: [DiaryFeelingDraft]
    var thinkingErrors: [ThinkingError]
    var alternativeThoughts: [DiaryAutomaticThoughtDraft]

    static let empty = DiaryTwoEntryDraft(
        event: "",
        automaticThoughts: [DiaryAutomaticThoughtDraft()],
        feelings: [],
        thinkingErrors: [],
        alternativeThoughts: [DiaryAutomaticThoughtDraft()]
    )

    static func from(_ entry: DiaryTwoEntry) -> DiaryTwoEntryDraft {
        let thoughts = entry.automaticThoughts.isEmpty
            ? [DiaryAutomaticThoughtDraft()]
            : entry.automaticThoughts.map { DiaryAutomaticThoughtDraft(text: $0) }
        return DiaryTwoEntryDraft(
            event: entry.event,
            automaticThoughts: thoughts,
            feelings: entry.feelings.map(DiaryFeelingDraft.init(persisted:)),
            thinkingErrors: entry.thinkingErrors,
            alternativeThoughts: entry.alternativeThoughts.map { DiaryAutomaticThoughtDraft(text: $0) }
        )
    }

    var persistedAutomaticThoughts: [String] {
        automaticThoughts
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var persistedAlternativeThoughts: [String] {
        alternativeThoughts.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
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
            thinkingErrors: thinkingErrors,
            alternativeThoughts: persistedAlternativeThoughts
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
        if Set(feelings.map(\.trimmedName)).count != feelings.count { return L10n.diaryFeelingAlreadySelected }
        if thinkingErrors.isEmpty { return L10n.diaryTwoValidationErrors }
        if persistedAlternativeThoughts.isEmpty { return L10n.diaryTwoValidationAlternatives }
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
        var thinkingErrors: [ThinkingError]
        var alternativeThoughts: [String]

        struct Feeling: Equatable {
            var name: String
            var intensity: Int?
        }
    }
}

