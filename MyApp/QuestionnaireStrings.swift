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
    static let notesSectionTitle = "הערות"
    static let notesFieldPlaceholder = "הערות"
    static let questionNoteTitle = "Question Note (placeholder)"
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

    static let viewQuestionnairesAction = "שאלונים"
    static let questionnairesTitle = "שאלוני מצב רוח"
    static let modePickerTitle = "View (placeholder)"
    static let listModeTitle = "רשימה"
    static let graphsModeTitle = "גרפים"
    static let noQuestionnairesMessage = "אין שאלונים עדיין"
    static let loadErrorTitle = "לא הצלחתי לטעון שאלונים"
    static let retryAction = "נסה שנית"
    static let metricPickerTitle = "Show (placeholder)"
    static let totalOptionLabel = "ציון כולל"

    static func questionOptionLabel(_ number: Int) -> String {
        "Question \(number) (placeholder)"
    }

    /// Short names used in compact rows next to scores.
    static let gad7ShortName = "GAD-7"
    static let phq9ShortName = "PHQ-9"

    static let questionnaireSectionTitle = "Questionnaire (placeholder)"

    /// Indications of the previous questionnaire's answers.
    static func previousAnswerLegend(dateText: String) -> String {
        "Outlined value = answer from the previous questionnaire, \(dateText) (placeholder)"
    }

    static func previousScoreLabel(dateText: String) -> String {
        "Previous, \(dateText) (placeholder)"
    }
    static let noQuestionnaireForSession = "No questionnaire for this session yet (placeholder)"

    // MARK: - GAD-7

    static let gad7Title = "GAD-7 שאלון לאבחון חרדה מוכללת"
    static let gad7MainQuestion =
        "במהלך השבועיים האחרונים עד כמה היית מוטרד/ת מהנושאים הבאים?"
//    static let gad7Questions: [String] = (1...7).map { "GAD-7 – Question \($0) (placeholder)" }

    static let gad7Questions: [String] = [
        "הרגשתי עצבות, חרדה או מתח רב",
        "לא הייתי מסוגל/ת להפסיק לדאוג או לשלוט בחרדה",
        "הייתי מודאג/ת יותר מדי בקשר לדברים שונים",
        "התקשיתי להירגע",
        "הייתי כל כך חסר/ת מנוחה שהיה לי קשה לשבת בלי לנוע",
        "התעצבנתי או התרגשתי בקלות",
        "פחדתי שמשהו נורא עומד לקרות"
    ]
    
    static func label(for severity: GAD7Severity) -> String {
        switch severity {
        case .minimal: return "No real anxiety (placeholder)"
        case .mild: return "Light anxiety (placeholder)"
        case .substantial: return "Substantial anxiety (placeholder)"
        case .extreme: return "Extreme anxiety (placeholder)"
        }
    }

    // MARK: - PHQ-9

    static let phq9Title = "PHQ-9 שאלון בריאות המטופל"
    static let phq9Questions: [String] = [
        "עניין או הנאה מועטים מעשיית דברים",
        "תחושת דכדוך, דיכאון או חוסר תקווה",
        "קשיים בהירדמות או בשינה רצופה, או עודף שינה",
        "תחושה של עייפות או אנרגיה מועטה",
        "תיאבון מועט או אכילת יתר",
        "הרגשה רגעה לגבי עצמך - מרגיש/ה שאת/ה כישלון או שאכזבת את עצמך או את משפחתך",
        "קושי להתרכז בדברים כמו קריאה בעיתון או צפייה בטלוויזיה",
        "דיבור או תנועה באיטיות רבה מהרגיל או להיפך, חוסר שקט כה רב עד כי צריך להסתובב יותר מהרגיל",
        "מחשבות שהיה עדיף לו היית מת/ה או מחשבות על פגיעה בעצמך בדרך כלשהי"
    ]

    static let phq9InterferenceQuestion =
        "אם סימנת בעיות **כלשהן** - עד כמה **הקשו** עליך לבצע את עבודתך, לטפל בדברים בבית או להסתדר עם אנשים אחרים?"

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
