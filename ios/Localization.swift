import Foundation

/// Central mapping of every user-facing string in the app.
///
/// The values are the app's existing wording, unchanged. Translate the
/// values in this one file — the rest of the app only ever references these
/// constants and never hard-codes user-facing wording.
enum L10n {
    
    // MARK: - Common
    
    static let save = "שמירה"
    static let cancel = "ביטול"
    static let done = "סיום"
    static let add = "הוספה"
    static let back = "חזרה"
    static let retry = "ניסיון נוסף"
    
    // MARK: - Auth
    
    static let appTitle = "CBTipul"
    static let authWelcomeSignIn = "נא להתחבר כדי להמשיך"
    static let authWelcomeSignUp = "נא ליצור חשבון על מנת להמשיך"
    static let authModePickerTitle = "מצב"
    static let authSignInAction = "התחברות"
    static let authSignUpAction = "הרשמה"
    static let emailPlaceholder = "אימייל"
    static let passwordPlaceholder = "סיסמה"
    static let forgotPasswordAction = "איפוס סיסמה"
    static let verifyEmailTitle = "אימות כתובת האימייל"
    /// The post-sign-up screen: where the verification link went and that
    /// opening it completes the registration.
    static func verifyEmailMessage(email: String) -> String {
        "שלחנו קישור אימות לכתובת \(email). יש לפתוח את הקישור כדי להשלים את ההרשמה."
    }
    static let backToSignInAction = "חזרה להתחברות"
    static let resendVerificationAction = "שליחת קישור חדש"
    static let verificationResentMessage = "קישור אימות חדש נשלח לכתובת האימייל."
    static let tooManyRequestsError = "נשלחו יותר מדי בקשות. יש להמתין מעט ולנסות שוב."
    static let emailNotConfirmedError = "כתובת האימייל עדיין לא אומתה. יש לפתוח את קישור האימות שנשלח אליך."
    static let verificationFailedError =
        "לא ניתן היה להשלים את אימות כתובת האימייל. ייתכן שהקישור פג תוקף. ניתן לנסות להתחבר או לבקש קישור חדש."
    static let newPasswordTitle = "סיסמה חדשה"
    static let newPasswordMessage = "יש לבחור סיסמה חדשה לחשבון."
    static let confirmPasswordPlaceholder = "אימות סיסמה"
    static let passwordsDontMatchError = "הסיסמאות אינן זהות."
    static let passwordRuleMinLength = "לפחות 8 תווים (12 ומעלה עדיף)"
    static let passwordRuleUppercase = "לפחות אות גדולה אחת (A-Z)"
    static let passwordRuleLowercase = "לפחות אות קטנה אחת (a-z)"
    static let passwordRuleDigit = "לפחות ספרה אחת"
    static let passwordRuleSpecial = "לפחות תו מיוחד אחד (! @ # $ %)"
    static let enterEmailFirstMessage = "נא לכתוב את האימייל קודם, ואז ללחוץ על ״איפוס סיסמה״."
    static let passwordResetSentMessage = "מייל לאיפוס סיסמה נשלח. נא לבדוק במייל ולאפס סיסמה."
    static let signOutAction = "התנתקות"
    
    // MARK: - Patients
    
    static let patientsTitle = "מטופלים/ות"
    static let loadingPatientsLabel = "טעינת מטופלים..."
    static let couldntLoadPatientsTitle = "טעינת מטופלים נכשלה"
    static let noPatientsTitle = "עדיין אין מטופלים"
    static let addFirstPatientMessage =
        "הוספת מטופל/ת מאפשרת להתחיל לתעד פגישות, שאלונים והתקדמות טיפולית."
    static let addPatientAction = "הוספת מטופל/ת"
    static let noSessionsYetLabel = "אין פגישות עדיין"
    static let newPatientTitle = "מטופל/ת חדש/ה"
    static let patientSectionTitle = "מטופל/ת"
    static let firstNamePlaceholder = "שם פרטי"
    static let lastNamePlaceholder = "שם משפחה"
    static let statusLabel = "סטטוס"
    static let patientStatusActive = "פעיל/ה"
    static let patientStatusInactive = "לא פעיל/ה"
    static func patientStatus(_ status: PatientStatus) -> String {
        switch status {
        case .active: patientStatusActive
        case .inactive: patientStatusInactive
        }
    }
    static let patientsSearchPrompt = "חיפוש מטופלים"
    static let patientsSearchEmpty = "לא נמצאו מטופלים"
    static let unnamedPatient = "מטופל/ת ללא שם"
    static func patientConnectedPushBody(name: String) -> String {
        PatientPushCopy.patientConnectedBody(name: name)
    }
    static let questionnaireCompletedPushGeneric = PatientPushCopy.genericQuestionnaireCompleted
    static func questionnaireCompletedPushBody(name: String) -> String {
        PatientPushCopy.questionnaireCompletedBody(name: name)
    }
    static let notesSection = "הערות"
    static let sessionSummarySection = "סיכום פגישה"
    
    static let optionalNotesPlaceholder = "הערות (לא חובה)"
    static let sessionSummaryFieldPlaceholder = "כתבו או הקליטו את סיכום הפגישה"
    static let patientNotesFieldPlaceholder = "כתבו או הקליטו הערות על המטופל/ת"
    
    static let myFormulationTitle = "הניסוח שלי"
    
    static let prepareNextSessionAction = "הכנה לפגישה הבאה"
    
    static let lastPreparationAction = "ההכנה האחרונה"
    
    static let outdatedBadge = "לא מעודכן"

    // MARK: - Getting Started / first-run

    static let welcomeTitle = "בואו נכיר את האפליקציה"
    static let welcomeBody =
        "מצב ההדגמה פועל בסביבה נפרדת. המטופלים האמיתיים שלך יוסתרו זמנית ולא יימחקו. המדריך נכנס למצב הדגמה עם קליניקה ריקה — כמו אחרי הרשמה. תיצרו מטופל/ת, פגישה ושאר הצעדים בעצמכם. בסוף המדריך (או בלחיצה על «דלגו לנתונים לדוגמה») יופיעו נתונים לדוגמה לצורכי התנסות. כל מה שייווצר במהלך המדריך נשמר במכשיר בלבד — לא יועלה לשרת."
    static let welcomePrimaryAction = "המשך למצב הדגמה"
    static let welcomeSecondaryAction = "אפשר לעבור על זה אחר כך"
    static let welcomeInfoLink = "איך נשמר המידע?"
    static let welcomeInfoBody =
        "שמות המטופלים נשמרים באופן מוצפן במכשיר בלבד ואינם מועלים לשרת. מידע אחר נשמר ומעובד בהתאם למדיניות הפרטיות ולהסכמות שניתנו באפליקציה."
    static let welcomeInfoDoneAction = "סגירה"

    static let gettingStartedTitle = "הצעדים הראשונים"
    static let gettingStartedSubtitle =
        "השלימו את הצעדים לפי הסדר. הכפתור הרלוונטי יהבהב כדי להדריך אתכם."
    static func gettingStartedProgress(_ step: Int, total: Int = 5) -> String {
        "שלב \(step) מתוך \(total)"
    }
    static let gettingStartedStepDemoTour = "סיור במצב הדגמה"
    static let gettingStartedStepAddPatient = "יצירת מטופל/ת"
    static let gettingStartedStepTreatmentGoal = "הגדרת מטרת טיפול"
    static let gettingStartedStepFirstSession = "יצירת פגישה"
    static let gettingStartedStepQuestionnaire = "מילוי שאלון"
    static let gettingStartedStepSessionSummary = "הוספת סיכום פגישה"
    static let gettingStartedStepAISummary = "יצירת סיכום AI"
    static let gettingStartedStepPreparation = "הכנה לפגישה הבאה"
    static let gettingStartedCompleteMessage = "המדריך הושלם — כל הכבוד!"
    static let gettingStartedRestartAction = "התחילו מחדש"
    static let gettingStartedDismissAccessibilityLabel = "הסתרת מדריך ההתחלה"
    static let gettingStartedGuideSettingsTitle = "הדרכה והתנסות באפליקציה"
    static let gettingStartedGuideSettingsSubtitle =
        "הדרכה מודרכת והתנסות עם מטופלים לדוגמה"

    static let tutorialCoachHintAddPatient =
        "לחצו על ״הוספת מטופל/ת ראשון/ה״ כדי להוסיף מטופל/ת"
    static let tutorialCoachHintFillNewPatient =
        "מילאו את שם המטופל/ת ולחצו על ״הוספת מטופל/ת״"
    static let tutorialCoachHintReturnPatientsAdd =
        "חזרו לרשימת המטופלים ולחצו על ״הוספת מטופל/ת ראשון/ה״"
    static let tutorialCoachHintOpenPatient =
        "לחצו על המטופל/ת שיצרתם/ן"
    static let tutorialCoachHintOpenSessions = "לחצו על ״פגישות״"
    static let tutorialCoachHintAddSession = "לחצו על ״הוספת פגישה ראשונה״"
    static let tutorialCoachHintSaveSession =
        "קבעו סוג פגישה ותאריך, ולחצו על ״הוספת פגישה״"
    static let tutorialCoachHintOpenSession =
        "לחצו על הפגישה שיצרתם/ן"
    static let tutorialCoachHintFillQuestionnaire = "לחצו על ״מילוי שאלון״"
    static let tutorialCoachHintCompleteQuestionnaire =
        "סמנו בחירה לכל שאלה, ולחצו על ״שמירה״ למעלה מצד שמאל."
    static let tutorialCoachHintRecordNotes =
        "הקלידו או הקליטו סיכום פגישה לדוגמה. האפליקציה תתמלל את ההקלטה באופן אוטומטי. הקלטה מתבצעת על ידי לחיצה על כפתור המיקרופון הצהוב."
    static let tutorialCoachHintAISummary = "לחצו על ״יצירת סיכום AI מובנה״"
    static let tutorialCoachHintReturnSessions = "חזרו למסך הפגישות כדי להמשיך"
    static let tutorialCoachHintFollowGlow = "עקבו אחרי הכפתור המסומן"

