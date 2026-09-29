import Foundation

nonisolated enum ThinkingError: String, Codable, CaseIterable, Identifiable, Sendable {
    case allOrNothing = "all_or_nothing"
    case overgeneralization = "overgeneralization"
    case negativeFilter = "negative_filter"
    case discountingPositives = "discounting_positives"
    case jumpingToConclusions = "jumping_to_conclusions"
    case mindReading = "mind_reading"
    case fortuneTelling = "fortune_telling"
    case magnificationMinimization = "magnification_minimization"
    case emotionalReasoning = "emotional_reasoning"
    case shouldStatements = "should_statements"
    case labeling = "labeling"
    case blame = "blame"
    var id: String { rawValue }
    var title: String { L10n.thinkingErrorTitles[Self.allCases.firstIndex(of: self)!] }
    var explanation: String { L10n.thinkingErrorExplanations[Self.allCases.firstIndex(of: self)!] }
}
