import Foundation

enum DiaryThreeEditorMode: Equatable {
    case create
    case edit(DiaryThreeEntry)
    var existing: DiaryThreeEntry? { if case .edit(let entry) = self { entry } else { nil } }
}

struct DiaryThreeAutomaticThoughtDraft: Identifiable, Equatable, Codable {
    var id = UUID()
    var text = ""
    var beliefBefore: Int?
    var beliefAfter: Int?
}
struct DiaryThreeFeelingDraft: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var intensityBefore: Int?
    var intensityAfter: Int?
}
struct DiaryThreeAlternativeThoughtDraft: Identifiable, Equatable, Codable {
    var id = UUID()
    var text = ""
    var belief: Int?
}

struct DiaryThreeEntryDraft: Equatable, Codable {
    var situation = ""
    var automaticThoughts = [DiaryThreeAutomaticThoughtDraft()]
    var feelings: [DiaryThreeFeelingDraft] = []
    var thinkingErrors: [ThinkingError] = []
    var alternativeThoughts = [DiaryThreeAlternativeThoughtDraft()]
    static var empty: Self { Self() }
    typealias Snapshot = DiaryThreeEntryDraft
    var comparableSnapshot: Snapshot { self }

    static func from(_ entry: DiaryThreeEntry) -> Self {
        Self(situation: entry.situation,
            automaticThoughts: entry.automaticThoughts.map { .init(text: $0.text, beliefBefore: $0.beliefBefore, beliefAfter: $0.beliefAfter) },
            feelings: entry.feelings.map { .init(name: $0.name, intensityBefore: $0.intensityBefore, intensityAfter: $0.intensityAfter) },
            thinkingErrors: entry.thinkingErrors,
            alternativeThoughts: entry.alternativeThoughts.map { .init(text: $0.text, belief: $0.belief) })
    }
    private func valid(_ rating: Int?) -> Bool { rating.map { (0...100).contains($0) } ?? false }
    func validationMessage() -> String? {
        if situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return L10n.diaryThreeValidationSituation }
        if automaticThoughts.isEmpty || automaticThoughts.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return L10n.diaryOneValidationThought }
        if automaticThoughts.contains(where: { !valid($0.beliefBefore) || !valid($0.beliefAfter) }) { return L10n.diaryThreeValidationRatings }
        if feelings.isEmpty { return L10n.diaryOneValidationFeelingsRequired }
        if feelings.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !valid($0.intensityBefore) || !valid($0.intensityAfter) }) { return L10n.diaryThreeValidationRatings }
        if Set(feelings.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }).count != feelings.count { return L10n.diaryFeelingAlreadySelected }
        if thinkingErrors.isEmpty { return L10n.diaryTwoValidationErrors }
        if Set(thinkingErrors).count != thinkingErrors.count { return L10n.diaryTwoDuplicateThinkingError }
        if alternativeThoughts.isEmpty || alternativeThoughts.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return L10n.diaryTwoValidationAlternatives }
        if alternativeThoughts.contains(where: { !valid($0.belief) }) { return L10n.diaryThreeValidationRatings }
        return nil
    }
    var persistedAutomaticThoughts: [DiaryThreeAutomaticThought] {
        precondition(validationMessage() == nil)
        return automaticThoughts.map { .init(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), beliefBefore: $0.beliefBefore!, beliefAfter: $0.beliefAfter!) }
    }
    var persistedAlternativeThoughts: [DiaryThreeAlternativeThought] {
        precondition(validationMessage() == nil)
        return alternativeThoughts.map { .init(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), belief: $0.belief!) }
    }
    func persistedFeelings() -> [DiaryThreeFeeling]? {
        guard validationMessage() == nil else { return nil }
        return feelings.map { .init(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), intensityBefore: $0.intensityBefore!, intensityAfter: $0.intensityAfter!) }
    }
}