    static let demoModeBannerTitle = "מצב הדגמה"
    static let demoModeBannerBody = "קליניקה לדוגמה — לצורך המחשה בלבד."
    static let demoModeExitShort = "חזרה למטופלים שלי"
    static let exitDemoModeAction = "חזרה למטופלים שלי"
    static let enterDemoModeAction = "כניסה למצב הדגמה"

    static let tutorialCoachSkipToShowcase = "דלגו לנתונים לדוגמה"
    static let showcaseCountdownTitle = "עוד רגע — נתונים לדוגמה"
    static func showcaseCountdownSeconds(_ seconds: Int) -> String {
        "\(seconds) שניות"
    }
    static let showcaseRevealTitle = "עכשיו — נתונים לדוגמה!"
    static let showcaseRevealBody =
        "הוספנו מטופלים, פגישות ושאלונים לדוגמה כדי שתוכלו להתנסות בכל האפשרויות של האפליקציה. השתמשו בכל מסך, לחצו על כל כפתור — זה בטוח. כשתסיימו, לחצו «חזרה למטופלים שלי» בפס מצב ההדגמה למעלה."
    static let showcaseRevealExitHint = "אפשר לחזור למטופלים האמיתיים בכל רגע מהפס הצהוב למעלה."
    static let showcaseRevealAction = "בואו נתנסה"

    static let emptyPatientsPrimaryAction = "הוספת מטופל/ת ראשון/ה"
    static let emptySessionsTitle = "עדיין אין פגישות"
    static let emptySessionsBody =
        "הוספת פגישה מאפשרת לתעד סיכומים, לצרף שאלונים ולעקוב אחר התקדמות הטיפול."
    static let emptySessionsPrimaryAction = "הוספת פגישה ראשונה"
    static let emptyQuestionnairesTitle = "עדיין לא נוספו שאלונים"
    static let emptyQuestionnairesBody =
        "שאלונים מאפשרים לעקוב אחר שינויים בתסמינים לאורך זמן. כדי למלא שאלון יש ליצור פגישה ואז למלא אותו משם, או לבקש מהמטופל/ת למלא אם כבר מחובר/ת ל-CBTipul."
    static let emptyQuestionnairesPrimaryAction = "הוספת שאלון"
    static let preparationInsufficientTitle = "עדיין אין מספיק מידע להכנה"
    static let preparationInsufficientBody =
        "מומלץ להוסיף לפחות סיכום פגישה אחד או שאלון כדי ליצור הכנה שימושית יותר."
    static let firstPreparationTipBody =
        "איכות ההכנה משתפרת ככל שנוספים פגישות ושאלונים."
    static let firstQuestionnaireTipBody =
        "תשובות קודמות יופיעו במילוי שאלונים בהמשך."
    static let contextualTipContinueAction = "המשך"
    
    // MARK: - Sessions
    
    static let sessionsTitle = "פגישות"
    
    static let addSessionAction = "הוספת פגישה"
    
    static let newSessionTitle = "פגישה חדשה"
    
    static func session(_ number: Int) -> String {
        "פגישה \(number)"
    }
    
    /// Editor title for an existing session; the number is omitted when unknown.
    static func sessionEditorTitle(_ number: Int?) -> String {
        "פגישה\(number.map { " \($0)" } ?? "")"
    }
    
    static let editDateAccessibilityLabel = "עריכת תאריך"
    
    static let fromLastSessionHeader = "מהפגישה הקודמת"
    
    static func moreFollowUps(_ count: Int) -> String {
        "עוד (\(count))"
    }
    
    static let openQuestionsTitle = "שאלות פתוחות"
    
    static let markDiscussedAccessibilityLabel = "סימון כנושא שנדון"
    
    static let analyzingLabel = "בניתוח…"
    
    static let aiSummaryAction = "יצירת סיכום AI מובנה"
    
    static let showStructuredSummaryAction = "הצגת סיכום AI מובנה בשלמותו"
    
    static let structuredSummarySection = "סיכום AI מובנה"
    
    static let deleteSessionAction = "מחיקת פגישה"
    
    static let deleteSessionConfirmTitle = "למחוק את הפגישה?"
    
    static let deleteSessionConfirmMessage =
    "מחיקת הפגישה והמידע שלה תהיה לצמיתות. לא ניתן לבטל פעולה זו."
    
    static let editQuestionnaireAction = "עריכה"
    
    static let deleteQuestionnaireAction = "מחיקת שאלון"
    
    static let deleteQuestionnaireConfirmTitle = "למחוק את השאלון?"
    
    static let deleteQuestionnaireConfirmMessage =
    "מחיקת השאלון והתשובות שלו תהיה לצמיתות. לא ניתן לבטל פעולה זו."

    static let questionnaireIncompleteTitle = "השאלון לא הושלם"

    static let questionnaireIncompleteMessage =
    "יש לענות על כל השאלות כדי לשמור את השאלון."
    
    // MARK: - Delete code challenge
    
    static let deleteCodeTitle = "אישור מחיקה נוסף"
    
    /// Message of the second delete confirmation, showing the code the
    /// user must type back to complete the deletion.
    static func deleteCodeMessage(_ code: String) -> String {
        "להשלמת המחיקה יש להקליד את הקוד:\n\(code)"
    }
    
    static let deleteCodePlaceholder = "הקלדת הקוד"
    
    static let deleteCodeConfirmAction = "מחיקה"
    
    static let deleteCodeMismatchTitle = "הקוד שגוי"
    
    static let deleteCodeMismatchMessage = "הקוד שהוקלד אינו תואם, ולכן המחיקה לא בוצעה."
    
    static let ok = "אישור"

