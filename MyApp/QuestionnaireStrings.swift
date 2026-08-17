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
    static let questionNoteTitle = "Question Note"
    static let scoreLabel = "ציון כולל"
    static let answerKeyTitle = "מפתח תשובות"

    /// Descriptions of the shared 0–3 answer scale, indexed by answer value.
    static let answerDescriptions: [String] = [
        "0 - כלל לא",
        "1 - כמה ימים",
        "2 - יותר ממחצית מהימים",
        "3 - כמעט כל יום",
    ]

    // MARK: - Voice note

    static let voiceNoteSectionTitle = "Voice Note"
    static let recordVoiceNoteAction = "Record Voice Note"
    static let recordingLabel = "Recording…"
    static let voiceNoteLabel = "Voice note"
    static let micPermissionDenied = "Microphone access is required to record. Enable it in Settings."
    static let transcribeAction = "Transcribe"
    static let transcribingLabel = "Transcribing…"
    /// Header line inserted above transcribed text in the notes field.
    static func transcriptionHeader(timeText: String) -> String {
        "מהקלטה ב- \(timeText)"
    }

    // MARK: - Session images

    static let imagesSectionTitle = "Images (placeholder)"
    static let uploadDocumentAction = "Upload Document (placeholder)"
    static let addImageFromLibraryAction = "Add from Library (placeholder)"
    static let takePhotoAction = "Take Photo (placeholder)"
    static let deleteImageAction = "Delete Image"

    /// Header line inserted above text extracted from an image.
    static func imageTranscriptionHeader(dateText: String) -> String {
        "מתמונה בתאריך \(dateText)"
    }

    // MARK: - AI assistant

    static let aiTitle = "AI Assistant"
    static let aiAction = "AI Assistant"
    static let aiModePickerTitle = "Mode"
    static let aiModeInsights = "Insights"
    static let aiModeQuestionnaires = "Questionnaires"
    static let aiModeGeneral = "General"
    static let aiPromptPlaceholder = "Your question"
    static let aiGenerateInsightsAction = "Generate Insights"
    static let aiAskAction = "Ask"
    static let aiThinkingLabel = "Thinking…"
    static let aiResponseTitle = "Response"

    // MARK: - Settings

    static let settingsTitle = "Settings"
    static let settingsAISectionTitle = "AI Assistant"
    static let settingsResponseStyleTitle = "Response Style"
    static let settingsResponseStyleTyping = "Typing"
    static let settingsResponseStyleRegular = "Regular"
    static let settingsDoneAction = "Done"

    // MARK: - Session editor

    static let discardChangesTitle = "You have unsaved changes. They will be deleted unless you save."
    static let discardChangesAction = "Discard Changes"
    static let saveChangesAction = "Save"
    static let keepEditingAction = "Keep Editing"
    static let recordingFinishedTitle = "Transcribe the recording into the notes?"
    static let discardRecordingAction = "Discard Recording"
    static let playRecordingAction = "Play"
    static let stopPlaybackAction = "Stop Playback"

    // MARK: - Questionnaire history

    static let viewQuestionnairesAction = "שאלונים"
    static let questionnairesTitle = "שאלוני מצב רוח"
    static let modePickerTitle = "View (placeholder)"
    static let listModeTitle = "רשימה"
    static let graphsModeTitle = "גרפים"
    static let noQuestionnairesMessage = "אין שאלונים עדיין"
    static let loadErrorTitle = "לא הצלחתי לטעון שאלונים"
    static let retryAction = "נסה שנית"
    static let metricPickerTitle = "Show"
    static let totalOptionLabel = "ציון כולל"

    /// Short per-question names shown in the graph metric picker,
    /// indexed like the question arrays.
    static let gad7QuestionShortNames: [String] = [
        "עצבנות ומתח",
        "שליטה בדאגה",
        "דאגה מוגזמת",
        "קושי להירגע",
        "חוסר מנוחה",
        "רגזנות",
        "פחד מאסון",
    ]

    static let phq9QuestionShortNames: [String] = [
        "אובדן עניין",
        "מצב רוח ירוד",
        "שינה",
        "עייפות",
        "תיאבון",
        "ערך עצמי",
        "ריכוז",
        "איטיות / אי-שקט",
        "מחשבות על פגיעה עצמית",
    ]

    /// Short names used in compact rows next to scores.
    static let gad7ShortName = "GAD-7"
    static let phq9ShortName = "PHQ-9"

    static let questionnaireSectionTitle = "Questionnaire"

    /// Indications of the previous questionnaire's answers.
