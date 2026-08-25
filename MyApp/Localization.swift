import Foundation

/// Central mapping of every user-facing string in the app.
///
/// The values are the app's existing wording, unchanged. Translate the
/// values in this one file — the rest of the app only ever references these
/// constants and never hard-codes user-facing wording.
enum L10n {

    // MARK: - Common

    static let save = "Save"
    static let cancel = "Cancel"
    static let done = "Done"
    static let add = "Add"
    static let back = "Back"
    static let retry = "Retry"

    // MARK: - Auth

    static let appTitle = "Therapy Notes"
    static let authWelcomeSignIn = "Welcome back — sign in to continue"
    static let authWelcomeSignUp = "Create an account to get started"
    static let authModePickerTitle = "Mode"
    static let emailPlaceholder = "Email"
    static let passwordPlaceholder = "Password"
    static let forgotPasswordAction = "Forgot password?"
    static let accountCreatedMessage = "Account created. Check your email to confirm your address, then sign in."
    static let enterEmailFirstMessage = "Enter your email address first, then tap Forgot password."
    static let passwordResetSentMessage = "Password reset email sent. Check your inbox for a link to set a new password."
    static let signOutAction = "Sign Out"

    // MARK: - Patients

    static let patientsTitle = "Patients"
    static let loadingPatientsLabel = "Loading patients…"
    static let couldntLoadPatientsTitle = "Couldn't Load Patients"
    static let noPatientsTitle = "No Patients"
    static let addFirstPatientMessage = "Add your first patient to get started."
    static let addPatientAction = "Add Patient"
    static let noSessionsYetLabel = "No sessions yet"
    static let newPatientTitle = "New Patient"
    static let patientSectionTitle = "Patient"
    static let firstNamePlaceholder = "First name"
    static let lastNamePlaceholder = "Last name"
    static let statusLabel = "Status"
    static let unnamedPatient = "Unnamed Patient"
    static let notesSection = "Notes"
    static let optionalNotesPlaceholder = "Optional notes"
    static let myFormulationTitle = "My Formulation"
    static let prepareNextSessionAction = "Prepare Next Session"
    static let lastPreparationAction = "Last Preparation"
    static let outdatedBadge = "Outdated"

    // MARK: - Sessions

    static let sessionsTitle = "Sessions"
    static let addSessionAction = "Add Session"
    static let newSessionTitle = "New Session"
    static func session(_ number: Int) -> String {
        "Session \(number)"
    }
    /// Editor title for an existing session; the number is omitted when unknown.
    static func sessionEditorTitle(_ number: Int?) -> String {
        "Session\(number.map { " \($0)" } ?? "")"
    }
    static let editDateAccessibilityLabel = "Edit date"
    static let fromLastSessionHeader = "From Last Session"
    static func moreFollowUps(_ count: Int) -> String {
        "More (\(count))"
    }
    static let openQuestionsTitle = "Open Questions"
    static let markDiscussedAccessibilityLabel = "Mark discussed"
    static let analyzingLabel = "Analyzing…"
    static let aiSummaryAction = "AI Summary"
    static let showStructuredSummaryAction = "Show Structured Summary"
    static let structuredSummarySection = "Structured Summary"
    static let deleteSessionAction = "Delete Session"
    static let deleteSessionConfirmTitle = "Delete this session?"
    static let deleteSessionConfirmMessage = "The session and its data will be permanently deleted. This cannot be undone."
    static let deletePatientAction = "Delete Patient"
    static let deletePatientConfirmTitle = "Delete this patient?"
    static let deletePatientConfirmMessage = "The patient and all their sessions and data will be permanently deleted. This cannot be undone."

    // MARK: - Terms and conditions