    /// A date in Hebrew wording (e.g. "24 באוג׳ 2026"), for strings whose
    /// surrounding text is Hebrew regardless of the device locale.
    static func hebrewDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted,
                                        locale: Locale(identifier: "he_IL")))
    }

    /// A numeric date in Hebrew conventions (e.g. "27.8.2026").
    static func hebrewNumericDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .numeric, time: .omitted,
                                        locale: Locale(identifier: "he_IL")))
    }

    /// A numeric date and short time in Hebrew conventions
    /// (e.g. "27.8.2026, 19:45"), for timestamps in Hebrew note headers.
    static func hebrewDateTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .numeric, time: .shortened,
                                        locale: Locale(identifier: "he_IL")))
    }

    /// A month-and-year headline in Hebrew (e.g. "אוגוסט 2026").
    static func hebrewMonth(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: Locale(identifier: "he_IL"))
            .month(.wide).year())
    }
    
    static let editPatientNameAction = "עריכת שם"

    static let editPatientNameTitle = "עריכת שם מטופל/ת"

    static let deletePatientAction = "מחיקת מטופל/ת"
    
    static let deletePatientConfirmTitle = "למחוק את המטופל/ת?"
    
    static let deletePatientConfirmMessage =
    "מחיקת המטופל/ת וכל הפגישות והמידע הקשור אליהם תהיה לצמיתות. לא ניתן לבטל פעולה זו."
    
    // MARK: - Patient state
    
    static let editTreatmentGoalAction = "עריכת מטרת הטיפול"
    /// The at-a-glance session counter in the patient's current-state strip.
    static func sessionsCount(_ count: Int) -> String {
        count == 1 ? "פגישה אחת" : "\(count) פגישות"
    }
    
    /// A patient row's last-session summary, e.g. "אינטייק · 7 פגישות".
    static func lastSessionSummary(_ typeOrDate: String, count: Int) -> String {
        "\(typeOrDate) · \(sessionsCount(count))"
    }
    
    // MARK: - Terms and conditions
    
    static let termsTitle = "תנאי שימוש"
    
    static let termsAgreeAction = "הסכמה והמשך"
    static let termsBody = """
    תנאי שימוש והסכם משתמש

    עודכן לאחרונה: 29/8/2026

    ברוכים הבאים ל־CBTipul ("האפליקציה").

    תנאי שימוש אלה מהווים הסכם בין המשתמש/ת לבין מפעיל האפליקציה. הכניסה לאפליקציה, ההרשמה או השימוש בה מהווים אישור לכך שתנאים אלה ומדיניות הפרטיות נקראו והובנו וכי קיימת הסכמה להם.

    אם אין הסכמה לתנאים אלה, אין להשתמש באפליקציה.

    1. מטרת האפליקציה

    האפליקציה מיועדת לשמש כלי עזר מקצועי למטפלים/ות, לאנשי ונשות מקצוע ולמטפלים/ות בהכשרה הפועלים/ות תחת הדרכה מתאימה, לצורך:

    • ניהול מידע הקשור למטופלים/ות;
    • תיעוד פגישות והערות טיפוליות;
    • הגדרת מטרות טיפול;
    • מילוי ומעקב אחר שאלונים;
    • מעקב אחר מידע לאורך זמן;
    • הפקת סיכומים ותובנות מסייעות;
    • הכנה לקראת פגישות;
    • שימוש בכלים המבוססים על בינה מלאכותית.

    האפליקציה אינה שירות רפואי, אינה מיועדת לספק טיפול ואינה מהווה תחליף להכשרה מקצועית, להדרכה, לשיקול דעת קליני או לאחריות המקצועית של המשתמש/ת.

    האפליקציה אינה מיועדת לשימוש עצמאי של מטופלים/ות לצורך אבחון, טיפול או קבלת החלטות רפואיות.

    2. הרשאה וכשירות לשימוש

    השימוש באפליקציה מותר רק למי שרשאי/ת לעשות שימוש במידע המוזן אליה בהתאם להכשרה, לסמכות, לחובות המקצועיות ולהוראות הדין החלות עליו/ה.

    המשתמש/ת מצהיר/ה כי:

    • השימוש באפליקציה נעשה במסגרת חוקית ומקצועית;
    • קיימת הרשאה מתאימה לעיבוד המידע המוזן לאפליקציה;
    • התקבלו הסכמות או אישורים נדרשים ממטופלים/ות, ככל שהם נדרשים;
    • השימוש באפליקציה אינו מפר חובת סודיות, חובה אתית או הוראת דין.

    האפליקציה אינה בודקת את ההכשרה, הרישוי, ההסמכה או הסמכות המקצועית של המשתמש/ת.

    3. שימוש בבינה מלאכותית

    האפליקציה עשויה להשתמש בשירותי בינה מלאכותית לצורך, בין היתר:

    • יצירת סיכום מובנה של הערות טיפוליות;
    • זיהוי שינויים ודפוסים אפשריים לאורך זמן;
    • זיהוי מחשבות אוטומטיות שליליות אפשריות;
    • הצגת מעגלי CBT אפשריים;
    • העלאת השערות לגבי דפוסי חשיבה או אמונות ליבה;
    • הכנה לקראת פגישה;
    • הצפת שאלות, נקודות להתייחסות ונושאים אפשריים להמשך עבודה;
    • מתן תובנות לצורכי הדרכה ורפלקציה מקצועית;
    • ניתוח שאלוני GAD-7 ו-PHQ-9;
    • תמלול קובצי שמע;
    • שיחה עם עוזר בינה מלאכותית;
    • הסרת פרטים מזהים מטקסט חופשי.

    תוצרי הבינה המלאכותית הם הצעות, השערות וכלי עזר בלבד.

    התוצרים אינם מהווים אבחנה, חוות דעת רפואית או פסיכולוגית, הערכת סיכון, הוראה טיפולית, המלצה רפואית או תחליף לבדיקה ולהערכה מקצועית.

    תוצרי בינה מלאכותית עשויים לכלול טעויות, מידע חסר, ניסוחים לא מדויקים, הטיות, פרשנויות שגויות או מידע שאינו נתמך במידע שהוזן.

    יש לבדוק באופן עצמאי כל תוצר לפני שימוש בו או הסתמכות עליו.

    4. אחריות מקצועית והערכת סיכון

    האחריות הבלעדית לקבלת החלטות בנוגע למטופל/ת, לאבחון, לטיפול, להערכת סיכון ולכל פעולה מקצועית אחרת חלה על המשתמש/ת, בהתאם להכשרתו/ה ולחובות המקצועיות, האתיות והחוקיות החלות עליו/ה.

    אין להסתמך על האפליקציה או על תוצרי בינה מלאכותית כמקור יחיד לקבלת החלטה הנוגעת למטופל/ת.

    אין להשתמש באפליקציה כתחליף להערכה ישירה של מצבי חירום, אובדנות, פגיעה עצמית, אלימות, סכנה מיידית או כל מצב אחר המחייב התערבות מקצועית או פנייה לשירותי חירום.

    האפליקציה עשויה להדגיש מידע מסוים, לרבות תשובות לשאלונים, אך אינה יכולה להבטיח זיהוי של כל סימן סיכון או מצב חירום.

    במקרה של חשש לסכנה מיידית יש לפעול בהתאם לשיקול הדעת המקצועי, לנהלים החלים ולשירותי החירום הרלוונטיים, ללא תלות באפליקציה.

    5. מידע על מטופלים/ות

    המשתמש/ת אחראי/ת לוודא כי הוא/היא רשאי/ת לאסוף, להזין, לשמור, להעביר ולעבד את המידע המוזן לאפליקציה.

    אין להזין מידע מעבר לנדרש לצורך השימוש המקצועי באפליקציה.

    שמות מטופלים/ות אינם מיועדים להישמר במסד הנתונים של CBTipul. האפליקציה משתמשת במזהים פנימיים, והמיפוי בין שם המטופל/ת לבין המזהה נשמר מקומית במכשיר.

    אין להזין בשדות טקסט חופשי פרטים מזהים שאינם נחוצים, כגון:

    • שם מלא;
    • מספר זהות;
    • מספר טלפון;
    • כתובת דוא"ל;
    • כתובת מגורים מדויקת;
    • שם משתמש או קישור אישי;
    • מספר תיק או מספר מזהה אחר;
    • מקום עבודה או מוסד לימודים כאשר אינם נחוצים;
    • פרטים ייחודיים העלולים לאפשר זיהוי של המטופל/ת.

    האחריות לצמצום המידע ולבדיקת נחיצותו נשארת בידי המשתמש/ת.

    6. הסרת פרטים מזהים מטקסט חופשי

    לפני שמירת טקסט חופשי הקשור למטופל/ת בשרת, האפליקציה עשויה להעביר אותו לתהליך אוטומטי שמטרתו להסיר או להכליל פרטים מזהים.

    תהליך זה עשוי לחול, בין היתר, על:

    • מטרות טיפול;
    • רשימות מפגישות;
    • הערות על מטופלים/ות;
    • הערות המצורפות לשאלונים;
    • שדות אחרים שבהם ניתן להזין טקסט חופשי.

    לצורך ביצוע התהליך, הטקסט המקורי מועבר באופן זמני דרך תשתיות האפליקציה וספקי השירות שלה, לרבות Supabase ו-OpenAI API.

    פרטים ידועים של המטפל/ת, כגון שם המטפל/ת, עשויים להישלח לצורך הבחנה בינם לבין פרטים המתייחסים למטופל/ת.

    רק הטקסט שהוחזר לאחר תהליך הסרת הפרטים המזהים מיועד להישמר במסד הנתונים.

    הטקסט המקורי אינו מיועד להישמר במסד הנתונים של האפליקציה כחלק מתהליך זה ואינו מתועד ביומני האפליקציה.

    מערכת אוטומטית אינה יכולה להבטיח הסרה מלאה של כל פרט מזהה או אנונימיות מוחלטת. היא עשויה:

    • לא לזהות פרט מזהה מסוים;
    • להסיר מידע שאינו מזהה;
    • לשנות ניסוח או פרט בעל משמעות;
    • להכליל מידע באופן רחב מדי;
    • לפרש באופן שגוי למי מתייחס פרט מסוים.

    לפני שמירת הטקסט יש לבדוק כי לא נותרו בו פרטים מזהים וכי משמעותו הקלינית נשמרה.

    אין להסתמך על מנגנון הסרת הפרטים המזהים כתחליף להימנעות מהזנת מידע מזהה שאינו נחוץ.

    7. הקלטות ותמלול

    האפליקציה עשויה לאפשר הקלטה או העלאה של קובצי שמע לצורך תמלול.

    קובץ השמע עשוי להישלח לספק שירות חיצוני לצורך ביצוע התמלול.

    קובצי שמע שנשלחים לצורך תמלול אינם מיועדים להישמר על ידי CBTipul לאחר השלמת התמלול.

    תוצר התמלול עשוי לעבור תהליך של הסרת פרטים מזהים ולהישמר כחלק מנתוני האפליקציה, בהתאם לפעולת המשתמש/ת.

    המשתמש/ת אחראי/ת לקבל כל הסכמה הנדרשת לצורך הקלטה, תמלול או עיבוד של שיחה.

    אין להקליט אדם ללא הרשאה או בניגוד להוראות הדין.

    8. שאלונים

    האפליקציה עשויה לאפשר שימוש בשאלוני הערכה, לרבות GAD-7 ו-PHQ-9.

    השאלונים נועדו לתמיכה במעקב ובהערכה ואינם מהווים, כשלעצמם, אבחנה רפואית, פסיכולוגית או פסיכיאטרית.

    ציונים, שינויים בציונים או התראות שמוצגות באפליקציה אינם תחליף להערכה מקצועית מלאה.

    המשתמש/ת אחראי/ת לפרש את תוצאות השאלונים בהתאם להקשר הקליני ולפעול לפי שיקול דעת מקצועי.

    9. חשבון ואבטחת פרטי התחברות

    המשתמש/ת אחראי/ת:

    • למסור מידע נכון בעת יצירת החשבון;
    • לשמור על סודיות פרטי ההתחברות;
    • לא למסור את החשבון או לאפשר שימוש בו לאחרים;
    • לנעול ולהגן על המכשיר שבו מותקנת האפליקציה;
    • לעדכן את מפעיל האפליקציה ללא דיחוי במקרה של חשש לגישה בלתי מורשית.

    כל פעולה שמתבצעת באמצעות החשבון עשויה להיחשב כפעולה של בעל/ת החשבון, אלא אם נמסרה הודעה על שימוש בלתי מורשה.

    10. שימוש מותר ואסור

    יש להשתמש באפליקציה רק למטרות חוקיות ובהתאם לתנאים אלה.

    אין:

    • להשתמש באפליקציה בניגוד לדין או לחובות מקצועיות;
    • להזין מידע שאין הרשאה לעבדו;
    • לפגוע בפרטיות, בסודיות או בזכויות של אדם אחר;
    • לנסות לעקוף מנגנוני אבטחה, הרשאות או מגבלות שימוש;
    • לנסות לקבל גישה לחשבון, למידע או למערכות שאינם שייכים למשתמש/ת;
    • לבצע שימוש אוטומטי, חריג או מכביד העלול לפגוע בשירות;
    • להחדיר קוד זדוני, לשבש את פעילות האפליקציה או לפגוע בתשתיותיה;
    • להשתמש באפליקציה לצורך פגיעה, הטרדה, אפליה או פעילות בלתי חוקית;
    • להעתיק, לפרק, לבצע הנדסה לאחור או לנסות לחשוף את קוד המקור, למעט כאשר הדבר מותר במפורש לפי דין.

    11. תוכן שהוזן על ידי המשתמש/ת

    המשתמש/ת שומר/ת על הזכויות בתוכן שהוא/היא מזין/ה לאפליקציה, ככל שזכויות אלה שייכות לו/ה.

    המשתמש/ת מעניק/ה למפעיל האפליקציה ולספקי השירות מטעמו הרשאה מוגבלת לעבד, להעביר, לאחסן ולהציג את התוכן רק במידה הנדרשת לצורך:

    • הפעלת האפליקציה;
    • ביצוע הפעולות שהתבקשו;
    • מתן תמיכה;
    • אבטחת השירות;
    • עמידה בהוראות הדין.

    המשתמש/ת מצהיר/ה כי הזנת התוכן והשימוש בו אינם מפרים זכויות, פרטיות או חובת סודיות של אדם אחר.

    12. פרטיות וספקי שירות חיצוניים

    השימוש במידע כפוף גם למדיניות הפרטיות של CBTipul, המהווה חלק מתנאי שימוש אלה.

    האפליקציה משתמשת בספקי שירות חיצוניים, ובהם Supabase לצורכי אימות, מסד נתונים ופונקציות שרת, ו-OpenAI API לצורכי תמלול, הסרת פרטים מזהים ועיבוד מבוסס בינה מלאכותית.

    השימוש בספקים חיצוניים עשוי להיות כפוף גם לתנאים, למדיניות ולמגבלות הטכניות שלהם.

    מידע עשוי לעבור עיבוד מחוץ למדינת ישראל בהתאם למיקום התשתיות ולפעילות ספקי השירות.

    13. דיוק ושלמות המידע

    נעשים מאמצים לספק מערכת שימושית ואמינה, אך אין התחייבות לכך ש:

    • מידע או תוצר שיופקו יהיו מדויקים, נכונים או מלאים;
    • כל דפוס, שינוי או פרט משמעותי יזוהה;
    • כל פרט מזהה יוסר;
    • המידע יישמר ללא שגיאה או אובדן;
    • האפליקציה תהיה נקייה מתקלות;
    • תוצר מסוים יתאים לצורך מקצועי מסוים.

    יש לבדוק את המידע לפני שימוש בו במסגרת טיפולית או מקצועית.

    14. אבטחת מידע

    ננקטים אמצעים טכניים וארגוניים סבירים לצמצום הסיכון לגישה, שימוש, שינוי, אובדן או חשיפה בלתי מורשים של מידע.

    עם זאת, אין מערכת מחשוב, תקשורת, אחסון או אנונימיזציה שיכולה להיות מובטחת כחסינה לחלוטין מפני תקלה, אובדן מידע, גישה בלתי מורשית או אירוע אבטחה.

    השימוש באפליקציה נעשה מתוך הבנה של מגבלות אלה.

    15. זמינות השירות

    האפליקציה והשירותים המשולבים בה מסופקים כפי שהם ובהתאם לזמינותם.

    ייתכנו:

    • תקלות;
    • שגיאות;
    • זמני השבתה;
    • עבודות תחזוקה;
    • מגבלות שימוש;
    • שינויים בתכונות;
    • אי-זמינות של שירותי צד שלישי;
    • עיכוב, אובדן או כשל בהשלמת פעולה.

    מפעיל האפליקציה רשאי לעדכן, לשנות, להוסיף, להסיר, להשעות או להפסיק חלקים מהאפליקציה או מהשירות, בכפוף להוראות הדין.

    אין התחייבות לכך שתכונה מסוימת תישאר זמינה לצמיתות.

    16. גיבוי ושמירת עותקים

    האפליקציה אינה מיועדת לשמש כמקור היחיד למידע הנדרש לצורכי טיפול, תיעוד מקצועי, תיעוד רפואי או עמידה בחובות חוקיות.

    המשתמש/ת אחראי/ת לשמור כל תיעוד או עותק נוסף הנדרש בהתאם לחובות המקצועיות והחוקיות החלות עליו/ה.

    אין להסתמך על האפליקציה כשירות גיבוי יחיד.

    17. מחיקת מידע וחשבון

    ניתן למחוק פריטים מסוימים מתוך האפליקציה, בהתאם לאפשרויות הזמינות בה.

    מחיקת מטופל/ת, פגישה או פריט אחר עשויה למחוק לצמיתות גם מידע קשור, בהתאם להודעת האישור המוצגת באפליקציה.

    ניתן לבקש מחיקה של החשבון והמידע המשויך אליו מתוך האפליקציה דרך:

    הגדרות → מחיקת חשבון

    מחיקת החשבון מיועדת למחוק את החשבון ואת המידע המשויך אליו, לרבות מידע שנשמר עבורו, בכפוף למידע שקיימת חובה חוקית לשמור ולמשך הזמן הנדרש להשלמת מחיקה ממערכות גיבוי.

    לאחר מחיקה ייתכן שלא יהיה ניתן לשחזר את החשבון או את המידע.

    18. קניין רוחני

    כל הזכויות באפליקציה, לרבות העיצוב, הקוד, המבנה, הממשק, הסימנים המסחריים, הגרפיקה והתוכן השייך למפעיל האפליקציה, ככל שאינם שייכים לצד שלישי, שמורות למפעיל האפליקציה.

    ניתנת למשתמש/ת הרשאה אישית, מוגבלת, ניתנת לביטול, בלתי בלעדית ואינה ניתנת להעברה להשתמש באפליקציה בהתאם לתנאים אלה.

    אין להעתיק, להפיץ, למכור, להשכיר, לשנות, ליצור יצירה נגזרת, לפרק, לבצע הנדסה לאחור או לעשות שימוש מסחרי בלתי מורשה באפליקציה.

    19. השעיה והפסקת שימוש

    המשתמש/ת רשאי/ת להפסיק להשתמש באפליקציה בכל עת.

    מפעיל האפליקציה רשאי להגביל, להשעות או להפסיק גישה לחשבון כאשר קיים חשש סביר לכך שהשימוש:

    • מפר תנאים אלה;
    • מפר הוראת דין;
    • פוגע בפרטיות או בזכויות של אדם אחר;
    • מסכן את האפליקציה, המשתמשים/ות או ספקי השירות;
    • כרוך בניסיון לעקוף מנגנוני אבטחה או מגבלות שימוש.

    ככל שניתן ובהתאם לנסיבות, תימסר הודעה מתאימה.

    20. הגבלת אחריות

    במידה המרבית המותרת לפי דין, האפליקציה, מפעיליה וספקי השירות אינם אחראים לנזק עקיף, תוצאתי, מיוחד או בלתי צפוי הנובע מהשימוש באפליקציה או מחוסר האפשרות להשתמש בה.

    מבלי לגרוע מהאמור, אין אחריות לנזק הנובע מ:

    • הסתמכות על תוצר של בינה מלאכותית;
    • החלטה מקצועית או קלינית;
    • טעות, השמטה או פרשנות שגויה בתוצר;
    • אי-זיהוי של מצב סיכון;
    • אי-הסרה של פרט מזהה;
    • אובדן, שינוי או מחיקה של מידע;
    • שימוש בלתי מורשה בחשבון;
    • תקלה או הפסקה בשירות של ספק חיצוני;
    • הזנת מידע ללא הרשאה מתאימה.

    אין בתנאים אלה כדי לשלול אחריות שלא ניתן לשלול או להגביל לפי דין.

    21. שינויים באפליקציה ובתנאים

    מפעיל האפליקציה רשאי לעדכן תנאים אלה מעת לעת.

    במקרה של שינוי מהותי, עשויה להינתן הודעה באמצעות האפליקציה, בדוא"ל או באמצעי מתאים אחר.

    המשך השימוש באפליקציה לאחר כניסת התנאים המעודכנים לתוקף יהווה הסכמה להם, בכפוף להוראות הדין.

    אם אין הסכמה לתנאים המעודכנים, יש להפסיק להשתמש באפליקציה ולמחוק את החשבון.

    22. הוראות כלליות

    אם הוראה מתנאים אלה תיקבע כבלתי תקפה או בלתי ניתנת לאכיפה, יתר ההוראות יישארו בתוקף.

    אי-מימוש של זכות לפי תנאים אלה אינו מהווה ויתור עליה.

    אין להעביר את הזכויות או ההתחייבויות לפי תנאים אלה לאדם אחר ללא הסכמה מראש ובכתב של מפעיל האפליקציה.

    23. דין וסמכות שיפוט

    תנאים אלה כפופים לדיני מדינת ישראל.

    סמכות השיפוט בכל מחלוקת הנוגעת לתנאים אלה או לשימוש באפליקציה תהיה בהתאם להוראות הדין החל.

    24. יצירת קשר

    לשאלות, בקשות או פניות בנוגע לתנאי השימוש ניתן ליצור קשר:

    מפעיל האפליקציה: עמית אברון שטרן ישי

    דוא"ל: support@cbtipul.com
    """
    // MARK: - Privacy policy
    
    static let privacyPolicyTitle = "מדיניות פרטיות"
    static let settingsSupportTitle = "תמיכה"
    /// The app version line at the bottom of Settings, e.g. "גרסה 1.0 (4)".
    static func appVersionLabel(version: String, build: String) -> String {
        "גרסה \(version) (\(build))"
    }
    static let settingsPrivacyChoicesTitle = "בחירות פרטיות"

    // MARK: - AI data-sharing consent

    static let aiConsentTitle = "שימוש בשירותי בינה מלאכותית"
    static let aiConsentBody = """
    לצורך תמלול, הסרת פרטים מזהים, הפקת סיכומים וניתוחים מסייעים, האפליקציה משתמשת בשירותי OpenAI.

    טקסט חופשי עשוי להישלח ל־OpenAI לצורך הסרת פרטים מזהים לפני שמירתו. הטקסט המקורי אינו נשמר על ידי האפליקציה.

    קובצי שמע עשויים להישלח ל־OpenAI לצורך תמלול. קובץ השמע אינו נשמר על ידי האפליקציה לאחר השלמת התמלול, והתמלול עובר תהליך להסרת פרטים מזהים לפני שמירתו.

    לאחר הסרת הפרטים המזהים, מידע עשוי להישלח ל־OpenAI לצורך הפעלת כלי הבינה המלאכותית באפליקציה.

    בלחיצה על ״אישור והמשך״ קיימת הסכמה להעברת המידע המתואר לעיל ל־OpenAI לצרכים אלה.
    """
    static let aiConsentAcceptAction = "אישור והמשך"
    static let aiConsentDeclineAction = "לא עכשיו"
    static let settingsAIConsentTitle = "שיתוף מידע עם שירותי בינה מלאכותית"
    static let settingsAIConsentApprovedStatus = "אושר"
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
    static let dateLabel = "תאריך"
    
    static let sessionDateTitle = "תאריך הפגישה"
    
    // MARK: - Questionnaires (shared)
    
    static let combinedTitle = "שאלון משולב"
    
    static let addQuestionnaireAction = "מילוי שאלון"
    
    static let notesSectionTitle = "הערות"
    
    static let notesFieldPlaceholder = "הערות"
    
    static let questionNoteTitle = "הערה לשאלה"
    
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
    
    static let voiceNoteSectionTitle = "הקלטה קולית"
    
    static let recordVoiceNoteAction = "הקלטת הערה קולית"
    
    static let recordingLabel = "הקלטה מתבצעת…"
    
    static let voiceNoteLabel = "הערה קולית"
    
    static let micPermissionDenied =
    "נדרשת גישה למיקרופון לצורך הקלטה. יש לאפשר גישה בהגדרות."
    
    static let transcribeAction = "תמלול"
    
    static let transcribingLabel = "מתבצע תמלול…"
    
    // MARK: - AI assistant
    
    static let aiTitle = "שיחת AI"
    
    static let aiAction = "שיחת AI"
    
    static let aiModePickerTitle = "מצב"
    
    static let aiModeInsights = "תובנות"
    
    static let aiModeQuestionnaires = "שאלונים"
    
    static let aiModeGeneral = "כללי"
    
    static let aiModeChat = "שיחה"
    
    static let aiSendAction = "שליחה"
    
    static let aiChatTitle = "שיחה"
    
    static let aiChatNavigationTitle = "שיחת AI"
    
    /// Hint in the chat's message field, e.g. "שאלה על באגס באני".
    static func aiPromptPlaceholder(_ name: String) -> String {
        "שאלה על \(name)"
    }
    
    /// Shown in the middle of the chat before the first question.
    static let aiEmptyMessage =
    "אפשר לשאול כל שאלה על המטופל/ת — הפגישות, ההערות והשאלונים משמשים כהקשר לתשובה."
    
    /// Example questions offered in the empty chat; tapping one fills the field.
    static let aiSuggestedQuestions = [
        "סיכום קצר של המצב הנוכחי",
        "מה השתנה מאז תחילת הטיפול?",
        "אילו דפוסים חוזרים בפגישות?",
    ]
    
    static let aiGenerateInsightsAction = "הפקת תובנות"
    
    static let aiAskAction = "שאלה"
    
    static let aiThinkingLabel = "מעבד…"
    
    static let aiResponseTitle = "תשובה"
    
    // MARK: - Settings
    
    static let settingsTitle = "הגדרות"
    
    static let settingsAISectionTitle = "שיחת AI"
    
    static let settingsResponseStyleTitle = "סגנון תשובה"
    
    static let settingsResponseStyleTyping = "הקלדה"
    
    static let settingsResponseStyleRegular = "רגיל"
    
    static let settingsDoneAction = "סיום"
    static let settingsAppearanceTitle = "מראה"
    static let appearanceLight = "בהיר"
    static let appearanceDark = "כהה"
    
    static let settingsAccountSectionTitle = "חשבון"

    static let settingsTherapistDisplayNameTitle = "שם לתצוגה למטופלים"

    static let settingsTherapistDisplayNameUnset = "לא הוגדר"

    static let therapistDisplayNamePromptTitle = "מה השם שיוצג למטופלים?"

    static let therapistDisplayNamePromptExplanation =
        "השם יוצג למטופלים שתזמין/י להשתמש ב-CBTipul."

    static let therapistDisplayNamePlaceholder = "שם לתצוגה"

    static let therapistDisplayNameSkipAction = "לא עכשיו"

    static let therapistDisplayNameEmptyError = "יש להזין שם לתצוגה."

    static let therapistDisplayNameSaveError = "לא ניתן היה לשמור את השם. יש לנסות שוב."

    static let therapistDisplayNameLoadError = "לא ניתן היה לטעון את השם. יש לנסות שוב."

    static let therapistDisplayNameNotSignedInError = "יש להתחבר כדי לשמור שם לתצוגה."

    static let invitePatientAction = "הזמנת מטופל/ת"

    static let patientInvitationFailedTitle = "לא ניתן היה ליצור הזמנה"

    static let patientInvitationInvalidPatientError = "לא ניתן להזמין מטופל/ת זה/ו."

    static func patientInvitationShareMessage(therapistName: String, invitationUrl: String) -> String {
        """
        היי,
        הוזמנת להתחבר ל-CBTipul על ידי \(therapistName).

        להתחברות:
        \(invitationUrl)
        """
    }

    static let invitePreviewTitle = "הוזמנת ל-CBTipul"

    static func invitePreviewTherapistLine(_ therapistDisplayName: String) -> String {
        "\(therapistDisplayName) הזמין/ה אותך להתחבר ל-CBTipul."
    }

    static let invitePreviewExplanation =
        "CBTipul מאפשר לך למלא שאלונים וכלים טיפוליים שהמטפל/ת שלך שולח/ת אליך."

    static let invitePreviewContinueAction = "המשך"

    static let invitePreviewCloseAction = "סגירה"

    static let inviteConsentTitle = "הסכמה לשימוש ב-CBTipul"

    static let inviteConsentIntro =
        "לפני שמתחילים, חשוב לדעת איך CBTipul משמש כחלק מהתהליך הטיפולי שלך."

    static let inviteConsentTherapistHeading = "חיבור למטפל/ת"

    static let inviteConsentTherapistBody =
        "השימוש ב-CBTipul מתבצע במסגרת הקשר שלך עם המטפל/ת שהזמין/ה אותך. מידע שתמלא/י באפליקציה עשוי להיות זמין למטפל/ת שלך ולשמש כחלק מהתהליך הטיפולי."

    static let inviteConsentDataHeading = "המידע שלך"

    static let inviteConsentDataBody =
        "באפליקציה ניתן למלא שאלונים וכלים טיפוליים שהמטפל/ת שולח/ת אליך. המידע שתזין/י נשמר לצורך השימוש בשירות והצגתו למטפל/ת שלך."

    static let inviteConsentEmergencyHeading = "לא מיועד למצבי חירום"

    static let inviteConsentEmergencyBody =
        "CBTipul אינו שירות חירום ואינו תחליף לקבלת עזרה מיידית. במקרה של מצוקה חריפה או סכנה מיידית יש לפנות לגורם חירום או לקבלת עזרה מקצועית מתאימה."

    static let inviteConsentAcceptance =
        "קראתי ואני מסכים/ה לתנאי השימוש ולמדיניות הפרטיות, ומסכים/ה לחיבור החשבון למטפל/ת שהזמין/ה אותי."

    static let inviteConsentAcceptAction = "מסכים/ה וממשיך/ה"

    static let inviteConsentBackAction = "חזרה"

    static let inviteConsentAcceptedValue = "מסומן"

    static let inviteConsentNotAcceptedValue = "לא מסומן"

    static let patientActivationConnecting = "מתחברים ל-CBTipul…"

    static let patientActivationFailedTitle = "לא ניתן היה להשלים את החיבור"

    static let patientActivationSignInFailedBody = "לא ניתן היה להתחבר. נסו שוב."

    static let patientActivationClaimFailed =
        "לא ניתן היה לשייך את ההזמנה. נסו שוב או בקשו הזמנה חדשה מהמטפל/ת."

    static let patientActivationContextFailedBody =
        "ההזמנה שויכה, אך לא ניתן היה לאמת את החיבור. נסו שוב."

    static let patientActivationRetryAction = "ניסיון חוזר"

    static let patientModeConnectedTitle = "החיבור הושלם בהצלחה"

    static let patientModeConnectedBody =
        "כעת ניתן לקבל מהמטפל/ת שאלונים וכלים טיפוליים."

    static let patientTasksTitle = "המשימות שלי"

    static let patientTasksRefreshAction = "רענון"

    static let patientTasksEmptyTitle = "אין משימות חדשות כרגע"

    static let patientTasksEmptyBody =
        "משימות חדשות מהמטפל/ת שלך יופיעו כאן."

    static let patientQuestionnaireCardTitle = "שאלון GAD-7 ו-PHQ-9"

    static let patientQuestionnaireCardBody =
        "המטפל/ת ביקש/ה ממך למלא שאלון."

    static let patientQuestionnaireStartAction = "התחלת שאלון"

    static let patientUpcomingTaskTitle = "משימה מהמטפל/ת"

    static let patientUpcomingTaskBody = "משימה זו תהיה זמינה בקרוב."

    static let patientDiaryOneCardTitle = "יומן 1"

    static let patientDiaryOneCardBody =
        "רישום של אירוע, מחשבה, רגשות והתגובה שלך."

    static let patientDiaryOneOngoingHint = "אפשר להוסיף רשומות בכל עת."

    static let patientDiaryOneSaveAction = "שמירת הרשומה"

    static let patientDiaryOneSaved = "הרשומה נשמרה"

    static let patientDiaryOneSubmitting = "שומרים את הרשומה…"

    static let patientDiaryOneSubmitError = "לא ניתן היה לשמור את הרשומה. נסו שוב."

    static let patientDiaryOneNotActiveTitle = "היומן אינו פעיל"

    static let patientDiaryOneNotActive = "היומן אינו פעיל יותר."

    static let patientTasksLoadError = "לא ניתן היה לטעון את המשימות. נסו שוב."

    static let patientQuestionnaireSubmitAction = "שליחה"

    static let patientQuestionnaireSubmittedTitle = "השאלון נשלח בהצלחה"

    static let patientQuestionnaireSubmitting = "שולחים…"

    static let patientQuestionnaireSubmitError =
        "לא ניתן היה לשלוח את השאלון. נסו שוב."

    static let patientQuestionnaireCancelledError =
        "המשימה בוטלה, ולכן לא ניתן לשלוח את השאלון."

    static let patientQuestionnaireAccessDeniedError =
        "לא ניתן לשלוח את השאלון כרגע."

    static let patientLeaveModeAction = "יציאה ממצב מטופל/ת"

    static let patientLeaveModeConfirmTitle = "יציאה ממצב מטופל/ת?"

    static let patientLeaveModeConfirmMessage =
        "לאחר היציאה יהיה צורך בהזמנה חדשה מהמטפל/ת כדי להתחבר שוב למצב מטופל/ת במכשיר זה."

    static let patientLeaveModeConfirmAction = "יציאה"

    static let patientLeaveModeFailed =
        "לא ניתן היה לצאת ממצב מטופל/ת. נסו שוב."

    static let patientActivationIncompleteTitle = "החיבור עדיין לא הושלם"

    static let patientActivationIncompleteBody =
        "לא ניתן להיכנס למסך ההתחברות של מטפלים. פתחו מחדש את קישור ההזמנה או נסו לאמת את החיבור שוב."

    static let patientContextRetryTitle = "לא ניתן היה לאמת את החיבור"

    static let patientContextRetryBody =
        "נסו שוב לאמת את החיבור. אין צורך לפתוח מחדש את קישור ההזמנה."

    static let inviteExpiredTitle = "ההזמנה פגה"

    static let inviteExpiredBody = "יש לבקש מהמטפל/ת הזמנה חדשה."

    static let inviteClaimedTitle = "ההזמנה כבר נוצלה"

    static let inviteClaimedBody =
        "יש לבקש מהמטפל/ת הזמנה חדשה אם יש צורך בחיבור מחדש."

    static let inviteCancelledTitle = "ההזמנה אינה פעילה"

    static let inviteCancelledBody = "יש לבקש מהמטפל/ת הזמנה חדשה."

    static let inviteInvalidTitle = "הקישור אינו תקין"

    static let invitePreviewLoadFailedTitle = "לא ניתן היה לטעון את ההזמנה"

    static let deleteAccountAction = "מחיקת חשבון"

    static let deleteAccountConfirmTitle = "למחוק את החשבון?"

    static let deleteAccountConfirmMessage =
        "מחיקת החשבון וכל המידע שלו — מטופלים, פגישות, שאלונים והערות — תהיה לצמיתות. לא ניתן לבטל פעולה זו."

    static let deleteAccountFailedTitle = "מחיקת החשבון נכשלה"

    static let settingsAccessibilitySectionTitle = "נגישות"
    
    static let settingsTextSizeTitle = "גודל טקסט"
    
    static let settingsTextSizeSmall = "קטן"
    
    static let settingsTextSizeStandard = "רגיל"
    
    static let settingsTextSizeLarge = "גדול"
    
    static let settingsTextSizeExtraLarge = "גדול מאוד"
    
    static let settingsTextSizeHuge = "ענק"
    
    // MARK: - Session editor
    
    static let discardChangesTitle =
    "קיימים שינויים שלא נשמרו. מחיקת השינויים תגרום לאובדן המידע."
    
    static let discardChangesAction = "מחיקת השינויים"
    
    static let saveChangesAction = "שמירה"
    
    static let keepEditingAction = "המשך עריכה"
    
    static let discardRecordingAction = "מחיקת ההקלטה"
    
    static let playRecordingAction = "הפעלת ההקלטה"
    
    static let stopPlaybackAction = "עצירת ההשמעה"
    
    // MARK: - Questionnaire history
    
    static let viewQuestionnairesAction = "שאלונים וגרפים"

    static let diaryOneTitle = "יומן 1"

    static let diaryOneAddEntryAction = "הוספת רשומה"
    static let emptyDiaryOnePrimaryAction = "הוספת רשומה ראשונה"

    static let diaryOneSaveEntryAction = "שמירת רשומה"

    static let diaryOneEventTitle = "האירוע"

    static let diaryOneEventQuestion = "מה קרה?"

    static let diaryOneThoughtTitle = "מחשבה"

    static let diaryOneThoughtQuestion = "איזו מחשבה עברה לי בראש?"

    static let diaryOneFeelingTitle = "רגשות"

    static let diaryOneFeelingQuestion = "אילו רגשות הרגשתי?"

    static let diaryOneFeelingIntensityTitle = "עוצמת הרגש"

    static let diaryOneBehaviourTitle = "התנהגות"

    static let diaryOneBehaviourQuestion = "איך הגבתי?"

    static let diaryOnePhysicalSymptomsTitle = "תחושות גופניות"

    static let diaryOnePhysicalSymptomsQuestion = "האם הרגש לווה בתחושות גופניות?"

    static let diaryOneEmptyTitle = "אין רשומות ביומן 1 עדיין"

    static let diaryOneEmptyBody = "הוסיפו רשומה כדי לתעד אירוע, מחשבה ורגשות."

    static let diaryOneIntensityUnset = "לא נבחרה"

    static func diaryOneIntensityValue(_ value: Int) -> String {
        "\(value)%"
    }

    static func diaryFeelingsPreview(_ feelings: [DiaryFeeling]) -> String {
        let visible = feelings.prefix(3).map { "\($0.name) \($0.intensity)%" }
        var text = visible.joined(separator: " · ")
        if feelings.count > 3 {
            text += " · \(diaryFeelingsMoreCount(feelings.count - 3))"
        }
        return text
    }

    static func diaryFeelingsMoreCount(_ count: Int) -> String {
        "+\(count)"
    }

    static let diaryFeelingsTitle = "רגשות"

    static let diaryFeelingPickTitle = "בחירת רגש"

    static let diaryAddFeelingAction = "הוספת רגש"

    static let diaryOtherFeelingAction = "רגש אחר"

    static let diaryRemoveFeelingAction = "הסרת רגש"

    static let diaryFeelingSearchPrompt = "חיפוש רגש"

    static let diaryFeelingSearchEmpty = "לא נמצאו רגשות מתאימים"

    static let diaryCustomFeelingPlaceholder = "שם הרגש"

    static let diaryCustomFeelingConfirmAction = "הוספה"

    static let diaryCustomFeelingEmpty = "יש להזין שם לרגש."

    static let diaryFeelingAlreadySelected = "הרגש הזה כבר נבחר."

    static let diaryOneValidationTitle = "הרשומה אינה שלמה"

    static let diaryOneValidationMessage =
        "יש למלא אירוע, מחשבה והתנהגות, לבחור לפחות רגש אחד, ולבחור עוצמה לכל רגש."

    static let diaryOneValidationEvent = "יש למלא את האירוע."

    static let diaryOneValidationThought = "יש למלא את המחשבה."

    static let diaryOneValidationFeelingsRequired = "יש לבחור לפחות רגש אחד."

    static let diaryOneValidationFeelingName = "יש לבחור רגש."

    static func diaryOneValidationFeelingIntensity(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "יש לבחור עוצמה לכל רגש."
        }
        return "יש לבחור עוצמה עבור \(trimmed)."
    }

    static let diaryOneValidationBehaviour = "יש למלא את ההתנהגות."

    static let diaryOneOptionalHint = "לא חובה"

    static let diaryOneSaveFailed = "לא ניתן היה לשמור את הרשומה. נסו שוב."

    static let diaryOneLoadFailed = "לא ניתן היה לטעון את יומן 1. נסו שוב."

    static let diaryOneDeleteAction = "מחיקת רשומה"

    static let diaryOneDeleteConfirmTitle = "למחוק את הרשומה?"

    static let diaryOneDeleteConfirmMessage =
        "הרשומה תימחק מיומן 1 ולא ניתן יהיה לשחזר אותה."

    static let diaryOneDeleteFailed = "לא ניתן היה למחוק את הרשומה. נסו שוב."
    
    static let questionnairesTitle = "שאלוני מצב רוח"
    
    static let modePickerTitle = "תצוגה"
    
    static let listModeTitle = "רשימה"
    
    static let graphsModeTitle = "גרפים"
    
    static let noQuestionnairesMessage = "אין שאלונים עדיין"
    
    static let loadErrorTitle = "טעינת השאלונים נכשלה"
    
    static let retryAction = "ניסיון נוסף"
    
    static let metricPickerTitle = "הצגת"
    
    static let totalOptionLabel = "ציון כולל"
    
    static let chartDateLabel = "תאריך"
    
    static let chartScoreLabel = "ציון"
    
    /// Short per-question names shown in the graph metric picker,
    /// indexed like the question arrays.
    static let gad7QuestionShortNames: [String] = [
        "עצבות/חרדה/מתח",
        "חוסר שליטה בדאגה",
        "דאגה מוגזמת",
        "קושי להירגע",
        "חוסר מנוחה",
        "עצבנות/התרגשות",
        "פחד מאסון",
    ]
    
    static let phq9QuestionShortNames: [String] = [
        "אובדן עניין/הנאה",
        "מצב רוח ירוד",
        "קשיי שינה",
        "עייפות/חוסר אנרגיה",
        "תיאבון מועט/מוגבר",
        "ערך עצמי נמוך",
        "קושי בריכוז",
        "איטיות / אי-שקט",
        "מחשבות על פגיעה עצמית",
    ]
    
    /// Short names used in compact rows next to scores.
    static let gad7ShortName = "GAD-7"
    
    static let phq9ShortName = "PHQ-9"
    
    static let questionnaireSectionTitle = "שאלון"

    static let sendQuestionnaireToPatientAction = "שליחת שאלון למטופל/ת"

    static let patientNotConnectedTitle = "המטופל/ת עדיין לא מחובר/ת ל-CBTipul"

    static let patientNotConnectedBody =
        "יש להזמין את המטופל/ת ולחבר/ה ל-CBTipul לפני שניתן לשלוח שאלון."

    static let questionnaireSentToPatient = "השאלון נשלח למטופל/ת"

    static let questionnaireAwaitingPatient = "ממתין למילוי על ידי המטופל/ת"

    static let patientConnectionCheckError =
        "לא ניתן היה לבדוק את חיבור המטופל/ת. נסו שוב."

    static let diaryPatientModeTitle = "יומן למטופל/ת"

    static let diaryPatientModeNotConnected = "מצב מטופל/ת אינו מחובר"

    static let diaryPatientModeInactiveBody =
        "אפשר לאפשר למטופל/ת למלא את היומן באופן שוטף."

    static let diaryPatientModeActivateAction = "הפעלת יומן למטופל/ת"

    static let diaryPatientModeActive = "היומן פעיל אצל המטופל/ת"

    static let diaryPatientModeStopAction = "הפסקת היומן למטופל/ת"

    static let diaryPatientModeStopConfirmTitle = "להפסיק את היומן למטופל/ת?"

    static let diaryPatientModeStopConfirmMessage =
        "המטופל/ת לא יוכל/תוכל להוסיף רשומות חדשות ליומן עד להפעלה מחדש. הרשומות הקיימות יישמרו."

    static let diaryPatientModeStopConfirmAction = "הפסקת היומן"

    static let diaryPatientModeActivateFailed = "לא ניתן היה להפעיל את היומן. נסו שוב."

    static let diaryPatientModeStopFailed = "לא ניתן היה להפסיק את היומן. נסו שוב."

    static let questionnaireAssignmentSendError =
        "לא ניתן היה לשלוח את השאלון. נסו שוב."

    static let questionnaireAssignmentRetryAction = "ניסיון חוזר"
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
        case .firstPhoneCall: return "שיחת טלפון ראשונית"
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
        "קודם, \(dateText)"
    }
    static let noQuestionnaireForSession = "אין שאלונים לפגישה זו"
    
    // MARK: - GAD-7
    
    static let gad7Title = "GAD-7 שאלון לאבחון חרדה מוכללת"
    static let gad7MainQuestion =
    "במהלך השבוע האחרון עד כמה היית מוטרד/ת מהנושאים הבאים?"
    
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
    "במהלך השבוע האחרון באיזו תדירות היית מוטרד/ת מכל אחת מן הבעיות הבאות?"
    
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
        case .minimal: return "דיכאון מינימלי"
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
        case .mild: return "כדאי לשקול טיפול עפ״י דיווח הסימפטומים של המטופל/ת ועפ״י התפקוד הכללי"
        case .moderate: return "כדאי לשקול טיפול עפ״י דיווח הסימפטומים של המטופל/ת ועפ״י התפקוד הכללי"
        case .moderatelySevere: return "מומלץ טיפול בדיכאון בתרופות, פסיכותרפיה או שילוב שלהם"
        case .severe: return "מומלץ טיפול בדיכאון בתרופות, פסיכותרפיה או שילוב שלהם"
        }
    }
    
    // MARK: - Session analysis
    
    static let sessionSummaryTitle = "סיכום פגישה AI מובנה"
    
    static let sessionSummaryPlaceholder = "סיכום פגישה"
    
    static let keySituationsSection = "מצבים מרכזיים"
    
    static let possibleAutomaticThoughtsSection = "מחשבות אוטומטיות אפשריות"
    
    static let cbtCycleSection = "מחזור CBT"
    
    /// Questions for the therapist — information missing from the notes
    /// worth clarifying, not questions to ask the patient.
    static let questionsToRevisitSection = "שאלות שכדאי להבהיר"
    
    static let assignmentsForNextWeekSection = "משימות לשבוע הבא"
    
    static let assignmentsToCheckSection = "משימות לבדיקה"
    
    static let saveSummaryPrompt = "לשמור את הסיכום בפגישה?"
    
    static let dontSaveAction = "לא לשמור"
    
    static let keepViewingAction = "להמשיך לצפות"
    
    static let thoughtLabel = "מחשבה"
    
    static let situationLabel = "מצב"
    
    static let emotionLabel = "רגש"
    
    static let behaviorLabel = "התנהגות"
    
    static let patientSaidBadge = "דברי המטופל/ת"
    
    static let possibleInferenceBadge = "מסקנה אפשרית"
    
    // MARK: - NAT source labels
    
    static let sourceExplicitPatient = "נאמר במפורש על ידי המטופל/ת"
    
    static let sourceTherapistReported = "דווח על ידי המטפל/ת"
    
    static let sourceTherapistInferred = "השערת המטפל/ת"
    
    static let sourceAIInferred = "השערת AI"
    
    static let possibleCognitivePatternsLabel = "דפוסי חשיבה אפשריים"
    
    // MARK: - Cognitive pattern confidence
    
    static let confidenceHigh = "ודאות גבוהה"
    
    static let confidenceMedium = "ודאות בינונית"
    
    static let confidenceLow = "ודאות נמוכה"
    
    static let questionPlaceholder = "שאלה"
    
    static let whyItMattersLabel = "למה זה חשוב"
    
    static let reasonPlaceholder = "סיבה"
    
    static let discussedAction = "נדון"
    
    static let followUpAction = "למעקב"
    
    static let notRelevantAction = "לא רלוונטי"
    
    static let therapistHypothesesSection = "השערות המטפל/ת"
    
    static let evidenceLabel = "ראיות"
    
    // MARK: - Session preparation
    
    static let sessionPreparationTitle = "הכנה לפגישה הבאה"
    
    static let preparationOutdatedMessage =
    "לא מעודכן — התקיימה פגישה מאז הכנת ההכנה."
    
    static let recurringNatsSection = "💭 מחשבות אוטומטיות שליליות חוזרות"
    
    static let maintenanceCyclesSection = "🔄 מחזורי שימור אפשריים"
    
    static let maintenanceCyclesSubtitle =
    "השערות AI — מנגנונים שכדאי לבדוק, לא עובדות"
    
    static let questionnaireInsightsSection = "📊 תובנות מהשאלונים"
    
    static let priorityFollowUpsSection = "🔎 נושאים בעדיפות להמשך"
    
    static let treatmentFocusSection = "🎯 מוקד טיפול אפשרי"
    
    static let treatmentFocusSubtitle =
    "תחומים שכדאי לשקול — לא הנחיות"
    
    static let suggestedQuestionsSection = "❓ שאלות מוצעות"
    
    static let aiDisclaimer =
    "תמיכה קלינית שנוצרה באמצעות AI. יש להפעיל שיקול דעת מקצועי."
    
    static func tokensUsed(_ count: Int) -> String {
        "אסימונים בשימוש: \(count)"
    }
    
    static func sourceLine(_ source: String) -> String {
        "מקור: \(source)"
    }
    
    static let situationsLabel = "מצבים"
    
    static let possibleThinkingPatternsLabel = "דפוסי חשיבה אפשריים"
    
    static let possibleMaintenanceCycleLabel = "מחזור שימור אפשרי"
    
    static let automaticThoughtLabel = "מחשבה אוטומטית"
    
    static let shortTermConsequenceLabel = "השלכה בטווח הקצר"
    
    static let longTermConsequenceLabel = "השלכה בטווח הארוך"
    
    static let possibleCoreBeliefSection = "אמונת ליבה אפשרית"
    
    static let coreBeliefSubtitle =
    "השערת AI — כדאי לדון ולבדוק, לא להניח שהיא נכונה"
    
    static let hypothesisBadge = "השערה"
    
    static let priorityHigh = "גבוהה"
    
    static let priorityMedium = "בינונית"
    
    static let priorityLow = "נמוכה"
    
    static func confidenceLine(_ value: String) -> String {
        "רמת ביטחון: \(value)"
    }
    
    /// A bulleted list line.
    static func bulleted(_ text: String) -> String {
        "• \(text)"
    }
    
    // MARK: - My formulation
    
    static let treatmentGoalSection = "מטרת הטיפול"
    
    static let noTreatmentGoalPlaceholder =
    "לא הוגדרה מטרת טיפול — הוספת מטרה"
    
    static let goalFormatWarning =
    "הפורמט הרצוי: „להפחית את רמת רגש ה-X מ-Y% ל-Z% במצבים של…”"
    
    static let coreBeliefSection = "🧠 אמונת ליבה"
    
    static let noCoreBeliefPlaceholder = "לא הוגדרה אמונת ליבה"
    
    static let keyAutomaticThoughtsSection = "💭 מחשבות אוטומטיות מרכזיות"
    
    static let addThoughtAction = "הוספת מחשבה"
    
    static let maintainingBehaviorsSection = "🔄 התנהגויות משמרות"
    
    static let addBehaviorAction = "הוספת התנהגות"
    
    static let keyCBTCycleSection = "🔁 מחזור CBT מרכזי"
    
    static let removeCycleAction = "הסרת מחזור"
    
    static let noKeyCBTCycleLabel = "לא הוגדר מחזור CBT מרכזי"
    
    static let addCBTCycleAction = "הוספת מחזור CBT"
    
    static let therapistHypothesisSection = "🧩 השערת המטפל/ת"
    
    static let therapistHypothesisPlaceholder =
    "השערת העבודה לגבי הגורמים המשמרים את הבעיה"
    
    static let automaticThoughtTitle = "מחשבה אוטומטית"
    
    static let challengeFormulationAction = "אתגור הניסוח שלי"
    
    static let analyzingFormulationLabel = "ניתוח הניסוח…"
    
    static let addFormulationContentHint =
    "כדאי להוסיף מידע לניסוח לפני בקשת אתגור מה-AI."
    
    static let whatAmIMissingAction = "מה חסר לי?"
    
    static let lookingAcrossHistoryLabel =
    "בחינת ההיסטוריה של המטופל/ת…"
    
    static let aiSupervisionSection = "🧠 הדרכת AI"
    
    static let aiSupervisionFooter =
    "ה-AI בוחן את הניסוח ואת ההיסטוריה של המטופל/ת. הוא אינו משנה את הניסוח."
    
    static let longitudinalReviewAction = "סקירה לאורך זמן"
    
    static let analyzingOverTimeLabel = "ניתוח התהליך לאורך זמן…"
    
    static let longitudinalCaseReviewTitle = "📈 סקירת המקרה לאורך זמן"
    
    static let longitudinalReviewFooter =
    "תמונה לאורך זמן: מה השתנה, מה נשאר ומה דורש תשומת לב."
    // MARK: - Supervision (Challenge My Formulation)
    
    static let aiGeneratedSupervisionLabel = "הדרכה מבוססת AI"

    static let supervisionDisclaimerBody = "אלו השערות לצורך חשיבה קלינית, ולא מסקנות מבוססות."

    static let supportsFormulationSection = "✓ מה תומך בפורמולציה?"

    static let mayNotFitSection = "⚠ מה עשוי שלא להתאים?"

    static let mayNotFitSubtitle = "מידע שעשוי שלא להתאים באופן מלא לפורמולציה הנוכחית — נקודה לשיקול, לא מסקנה"

    static let alternativeFormulationsSection = "🔄 פורמולציות חלופיות"

    static let alternativeFormulationsSubtitle = "אפשרויות נוספות לשקול — לא אבחנות או מסקנות"

    static let questionsToExploreSection = "❓ שאלות שכדאי לבחון"

    static let treatmentImplicationsSection = "🎯 השלכות אפשריות לטיפול"

    static let treatmentImplicationsSubtitle = "כיוונים אפשריים לשקול — לא הנחיות"

    static let possibleBlindSpotsSection = "👁 נקודות עיוורון אפשריות"

    static let blindSpotsSubtitle = "השערות, לא עובדות — היבטים שייתכן שאינם מקבלים ביטוי בפורמולציה"

    static let possibleFormulationLabel = "פורמולציה אפשרית"

    static let whatThisMightExplainLabel = "מה זה עשוי להסביר"

    static func purposeLine(_ purpose: String) -> String {
        "מטרה: \(purpose)"
    }

    static let possibleAreaToConsiderLabel = "כיוון אפשרי לשקול"

    // MARK: - Supervision (What Am I Missing?)

    static let whatAmIMissingTitle = "🔎 מה אולי חסר לי?"

    static let noAdditionalPatternsMessage = "לא זוהו דפוסים משמעותיים נוספים על סמך המידע הקיים."

    static let whyThisMightMatterLabel = "למה זה עשוי להיות משמעותי"

    static let questionForTherapistLabel = "שאלה למטפל/ת"

    static let categoryRecurringNat = "מחשבה אוטומטית חוזרת"

    static let categoryCognitivePattern = "דפוס חשיבה"

    static let categoryMaintainingBehavior = "התנהגות משמרת"

    static let categoryDiscrepancy = "פער אפשרי"

    static let categoryPersistentSymptom = "תסמין מתמשך"

    static let categoryRepeatedSituation = "מצב חוזר"

    static let categoryUnexploredTheme = "נושא אפשרי שטרם נבחן"

    static let categoryPossibleConnection = "קשר אפשרי"

    static let categoryTreatmentOpportunity = "הזדמנות טיפולית אפשרית"

    static let categoryRiskReview = "בחינת סיכון"

    // MARK: - Supervision (Longitudinal Case Review)

    static let highConfidenceLabel = "ודאות גבוהה"

    static let mediumConfidenceLabel = "ודאות בינונית"

    static let lowConfidenceLabel = "ודאות נמוכה"

    static let improvementsSection = "✅ שיפורים"

    static let persistentDifficultiesSection = "⚠️ קשיים מתמשכים"

    static let persistentDifficultiesSubtitle = "היבטים שעדיין לא נראה בהם שינוי מספק"

    static let recurringPatternsSection = "🔄 דפוסים חוזרים"

    static let recurringPatternsSubtitle = "דפוסים שחוזרים לאורך הטיפול"

    static let importantChangesSection = "🔀 שינויים משמעותיים"

    static let treatmentGoalProgressSection = "🎯 התקדמות לעבר מטרת הטיפול"

    static let formulationEvolutionSection = "🧠 התפתחות הפורמולציה"

    static let formulationEvolutionSubtitle = "מה מתחיל להתבהר? השערות ופרשנויות, לא עובדות מבוססות"

    static let worthAttentionSection = "👀 נקודות שכדאי לשים לב אליהן"

    static let worthAttentionSubtitle = "כיוונים שאולי כדאי לבחון — לא הנחיות"

    static let overallTrajectorySection = "📈 מגמה כללית"

    static let insufficientLongitudinalDataMessage = "אין מספיק מידע לאורך זמן כדי להסיק מסקנות נוספות בשלב זה."

    static let whatImprovedLabel = "מה השתפר"

    static let possibleInterpretationHebrewLabel = "פרשנות אפשרית"

    static let whyWeThinkSoLabel = "מה תומך בפרשנות הזו"

    static let possibleInterpretationLabel = "פרשנות אפשרית"

    static let currentEstimateLabel = "הערכה נוכחית"

    static let possibleNextStepLabel = "צעד אפשרי להמשך"

    static let questionsForTherapistSection = "❓ שאלות למטפל/ת"

    static let questionsForTherapistSubtitle = "לחשיבה במסגרת ההדרכה — אין צורך בתשובה מחייבת"

    static let goalStatusProgressing = "בתהליך התקדמות"

    static let goalStatusPartiallyProgressing = "התקדמות חלקית"

    static let goalStatusUnchanged = "ללא שינוי"

    static let goalStatusWorsening = "החמרה"

    static let goalStatusAchieved = "הושגה"

    static let goalStatusUnclear = "לא ברור"
    
    // MARK: - Errors
    
    static func transcriptionFailed(_ message: String) -> String {
        "התמלול נכשל: \(message)"
    }
    
    static func couldNotReadAudioFile(_ description: String) -> String {
        "לא ניתן לקרוא את קובץ השמע: \(description)"
    }
    
    static let sessionAnalysisFailedError = "ניתוח הפגישה נכשל"
    
    static let invalidInputError = "הקלט אינו תקין."
    
    static let invalidServerResponseError = "התקבלה תגובה לא תקינה מהשרת."
    
    static let emptyAIResponseError = "שירות ה-AI החזיר תגובה ריקה."
    
    static let supabaseNotConfiguredError = "Supabase אינו מוגדר. יש להזין את כתובת הפרויקט ואת מפתח ה-anon בקובץ SupabaseConfig.swift."
    
    static func notImplementedError(_ feature: String) -> String {
        "\(feature) עדיין לא זמין."
    }
    
    static let patientNotSavedError = "המטופל/ת עדיין לא נשמר/ה במסד הנתונים."
    
    static let sessionNotSavedError = "הפגישה עדיין לא נשמרה במסד הנתונים."
    
    static let updateRejectedError = "השרת קיבל את הבקשה, אך לא בוצע שינוי. יש לבדוק את מדיניות אבטחת השורות (RLS) של הטבלה — ייתכן שחסרה הרשאת UPDATE."
    
    // MARK: - Anonymization
    
    static let anonymizationFailedError = "לא ניתן היה להסיר פרטים מזהים ולכן המידע לא נשמר. אפשר לנסות שוב."
    
    static let anonymizingStatusLabel = "הסרת פרטים מזהים…"
}
