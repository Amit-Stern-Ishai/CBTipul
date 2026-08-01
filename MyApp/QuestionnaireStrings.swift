import Foundation

/// Central mapping of every user-facing questionnaire string.
///
/// All values are English placeholders. The production app will show Hebrew:
/// translate the values in this one file (or back them with a String Catalog
/// later) — the rest of the app only ever references these constants and
/// never hard-codes questionnaire wording.
enum QuestionnaireText {

    // MARK: - Shared

    static let combinedTitle = "שאלון משולב"
    static let addQuestionnaireAction = "מלא שאלון"
    static let notesSectionTitle = "Notes (placeholder)"
    static let notesFieldPlaceholder = "Optional notes (placeholder)"
    static let scoreLabel = "Score (placeholder)"
    static let answerKeyTitle = "Answer key (placeholder)"

    /// Descriptions of the shared 0–3 answer scale, indexed by answer value.
    static let answerDescriptions: [String] = [
        "0 – Not at all (placeholder)",
        "1 – Several days (placeholder)",
        "2 – More than half the days (placeholder)",
        "3 – Nearly every day (placeholder)",
    ]

    // MARK: - GAD-7

    static let gad7Title = "GAD-7 Questionnaire (placeholder)"
    static let gad7MainQuestion =
        "How much were you bothered by these in the past two weeks? (placeholder)"
    static let gad7Questions: [String] = (1...7).map { "GAD-7 – Question \($0) (placeholder)" }

    static func label(for severity: GAD7Severity) -> String {
        switch severity {
        case .minimal: return "No real anxiety (placeholder)"
        case .mild: return "Light anxiety (placeholder)"
        case .substantial: return "Substantial anxiety (placeholder)"
        case .extreme: return "Extreme anxiety (placeholder)"
        }
    }

    // MARK: - PHQ-9

    static let phq9Title = "PHQ-9 Questionnaire (placeholder)"
    static let phq9Questions: [String] = (1...9).map { "PHQ-9 – Question \($0) (placeholder)" }

    static let phq9ImpairmentQuestion =
        "If you noted any problems, how much did they interfere with doing your work, stuff at home, or getting along with other people? (placeholder)"

    /// The four worded options for the impairment question, indexed by value.
    static let phq9ImpairmentOptions: [String] = [
        "Not difficult at all (placeholder)",
        "Somewhat difficult (placeholder)",
        "Very difficult (placeholder)",
        "Extremely difficult (placeholder)",
    ]

    static func label(for severity: PHQ9Severity) -> String {
        switch severity {
        case .minimal: return "Minimal depression, no need to treat (placeholder)"
        case .mild: return "Light depression (placeholder)"
        case .moderate: return "Medium depression (placeholder)"
        case .moderatelySevere: return "Medium-major depression (placeholder)"
        case .severe: return "Major depression (placeholder)"
        }
    }

    /// The treatment suggestion shown next to each PHQ-9 classification.
    /// Real content will be provided later.
    static func suggestion(for severity: PHQ9Severity) -> String {
        switch severity {
        case .minimal: return "Suggestion for minimal depression (placeholder)"
        case .mild: return "Suggestion for light depression (placeholder)"
        case .moderate: return "Suggestion for medium depression (placeholder)"
        case .moderatelySevere: return "Suggestion for medium-major depression (placeholder)"
        case .severe: return "Suggestion for major depression (placeholder)"
        }
    }
}