    static let termsTitle = "Terms and Conditions"
    static let termsAgreeAction = "Agree and Continue"
    /// Placeholder — the real wording will be filled in later.
    static let termsBody = """
תנאי שימוש והסכם משתמש

עודכן לאחרונה: 25/8/2026

ברוכים הבאים ל־CBTipul ("האפליקציה"). השימוש באפליקציה מותנה בהסכמתך לתנאים המפורטים להלן.

בכניסה לאפליקציה, בהרשמה או בשימוש בה, אתה מאשר כי קראת את תנאי השימוש, הבנת אותם ואתה מסכים להם.

1. מטרת האפליקציה

האפליקציה מיועדת לשמש כלי עזר מקצועי למטפלים בניהול מידע הקשור למטופלים, תיעוד פגישות, שאלונים, מעקב לאורך זמן ושימוש בכלי בינה מלאכותית לצורך תמיכה בתהליך העבודה המקצועי.

האפליקציה אינה מהווה תחליף להכשרה מקצועית, לשיקול דעת קליני או לאחריותו המקצועית של המטפל.

2. שימוש בבינה מלאכותית

האפליקציה עשויה להשתמש בשירותי בינה מלאכותית לצורך, בין היתר:

סיכום מובנה של הערות טיפוליות;
זיהוי דפוסים אפשריים במידע לאורך זמן;
זיהוי מחשבות אוטומטיות שליליות (NATs);
הצגת מחזורי CBT אפשריים;
הכנה לקראת פגישה;
הצפת שאלות ונקודות להתייחסות;
מתן תובנות לצורכי הדרכה ורפלקציה מקצועית;
שיחה עם עוזר AI.

תוצרי ה-AI הם הצעות, השערות וכלי עזר בלבד. הם אינם קביעה רפואית, אבחנה, הערכה פסיכולוגית או הנחיה טיפולית מחייבת.

על המטפל לבחון באופן עצמאי כל מידע שמופק על ידי האפליקציה ולהפעיל שיקול דעת מקצועי לפני הסתמכות עליו.

3. אחריות מקצועית

האחריות הבלעדית לקבלת החלטות בנוגע למטופל, לאבחון, לטיפול, להערכת סיכון ולכל פעולה מקצועית אחרת חלה על המשתמש, בהתאם להכשרתו ולחובותיו המקצועיות והחוקיות.

אין להסתמך על האפליקציה או על תוצרי AI כמקור יחיד לקבלת החלטה הנוגעת למטופל.

בפרט, אין להשתמש בתוצר AI כתחליף להערכה מקצועית של מצבי חירום או סיכון.

4. מידע על מטופלים

המשתמש אחראי לוודא כי הוא רשאי להזין ולעבד את המידע שהוא מזין לאפליקציה, וכי השימוש במידע נעשה בהתאם לכל דין, חובה מקצועית או חובת סודיות החלה עליו.

המשתמש אחראי גם לקבלת הסכמות נדרשות מהמטופלים, ככל שהדבר נדרש על פי הדין או לפי כללי המקצוע החלים עליו.

5. דיוק המידע

אנו עושים מאמצים לספק מערכת אמינה, אולם איננו מתחייבים כי:

המידע שיופק על ידי ה-AI יהיה תמיד מדויק;
הסיכומים יהיו מלאים;
כל דפוס או מידע משמעותי יזוהה;
לא יופיעו טעויות או פרשנויות שגויות.

לפיכך יש לבדוק את המידע לפני השימוש בו במסגרת טיפולית.

6. שאלונים

האפליקציה עשויה לאפשר שימוש בשאלוני הערכה כגון GAD-7 ו-PHQ-9.

השאלונים מיועדים לתמיכה במעקב ובהערכה ואינם מהווים, כשלעצמם, אבחנה רפואית או פסיכיאטרית.

7. אבטחת מידע

אנו נוקטים אמצעים סבירים ומקובלים להגנה על המידע הנשמר ומעובד באמצעות האפליקציה.

עם זאת, אין מערכת מחשוב או תקשורת שיכולה להיות מובטחת כחסינה לחלוטין מפני גישה בלתי מורשית, אובדן מידע או אירוע אבטחה.

המשתמש אחראי לשמור על פרטי ההתחברות שלו ולא לאפשר לאחרים גישה לחשבונו.

8. זמינות השירות

אנו רשאים לעדכן, לשנות, להשעות או להפסיק חלקים מהאפליקציה או מהשירותים המשולבים בה.

ייתכנו תקלות, זמני השבתה, מגבלות טכניות או אי-זמינות זמנית של שירותי צד שלישי, לרבות שירותי AI.

9. קניין רוחני

כל הזכויות באפליקציה, בעיצוב שלה, בקוד, בממשק, בסימנים המסחריים ובתוכן השייך למפעיל האפליקציה, ככל שאינם שייכים לצד שלישי, שמורות למפעיל.

אין להעתיק, להפיץ, לשנות, לפרק, לבצע הנדסה לאחור או לעשות שימוש מסחרי בלתי מורשה באפליקציה.

10. הפסקת שימוש

המשתמש רשאי להפסיק את השימוש באפליקציה בכל עת.

אנו רשאים להגביל או להפסיק גישה לחשבון במקרה של שימוש המפר תנאים אלה או הוראות דין.

11. שינויים בתנאים

אנו רשאים לעדכן תנאים אלה מעת לעת. במקרה של שינוי מהותי, עשויה להינתן הודעה באמצעות האפליקציה או באמצעי מתאים אחר.

המשך השימוש באפליקציה לאחר כניסת השינויים לתוקף יהווה הסכמה לתנאים המעודכנים, בכפוף לדין.

12. דין וסמכות שיפוט

תנאים אלה כפופים לדיני מדינת ישראל.

סמכות השיפוט בכל מחלוקת הנוגעת לתנאים אלה או לשימוש באפליקציה תהיה בהתאם להוראות הדין החל.

13. יצירת קשר

לשאלות, בקשות או פניות בנוגע לתנאי השימוש ניתן ליצור קשר:

עמית אברון שטרן ישי
דוא"ל: amitishai@gmail.com
"""