//    static func previousAnswerLegend(dateText: String) -> String {
//        "Outlined value = answer from the previous questionnaire, \(dateText) (placeholder)"
//    }

    static func previousAnswerLegend(dateText: String) -> String {
        let hebrewDate = hebrewDate(from: dateText) ?? dateText
        return "הערך המוקף = תשובה מהשאלון הקודם מתאריך \(hebrewDate)"
    }
    
    static func hebrewDate(from dateString: String) -> String? {
        let inputFormatter = DateFormatter()
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.dateFormat = "d MMM yyyy"

        guard let date = inputFormatter.date(from: dateString) else {
            return nil
        }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "he_IL")
        outputFormatter.dateFormat = "d 'ב'MMMM yyyy"

        return outputFormatter.string(from: date)
    }
    
    static func previousScoreLabel(dateText: String) -> String {
        "Previous, \(dateText)"
    }
    static let noQuestionnaireForSession = "אין שאלונים לפגישה זו"

    // MARK: - GAD-7

    static let gad7Title = "GAD-7 שאלון לאבחון חרדה מוכללת"
    static let gad7MainQuestion =
        "במהלך השבועיים האחרונים עד כמה היית מוטרד/ת מהנושאים הבאים?"

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
        case .minimal: return "ללא חרדה משמעותית"
        case .mild: return "חרדה קלה"
        case .substantial: return "חרדה משמעותית"
        case .extreme: return "חרדה קשה"
        }
    }

    // MARK: - PHQ-9

    static let phq9Title = "PHQ-9 שאלון בריאות המטופל"
    
    static let phq9MainQuestion =
        "במהלך השבועיים האחרונים באיזו תדירות היית מוטרד/ת מכל אחת מן הבעיות הבאות?"

    static let phq9Questions: [String] = [
        "עניין או הנאה מועטים מעשיית דברים",
        "תחושת דכדוך, דיכאון או חוסר תקווה",
        "קשיים בהירדמות או בשינה רצופה, או עודף שינה",
        "תחושה של עייפות או אנרגיה מועטה",
        "תיאבון מועט או אכילת יתר",
        "הרגשה רעה לגבי עצמך - מרגיש/ה שאת/ה כישלון או שאכזבת את עצמך או את משפחתך",
        "קושי להתרכז בדברים כמו קריאה בעיתון או צפייה בטלוויזיה",
        "דיבור או תנועה באיטיות רבה מהרגיל או להיפך, חוסר שקט כה רב עד כי צריך להסתובב יותר מהרגיל",
        "מחשבות שהיה עדיף לו היית מת/ה או מחשבות על פגיעה בעצמך בדרך כלשהי"
    ]

    static let phq9InterferenceQuestion =
        "אם סימנת בעיות **כלשהן** - עד כמה **הקשו** עליך לבצע את עבודתך, לטפל בדברים בבית או להסתדר עם אנשים אחרים?"

    /// The four worded options for the interference question, indexed by value.
    static let phq9InterferenceOptions: [String] = [
        "לא הקשו בכלל",
        "הקשו במידת מה",
        "הקשו מאוד",
        "הקשו באופן קיצוני",
    ]

    static func label(for severity: PHQ9Severity) -> String {
        switch severity {
        case .minimal: return "דיכאוןם מינימאלי"
        case .mild: return "דיכאון קל"
        case .moderate: return "דיכאון בינוני"
        case .moderatelySevere: return "דיכאון בינוני כבד"
        case .severe: return "דיכאון כבד"
        }
    }

    /// The treatment suggestion shown next to each PHQ-9 classification.
    /// Real content will be provided later.
    static func suggestion(for severity: PHQ9Severity) -> String {
        switch severity {
        case .minimal: return "אין צורך בטיפול לדיכאון"
        case .mild: return "כדאי לשקול טיפול ע״פ דיווח הסימפטומים של המטופל וע״פ התפקוד הכללי"
        case .moderate: return "כדאי לשקול טיפול ע״פ דיווח הסימפטומים של המטופל וע״פ התפקוד הכללי"
        case .moderatelySevere: return "מומלץ טיפול בדיכאון בתרופות, פסיכוטרפיה או שילוב שלהם"
        case .severe: return "מומלץ טיפול בדיכאון בתרופות, פסיכוטרפיה או שילוב שלהם"
        }
    }
}
