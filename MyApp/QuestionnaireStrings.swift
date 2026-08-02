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
    static let answerKeyTitle = "מפתח תשובות"

    /// Descriptions of the shared 0–3 answer scale, indexed by answer value.
    static let answerDescriptions: [String] = [
        "0 - כלל לא",
        "1 - כמה ימים",
        "2 - יותר ממחצית מהימים",
        "3 - כמעט כל יום",
    ]

    // MARK: - Questionnaire history

    static let viewQuestionnairesAction = "View Questionnaires (placeholder)"
    static let questionnairesTitle = "Questionnaires (placeholder)"
    static let modePickerTitle = "View (placeholder)"
    static let listModeTitle = "List (placeholder)"
    static let graphsModeTitle = "Graphs (placeholder)"
    static let noQuestionnairesMessage = "No questionnaires yet (placeholder)"
    static let loadErrorTitle = "Couldn't load questionnaires (placeholder)"
    static let retryAction = "Retry (placeholder)"
    static let metricPickerTitle = "Show (placeholder)"
    static let totalOptionLabel = "Total score (placeholder)"

    static func questionOptionLabel(_ number: Int) -> String {
        "Question \(number) (placeholder)"
    }

    /// Short names used in compact rows next to scores.
    static let gad7ShortName = "GAD-7 (placeholder)"
    static let phq9ShortName = "PHQ-9 (placeholder)"

    static let questionnaireSectionTitle = "Questionnaire (placeholder)"
    static let noQuestionnaireForSession = "No questionnaire for this session yet (placeholder)"

    // MARK: - GAD-7

    static let gad7Title = "GAD-7 שאלון לאבחון חרדה מוכללת"
    static let gad7MainQuestion =
        "במהלך השבועיים האחרונים עד כמה היית מוטרד/ת מהנושאים הבאים?"
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

    static let phq9InterferenceQuestion =
        "If you noted any problems, how much did they interfere with doing your work, stuff at home, or getting along with other people? (placeholder)"

    /// The four worded options for the interference question, indexed by value.
    static let phq9InterferenceOptions: [String] = [
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