    // MARK: - Privacy policy

    static let privacyPolicyTitle = "Privacy Policy"
    /// Placeholder — the real wording will be filled in later.
    static let privacyPolicyBody = """
מדיניות פרטיות עבור CBTipul

עודכן לאחרונה: 25/8/2026

מדיניות זו מסבירה איזה מידע נאסף במסגרת השימוש ב־CBTipul ("האפליקציה"), כיצד נעשה בו שימוש, היכן הוא נשמר, עם מי הוא עשוי להיות משותף וכיצד אנו פועלים להגנתו.

השימוש באפליקציה מהווה הסכמה למדיניות זו, בכפוף להוראות הדין.

1. מי מפעיל את האפליקציה

האפליקציה מופעלת על ידי:

עמית אברון שטרן ישי
דוא"ל: amitishai@gmail.com

לצורך מדיניות זו, "אנחנו" או "המפעיל" מתייחס לישות המפעילה את האפליקציה.

2. איזה מידע אנו מעבדים

בהתאם לאופן השימוש באפליקציה, עשוי להיאסף ולעובד מידע כגון:

מידע על המשתמש

שם;

מידע על מטופלים

מזהה פנימי;
מידע שהמטפל מזין לגבי המטופל;
הערות וסיכומי פגישות;
מידע הקשור לפגישות טיפוליות;
תשובות לשאלונים כגון GAD-7 ו־PHQ-9;
מטרות טיפול;
מידע קליני ותובנות שהמטפל בוחר לתעד.

המידע שהמטפל מזין לגבי מטופל עשוי לכלול מידע אישי ורגיש מאוד.

3. שמירת שם המטופל

כחלק מהארכיטקטורה של האפליקציה, אנו עשויים לשמור את שם המטופל באופן מקומי במכשיר, בנפרד מהמידע הקליני הנשמר בשירותי הענן.

מטרת הפרדה זו היא לצמצם את כמות המידע המזהה הנשמרת בשרת.

שם המטופל עשוי להישמר באחסון מאובטח של מערכת ההפעלה של המכשיר.

4. שימוש בבינה מלאכותית

האפליקציה משתמשת בשירותי בינה מלאכותית כדי לספק תכונות כגון:

סיכום הערות פגישה;
הכנה לפגישה הבאה;
זיהוי מחשבות אוטומטיות שליליות;
זיהוי דפוסים קוגניטיביים;
זיהוי מחזורי CBT אפשריים;
זיהוי נושאים חוזרים;
הצפת נקודות שהמטפל עשוי שלא לקחת בחשבון;
תמיכה ברפלקציה ובהדרכה מקצועית;
שיחה עם עוזר AI.

לצורך מתן תכונות אלה, מידע שהמטפל בוחר להעביר לעיבוד AI עשוי להישלח לספקי שירותי AI חיצוניים.

אנו פועלים לצמצום מידע מזהה שאינו נדרש לצורך העיבוד, ובכלל זה שם המטופל, ככל שהמערכת מאפשרת זאת.

אין להשתמש בשם המטופל או במידע מזהה אחר כחלק מהמידע הנשלח ל-AI כאשר מידע זה אינו נדרש לצורך השירות.

5. כיצד אנו משתמשים במידע

המידע משמש לצורך:

הפעלת האפליקציה;
שמירת המידע שהמשתמש בוחר לתעד;
הצגת היסטוריית המטופל;
הצגת שאלונים ותוצאותיהם;
יצירת תוצרי AI שהמשתמש ביקש;
אבטחה, מניעת שימוש לרעה ותפעול השירות;
תמיכה טכנית;
שיפור אמינות השירות;
עמידה בדרישות חוקיות.

לא נמכור מידע אישי של משתמשים או מטופלים לצדדים שלישיים.

6. מידע שנשלח לספקי שירות

לצורך הפעלת האפליקציה אנו עשויים להשתמש בספקי שירות חיצוניים, כגון ספקי:

אחסון ענן;
אימות משתמשים;
תשתיות תוכנה;
שירותי בינה מלאכותית;
ניטור ותפעול.

ספקים אלה עשויים לעבד מידע מטעמנו בהתאם לתפקידם ולתנאים החוזיים החלים עליהם.

7. אבטחת מידע

אנו נוקטים אמצעים טכניים וארגוניים סבירים להגנה על המידע, לרבות בקרת גישה, אימות משתמשים ואמצעי אבטחה מתאימים לסביבת השירות.

אנו מגבילים גישה למידע למי שזקוק לכך לצורך תפקידו.

עם זאת, אין מערכת מידע או תקשורת שניתן להבטיח כי תהיה חסינה לחלוטין מפני חדירה, אובדן או שימוש בלתי מורשה.

הרשות להגנת הפרטיות מדגישה, בין היתר, את הצורך בניהול הרשאות גישה בהתאם לתפקיד ובשמירה על רשימת הרשאות מעודכנת.

8. שמירת מידע

אנו נשמור מידע כל עוד הדבר נדרש לצורך מתן השירות, עמידה בדרישות חוקיות, הגנה על זכויותינו או בהתאם למדיניות המחיקה שלנו.

כאשר מידע אינו נדרש עוד, נפעל למחיקתו או לאנונימיזציה שלו, בכפוף לחובות החלות עלינו.

9. זכויות המשתמש

בכפוף לדין החל, המשתמש עשוי להיות זכאי לבקש:

לעיין במידע הנוגע אליו;
לתקן מידע שאינו נכון;
למחוק מידע במקרים המתאימים;
לקבל מידע לגבי אופן השימוש במידע.

בקשות ניתן לשלוח ל:

amitishai@gmail.com

10. מידע על מטופלים

האפליקציה מיועדת למטפלים. המטפל הוא האחראי לוודא כי הזנת מידע על מטופל, שמירתו ועיבודו באמצעות האפליקציה נעשים כדין ובהתאם לחובותיו המקצועיות, לרבות חובות סודיות וקבלת הסכמות כאשר הדבר נדרש.

11. אירועי אבטחה

במקרה של אירוע אבטחה, נפעל בהתאם לדרישות הדין החלות עלינו, לרבות דרישות הדיווח והטיפול באירוע, ככל שיחולו.

הרשות להגנת הפרטיות מפעילה מסלול ייעודי לדיווח על אירועי אבטחה חמורים במאגרי מידע.

12. העברת מידע מחוץ לישראל

חלק מספקי השירות שבהם אנו משתמשים עשויים לעבד מידע מחוץ לישראל. במקרים כאלה נפעל בהתאם להוראות הדין הרלוונטיות להעברת מידע.

13. שינויים במדיניות

אנו רשאים לעדכן מדיניות זו מעת לעת. במקרה של שינוי מהותי נפעל ליידע את המשתמשים בדרך המקובלת.

14. יצירת קשר

לשאלות או בקשות בנושא פרטיות:

עמית אברון שטרן ישי
דוא"ל: amitishai@gmail.com
"""
    static let dateLabel = "Date"
    static let sessionDateTitle = "Session Date"

    // MARK: - Questionnaires (shared)

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
    static let aiModeChat = "Chat"
    static let aiSendAction = "Send"
    static let aiChatTitle = "Conversation"
    static let aiChatNavigationTitle = "AI Chat"
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
    static let settingsAccessibilitySectionTitle = "Accessibility"
    static let settingsTextSizeTitle = "Text Size"
    static let settingsTextSizeSmall = "Small"
    static let settingsTextSizeStandard = "Standard"
    static let settingsTextSizeLarge = "Large"
    static let settingsTextSizeExtraLarge = "Extra Large"
    static let settingsTextSizeHuge = "Huge"

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
    static let chartDateLabel = "Date"
    static let chartScoreLabel = "Score"

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

    /// One-line GAD-7/PHQ-9 score summary shown next to a questionnaire.
    static func gadPhqScores(gad7: Int, phq9: Int) -> String {
        "\(gad7ShortName): \(gad7) · \(phq9ShortName): \(phq9)"
    }

    /// A single compact score in a session row, e.g. "GAD-7: 12".
    static func scoreBadge(name: String, score: Int) -> String {
        "\(name): \(score)"
    }

    /// Accessibility label for the icon marking sessions that have an
    /// AI structured summary.
    static let hasStructuredSummaryLabel = "כולל סיכום מובנה"

    // MARK: - Session type

    static let sessionTypeLabel = "סוג פגישה"
    static let sessionTypeNone = "ללא"

    static func label(for type: SessionType) -> String {
        switch type {
        case .firstPhoneCall: return "שיחת טלפון ראשונה"
        case .intake: return "אינטייק"
        case .psychoEducation: return "פסיכו-חינוכי"
        case .diaryOne: return "יומן 1"
        case .diaryTwo: return "יומן 2"
        case .diaryThree: return "יומן 3"
        case .caseFormulation: return "המשגה"
        case .behavioralInterventions: return "חשיפות"
        case .relapsePreventionAndTermination: return "סיכום טיפול והישנות"
        }
    }

    /// The live total score line of a questionnaire part.
    static func totalScoreLine(_ score: Int) -> String {
        "\(scoreLabel): \(score)"
    }

    /// The previous questionnaire's score line.
    static func previousScoreLine(dateText: String, score: Int) -> String {
        "\(previousScoreLabel(dateText: dateText)): \(score)"
    }

    /// Indications of the previous questionnaire's answers.
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

    // MARK: - Session analysis

    static let sessionSummaryTitle = "Session Summary"
    static let sessionSummaryPlaceholder = "Session summary"
    static let keySituationsSection = "Key Situations"
    static let possibleAutomaticThoughtsSection = "Possible Automatic Thoughts"
    static let cbtCycleSection = "CBT Cycle"
    static let thingsWorthExploringSection = "Things Worth Exploring"
    static let questionsToRevisitSection = "Questions You May Want to Revisit"
    static let fullAnalysisTitle = "Full Analysis"
    static let saveSummaryPrompt = "Save this summary to the session?"
    static let dontSaveAction = "Don't Save"
    static let keepViewingAction = "Keep Viewing"
    static let thoughtLabel = "Thought"
    static let situationLabel = "Situation"
    static let emotionLabel = "Emotion"
    static let behaviorLabel = "Behavior"
    static let possibleConsequenceLabel = "Possible consequence"
    static let patientSaidBadge = "Patient said"
    static let possibleInferenceBadge = "Possible inference"
    static let possibleCognitivePatternsLabel = "Possible cognitive patterns"
    static let aiNoticedLabel = "The AI noticed"
    static let observationPlaceholder = "Observation"
    static let whyItMayMatterPlaceholder = "Why it may matter"
    static let worthExploringLabel = "Worth exploring"
    static let questionToExplorePlaceholder = "Question to explore"
    static let questionPlaceholder = "Question"
    static let whyItMattersLabel = "Why it matters"
    static let reasonPlaceholder = "Reason"
    static let discussedAction = "Discussed"
    static let followUpAction = "Follow up"
    static let notRelevantAction = "Not relevant"
    static let importancePlaceholder = "Importance"
    static let emotionsSection = "Emotions"
    static let possibleNatsSection = "Possible Negative Automatic Thoughts"
    static let behaviorsSection = "Behaviors"
    static let cbtPatternsSection = "CBT Patterns"
    static let maintainingCyclesSection = "Maintaining Cycles"
    static let developmentsSection = "Developments"
    static let therapistHypothesesSection = "Therapist Hypotheses"
    static let therapistReflectionsSection = "Therapist Reflections"
    static let followUpQuestionsSection = "Follow-up Questions"
    static let unresolvedIssuesSection = "Unresolved Issues"
    static let contextLabel = "Context"
    static let evidenceLabel = "Evidence"
    static let typeLabel = "Type"
    static let possibleFunctionLabel = "Possible function"
    static let sourceLabel = "Source"
    static let confidenceLabel = "Confidence"
    static let significanceLabel = "Significance"
    static let categoryLabel = "Category"
    static let priorityLabel = "Priority"

    // MARK: - Session preparation

    static let sessionPreparationTitle = "Session Preparation"
    static let preparationOutdatedMessage = "Outdated — a session has taken place since this was prepared."
    static let recurringNatsSection = "💭 Recurring Automatic Thoughts"
    static let maintenanceCyclesSection = "🔄 Possible Maintenance Cycles"
    static let maintenanceCyclesSubtitle = "AI hypotheses — mechanisms worth testing, not facts"
    static let whatChangedSection = "What Changed"
    static let questionnaireInsightsSection = "📊 Questionnaire Insights"
    static let supervisionConsiderSection = "🧠 Supervision — Things to Consider"
    static let priorityFollowUpsSection = "🔎 Priority Follow-ups"
    static let treatmentFocusSection = "🎯 Possible Treatment Focus"
    static let treatmentFocusSubtitle = "Suggested areas to consider — not instructions"
    static let suggestedQuestionsSection = "❓ Suggested Questions"
    static let unresolvedIssuesPreparationSection = "📌 Unresolved Issues"
    static let aiDisclaimer = "AI-generated clinical support. Use your professional judgment."
    static func tokensUsed(_ count: Int) -> String {
        "Tokens used: \(count)"
    }
    static func sourceLine(_ source: String) -> String {
        "Source: \(source)"
    }
    static let situationsLabel = "Situations"
    static let possibleThinkingPatternsLabel = "Possible thinking patterns"
    static let possibleMaintenanceCycleLabel = "Possible maintenance cycle"
    static let automaticThoughtLabel = "Automatic thought"
    static let shortTermConsequenceLabel = "Short-term consequence"
    static let longTermConsequenceLabel = "Long-term consequence"
    static let possibleCoreBeliefSection = "Possible Core Belief"
    static let coreBeliefSubtitle = "AI hypothesis — discuss and test, don't assume"
    static let questionToConsiderLabel = "Question to consider"
    static let hypothesisBadge = "Hypothesis"
    static let priorityHigh = "High"
    static let priorityMedium = "Medium"
    static let priorityLow = "Low"
    static func confidenceLine(_ value: String) -> String {
        "Confidence: \(value)"
    }
    /// A bulleted list line.
    static func bulleted(_ text: String) -> String {
        "•  \(text)"
    }

    // MARK: - My formulation

    static let treatmentGoalSection = "🎯 Treatment Goal"
    static let noTreatmentGoalPlaceholder = "No treatment goal defined — add one"
    static let goalFormatWarning = "Expected format: “Reduce X emotion from Y% to Z% in situations of …”"
    static let coreBeliefSection = "🧠 Core Belief"
    static let noCoreBeliefPlaceholder = "No core belief defined"
    static let keyAutomaticThoughtsSection = "💭 Key Automatic Thoughts"
    static let addThoughtAction = "Add Thought"
    static let maintainingBehaviorsSection = "🔄 Maintaining Behaviors"
    static let addBehaviorAction = "Add Behavior"
    static let keyCBTCycleSection = "🔁 Key CBT Cycle"
    static let removeCycleAction = "Remove Cycle"
    static let noKeyCBTCycleLabel = "No key CBT cycle defined"
    static let addCBTCycleAction = "Add CBT Cycle"
    static let therapistHypothesisSection = "🧩 Therapist Hypothesis"
    static let therapistHypothesisPlaceholder = "Your working hypothesis about what maintains the problem"
    static let automaticThoughtTitle = "Automatic Thought"
    static let challengeFormulationAction = "Challenge My Formulation"
    static let analyzingFormulationLabel = "Analyzing your formulation..."
    static let addFormulationContentHint = "Add some formulation information before asking AI to challenge it."
    static let whatAmIMissingAction = "What Am I Missing?"
    static let lookingAcrossHistoryLabel = "Looking across the patient's history..."
    static let aiSupervisionSection = "🧠 AI Supervision"
    static let aiSupervisionFooter = "The AI reviews your formulation and the patient's history. It never changes your formulation."
    static let longitudinalReviewAction = "סקירה לאורך זמן"
    static let analyzingOverTimeLabel = "מנתח את התהליך לאורך זמן..."
    static let longitudinalCaseReviewTitle = "📈 Longitudinal Case Review"
    static let longitudinalReviewFooter = "תמונה לאורך זמן: מה השתנה, מה נשאר ומה דורש תשומת לב."

    // MARK: - Supervision (Challenge My Formulation)

    static let aiGeneratedSupervisionLabel = "AI-generated supervision"
    static let supervisionDisclaimerBody = "These are hypotheses for clinical reflection, not established conclusions."
    static let supportsFormulationSection = "✓ What supports your formulation?"
    static let mayNotFitSection = "⚠ What may not fit?"
    static let mayNotFitSubtitle = "Evidence that may not fully fit the current formulation — something to weigh, not a verdict"
    static let alternativeFormulationsSection = "🔄 Alternative Formulations"
    static let alternativeFormulationsSubtitle = "Alternatives to consider — not diagnoses or conclusions"
    static let questionsToExploreSection = "❓ Questions to Explore"
    static let treatmentImplicationsSection = "🎯 Possible Treatment Implications"
    static let treatmentImplicationsSubtitle = "Possible areas to consider — not instructions"
    static let possibleBlindSpotsSection = "👁 Possible Blind Spots"
    static let blindSpotsSubtitle = "Hypotheses, not facts — areas the formulation may not be covering"
    static let possibleFormulationLabel = "Possible formulation"
    static let whatThisMightExplainLabel = "What this might explain"
    static func purposeLine(_ purpose: String) -> String {
        "Purpose: \(purpose)"
    }
    static let possibleAreaToConsiderLabel = "Possible area to consider"

    // MARK: - Supervision (What Am I Missing?)

    static let whatAmIMissingTitle = "🔎 What Am I Missing?"
    static let noAdditionalPatternsMessage = "No additional significant patterns were identified from the available information."
    static let whyThisMightMatterLabel = "Why this might matter"
    static let questionForTherapistLabel = "Question for therapist"
    static let categoryRecurringNat = "Recurring Automatic Thought"
    static let categoryCognitivePattern = "Thinking Pattern"
    static let categoryMaintainingBehavior = "Maintaining Behavior"
    static let categoryDiscrepancy = "Possible Discrepancy"
    static let categoryPersistentSymptom = "Persistent Symptom"
    static let categoryRepeatedSituation = "Repeated Situation"
    static let categoryUnexploredTheme = "Possible Unexplored Theme"
    static let categoryPossibleConnection = "Possible Connection"
    static let categoryTreatmentOpportunity = "Possible Treatment Opportunity"
    static let categoryRiskReview = "Risk Review"

    // MARK: - Supervision (Longitudinal Case Review)

    static let highConfidenceLabel = "High confidence"
    static let mediumConfidenceLabel = "Medium confidence"
    static let lowConfidenceLabel = "Low confidence"
    static let improvementsSection = "✅ Improvements"
    static let persistentDifficultiesSection = "⚠️ Persistent Difficulties"
    static let persistentDifficultiesSubtitle = "Things that do not appear to have changed sufficiently yet"
    static let recurringPatternsSection = "🔄 Recurring Patterns"
    static let recurringPatternsSubtitle = "What keeps coming back across the treatment"
    static let importantChangesSection = "🔀 Important Changes"
    static let treatmentGoalProgressSection = "🎯 Treatment Goal Progress"
    static let formulationEvolutionSection = "🧠 Formulation Evolution"
    static let formulationEvolutionSubtitle = "What appears to be becoming clearer? Hypotheses and interpretations, not established facts"
    static let worthAttentionSection = "👀 Worth Paying Attention To"
    static let worthAttentionSubtitle = "Areas the therapist may want to investigate — not instructions"
    static let overallTrajectorySection = "📈 Overall Trajectory"
    static let insufficientLongitudinalDataMessage = "אין מספיק מידע לאורך זמן כדי להסיק מסקנות נוספות בשלב זה."
    static let whatImprovedLabel = "מה השתפר"
    static let possibleInterpretationHebrewLabel = "פרשנות אפשרית"
    static let whyWeThinkSoLabel = "למה אנחנו חושבים כך"
    static let possibleInterpretationLabel = "Possible interpretation"
    static let currentEstimateLabel = "Current estimate"
    static let possibleNextStepLabel = "Possible next step to consider"
    static let questionsForTherapistSection = "❓ Questions for Therapist"
    static let questionsForTherapistSubtitle = "For reflective supervision — there are no required answers"
    static let goalStatusProgressing = "Progressing"
    static let goalStatusPartiallyProgressing = "Partially progressing"
    static let goalStatusUnchanged = "Unchanged"
    static let goalStatusWorsening = "Worsening"
    static let goalStatusAchieved = "Achieved"
    static let goalStatusUnclear = "Unclear"

    // MARK: - Errors

    static func transcriptionFailed(_ message: String) -> String {
        "Transcription failed: \(message)"
    }
    static func couldNotReadAudioFile(_ description: String) -> String {
        "Could not read audio file: \(description)"
    }
    static let sessionAnalysisFailedError = "Session analysis failed"
    static let invalidInputError = "Invalid input."
    static let invalidServerResponseError = "Invalid response from server."
    static let emptyAIResponseError = "The AI service returned an empty response."
    static let supabaseNotConfiguredError = "Supabase is not configured. Fill in your project URL and anon key in SupabaseConfig.swift."
    static func notImplementedError(_ feature: String) -> String {
        "\(feature) is not implemented yet."
    }
    static let patientNotSavedError = "This patient hasn't been saved to the database yet."
    static let sessionNotSavedError = "This session hasn't been saved to the database yet."
    static let updateRejectedError = "The server accepted the request but didn't change any row. Check the table's row-level security policies (UPDATE is likely missing)."
}
