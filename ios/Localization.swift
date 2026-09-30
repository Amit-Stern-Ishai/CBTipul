import Foundation

/// Central mapping of every user-facing string in the app.
///
/// The values are the app's existing wording, unchanged. Translate the
/// values in this one file — the rest of the app only ever references these
/// constants and never hard-codes user-facing wording.
enum L10n {
    static let diaryFivePartsOptional = "5 חלקים · החלק האחרון לבחירה"
    static let diaryEntryGuide = "ממלאים חלק אחד בכל פעם. אפשר לפתוח כל חלק כדי לעיין או לשנות."
    static func diaryEntryProgress(_ completed: Int, _ total: Int) -> String { "הושלמו \(completed) מתוך \(total) חלקים" }
    static let diarySectionNext = "לחלק הבא"
    static let diarySectionComplete = "הושלם"
    static let diarySectionOpen = "פתיחת החלק"
    static let diarySectionClose = "סגירת החלק"
    static let diaryReadyToSave = "הכול מוכן. בדקו את הפרטים ולחצו על שמירה."
    static let diaryOriginalThoughts = "המחשבות שכתבתי"
    static let diaryRemoveThoughtConfirm = "להסיר את המחשבה שכתבתם?"
    static let diaryRemoveThoughtAction = "הסרת המחשבה"
    static let diaryFeelingsPickerHint = "בחרו רגש כדי להוסיף אותו. אפשר להוסיף רגשות נוספים בהמשך."
    static let diaryRatingAdjust = "אפשר לגרור את המחוון כדי לדייק."

    static let diaryRatingChoose = "בחרו אחוזים. לאחר הבחירה אפשר לדייק בעזרת המחוון."
    static func diaryThoughtNumber(_ title: String, _ number: Int) -> String { "\(title) \u{2066}\(number)\u{2069}" }
    static func diaryRemoveThoughtNumber(_ title: String, _ number: Int) -> String { "הסרת \(diaryThoughtNumber(title, number))" }
    static let diaryAddAlternativeThought = "הוספת מחשבה חלופית"
    static let diaryChooseThinkingErrors = "בחירת טעויות חשיבה"
    static let diaryEditThinkingErrors = "שינוי הבחירה"
    static func diaryRemoveThinkingError(_ name: String) -> String { "הסרת \(name)" }
    static let diaryThinkingChoose = "אפשר לבחור כמה אפשרויות. להסבר לחצו על ⓘ."
    static let diaryEntryThoughtHint = "כתבו את המשפט שעבר בראש באותו רגע."
    static let diaryEntryAlternativeHint = "איזו דרך נוספת ומאוזנת יותר יש לראות את המצב?"
    static let diaryEntryFeelingsHint = "הוסיפו רגש ובחרו את עוצמתו. אפשר להוסיף כמה רגשות."
    static let diaryPreviousStep = "לשלב הקודם"
    static func diaryThinkingAbout(_ name: String) -> String { "הסבר על \(name)" }

    static let patientQuestionnaireInactiveHint = "אפשר לעיין במילויים הקודמים. למילוי חדש נדרשת הפעלה של המטפל/ת."
    static let questionnairesActive = "שאלונים פעילים"
    static let questionnairesStop = "הפסקת שאלונים"
    static let questionnairesStopExplanation = "המטופל/ת לא יוכל/תוכל לשלוח מילויים חדשים. כל התשובות הקודמות יישמרו."
    static let patientQuestionnaireHistory = "השאלונים שלי"
    static let patientQuestionnaireHistoryEmpty = "המילויים שלך יופיעו כאן לאחר השליחה."
    static let patientQuestionnaireHistoryError = "לא ניתן לטעון את השאלונים הקודמים כרגע. אפשר לנסות שוב. מילוי חדש עדיין זמין כשהגישה פעילה."
    static let patientQuestionnaireOpenAction = "פתיחת שאלונים"

    
    // MARK: - Sessions workspace

    static let pastSessionsSection = "פגישות קודמות"
    static let noUpcomingSessionsBody = "אין פגישות מתוכננות להיום או להמשך. אפשר לתאם פגישה חדשה באמצעות הכפתור למטה."
    static let noPastSessionsBody = "עדיין לא תועדו פגישות קודמות."
    static let sessionsSearchPrompt = "חיפוש לפי שם מטופל/ת"
    static let sessionsSearchEmpty = "לא נמצאו פגישות למטופל/ת בשם הזה"
    static func sessionsMonthSection(_ section: String, month: String) -> String {
        "\(section) · \(month)"
    }

    // MARK: - Drafts and form completion

    static let deviceDraftSaved = "טיוטה נשמרה במכשיר הזה בלבד. היא עדיין לא נשלחה."
    static let deviceDraftRestored = "הטיוטה הקודמת שוחזרה מהמכשיר הזה. היא עדיין לא נשלחה."
    static let deviceDraftSaveFailed = "הטיוטה לא נשמרה במכשיר. התוכן עדיין כאן — אפשר לנסות שוב לפני היציאה."
    static let deviceDraftRestoreFailed = "לא ניתן לשחזר את הטיוטה מהמכשיר כרגע."
    static let deviceDraftRemoveFailed = "לא ניתן למחוק את הטיוטה מהמכשיר כרגע. אפשר לנסות שוב."
    static let leaveDraftTitle = "לשמור את הטיוטה להמשך?"
    static let keepDraftAndLeave = "שמירת טיוטה ויציאה"
    static let discardDraftAction = "מחיקת הטיוטה ויציאה"
    static let unansweredQuestionLabel = "עדיין לא נענתה"
    static let nextUnansweredAction = "מעבר לשאלה הבאה שלא נענתה"
    static let questionnaireReadyToSend = "כל השאלות נענו. אפשר לבדוק את התשובות ולשלוח."
    static func questionnaireCompletion(_ answered: Int, total: Int) -> String {
        "נענו \(answered) מתוך \(total) שאלות"
    }
    static func messageCharacterCount(_ count: Int, maximum: Int) -> String {
        "\(count) מתוך \(maximum) תווים"
    }
    static let submittedDraftCleanup = "התוכן נשלח. יש למחוק את הטיוטה המקומית כדי לסיים. לחיצה על סיום לא תשלח שוב."
    static let messageSentDraftCleanup = "ההודעה נשלחה. יש למחוק את הטיוטה המקומית כדי לסיים. לחיצה על סיום לא תשלח שוב."

    // MARK: - Patient workspace

    static let editPatientDetailsAction = "עריכת פרטים"
    static let patientRecordsTitle = "התיק הטיפולי"
    static let patientSessionsDescription = "תיעוד ועיון בפגישות הטיפול"
    static func patientLatestSession(_ date: String) -> String { "פגישה אחרונה: \(date)" }
    static let patientQuestionnairesDescription = "עיון בתשובות קודמות ומילוי שאלון חדש"
    static let patientGraphsDescription = "מעקב אחר ציוני השאלונים לאורך זמן"
    static let questionnaireHistoryTitle = "היסטוריית שאלונים"
    static let emptyQuestionnaireGraphsTitle = "עדיין אין נתונים לגרפים"
    static let emptyQuestionnaireGraphsBody = "לאחר מילוי שאלונים, הציונים יוצגו כאן. למילוי שאלון חדש חזרו לתיק המטופל/ת ובחרו ״היסטוריית שאלונים״."
    static let patientDiariesTitle = "יומנים"
    static let patientDiariesDescription = "יומן 1, יומן 2, יומן 3"
    static let diaryTwoTitle = "יומן 2"
    static let diaryThreeTitle = "יומן 3"
    static let diaryComingSoon = "בקרוב"
    static let patientSendingDescription = "הודעה, הפעלת שאלונים או יומן"
    static let patientSendingUnavailableTitle = "השליחה אינה זמינה"
    static let patientSendingRequiresConnection = "אפשר לשלוח רק לאחר שהמטופל/ת יפתחו את קישור ההזמנה וישלימו את החיבור לאפליקציה."
    static let patientSendingUnavailableHere = "שליחה זמינה רק למטופל/ת מחובר/ת בתיק אמיתי. במצב הדגמה לא נשלחים תכנים."
    static let patientChooseSendAction = "שליחת הודעה או ניהול גישה לשאלונים וליומנים."
    static let patientSendMessageDescription = "כתבו הודעה ובדקו אותה לפני השליחה. ההודעה תופיע באפליקציית המטופל/ת."
    static let patientQuestionnaireRequestDescription = "גישה מתמשכת לשאלוני GAD-7 ו-PHQ-9. כל מילוי נשמר בנפרד בהיסטוריה, ללא שיוך לפגישה. אפשר להפסיק את הגישה בכל עת."
    static let patientEnableDiaryOneAction = "הפעלת יומן 1"
    static let patientSendDiaryOneDescription = "מאפשר למטופל/ת למלא יומן 1 באופן שוטף באפליקציה."
    static let patientDiaryDescription = "עיון ותיעוד של אירועים, מחשבות ורגשות"
    static let patientDiaryTwoDescription = "זיהוי טעויות חשיבה וניסוח מחשבות חלופיות"
    static let patientDiaryThreeDescription = "בחינת מחשבות והשוואת רגשות לפני ואחרי"
    static let patientMessagesDescription = "הודעות שנשלחו למטופל/ת ומצב הקריאה שלהן"
    static let patientNotesTitle = "הערות על המטופל/ת"
    static let patientNotesDescription = "רקע והערות כלליות שאינן שייכות לפגישה מסוימת"
    static let additionalAssistanceTitle = "תובנות והכנה לפגישה"
    static let patientAIAssistanceTitle = aiChatNavigationTitle
    static let patientAIAssistanceDescription = "שיחה עם עוזר בינה מלאכותית והמשגת המקרה"
    static let patientConnectTitle = "חיבור המטופל/ת לאפליקציה"
    static let patientInviteToAppAction = "הזמנה לאפליקציה"
    static let patientInvitationDemoStatus = "לא זמין במצב הדגמה"
    static let patientConnectDescription = "שליחת קישור הזמנה אישי מאפשרת למטופל/ת לקבל ממך הודעות ולמלא שאלונים ויומנים שהפעלת."
    static let patientShareInvitationAction = "שיתוף קישור הזמנה"
    static let patientReinviteAction = "שליחת הזמנה חדשה"
    static let patientReinviteExplanation = "אפשר לשלוח קישור חדש כדי להתחבר מחדש, למשל לאחר החלפת טלפון. החיבור הנוכחי יישאר פעיל עד לאישור ההזמנה החדשה, ואז יוחלף בחיבור החדש."
    static let patientShareInvitationExplanation = "בלחיצה ייפתחו אפשרויות שיתוף, למשל WhatsApp או דוא״ל. יש לבחור איך לשלוח את הקישור. החיבור יושלם רק לאחר שהמטופל/ת יפתחו אותו ויאשרו את ההצטרפות."
    static let patientConnectionOptionalExplanation = "ההזמנה אינה חובה. אפשר לתעד פגישות גם בלי לחבר את המטופל/ת לאפליקציה."
    static let patientConnectionReadyDescription = "לחצו על ״שליחה למטופל/ת״ כדי לבחור הודעה, הפעלת שאלונים או יומן."
    static let patientInvitationUnavailableExplanation = "הזמנה זמינה בתיק של מטופל/ת אמיתי/ת. במצב הדגמה לא נשלחות הזמנות."
    static let stopPatientNotesRecording = "עצירה ותמלול"

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

    /// Bottom-tab labels (shorter than some screen titles).
    static let therapistTabPatients = "מטופלים"
    static let therapistTabSessions = "פגישות"
    static let therapistTabNotifications = "התראות"
    static let therapistTabSettings = "הגדרות"

    static let globalSessionsPlaceholderTitle = "פגישות"
    static let globalSessionsPlaceholderBody =
        "כאן יופיעו הפגישות מכלל הקליניקה."
    static let notificationsPlaceholderTitle = "התראות"
    static let notificationsPlaceholderBody =
        "אין התראות כרגע."
    static let notificationsEmptyTitle = "אין התראות כרגע"
    static let notificationsEmptyBody = "עדכונים על שאלונים, יומנים וחיבור מטופלים יופיעו כאן."
    static let notificationsDemoBody = "במצב הדגמה לא מתקבלות התראות ממטופלים."
    static let notificationsRefreshFailed = "לא ניתן לעדכן כרגע. מוצגות ההתראות שנטענו קודם."
    static let notificationOpenQuestionnaires = "לשאלונים"
    static let notificationOpenDiary = "ליומן 1"
    static let notificationOpenPatient = "לתיק המטופל/ת"
    static let notificationQuestionnaireCompleted = "השאלון הושלם"
    static let notificationPatientConnected = "התחבר/ה ל-CBTipul"
    static let notificationDiaryTwoEntryAdded = "הוסיף/ה רשומה חדשה ליומן 2"
    static let notificationDiaryOneEntryAdded = "הוסיף/ה רשומה חדשה ליומן 1"
    static let notificationGenericTitle = "התראה"
    static let notificationGenericPatient = "מטופל/ת"
    static let notificationTargetUnavailable = "הפריט כבר אינו זמין"
    static let notificationUnreadAccessibility = "לא נקראה"
    static let notificationsUnreadSection = "לא נקראו"
    static let notificationsReadSection = "נקראו"
    static let notificationsLoadFailedTitle = "טעינת התראות נכשלה"

    /// Relative time for inbox rows (e.g. "היום, 14:32").
    static func notificationTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened,
                                                   locale: Locale(identifier: "he_IL")))
        if calendar.isDateInToday(date) {
            return "היום, \(time)"
        }
        if calendar.isDateInYesterday(date) {
            return "אתמול, \(time)"
        }
        return hebrewDateTime(date)
    }
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
    static let activePatientsSectionTitle = "מטופלים פעילים"
    static func patientListSection(_ title: String, count: Int) -> String { "\(title) (\(count))" }
    static func patientListNextSession(_ date: Date) -> String { "הפגישה הבאה: \(hebrewDate(date))" }
    static func patientListLastSession(_ date: Date) -> String { "פגישה אחרונה: \(hebrewDate(date))" }
    static let inactivePatientsSectionTitle = "מטופלים לא פעילים"
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
    static let saveSessionAction = "שמירת הפגישה"
    static let recordSessionNotesAction = "הקלטת סיכום הפגישה"
    static let sessionRecordingHelp = "אפשר להקליד או להקליט. בסיום ההקלטה, הדברים שאמרתם יהפכו לטקסט שאפשר לערוך."
    static let sessionNotesSaveHelp = "בסיום העריכה לחצו על ״שמירת הפגישה״."
    static let sessionOptionalDetails = "סוג פגישה (לא חובה)"
    static let sessionOptionalAI = "סיכום מובנה בעזרת AI"
    static let sessionAIHelp = "אפשר ליצור סיכום מובנה מהטקסט שכתבתם. מומלץ לקרוא ולבדוק אותו. אפשר גם לשמור את הפגישה בלי ליצור סיכום כזה."
    static let sessionPendingRecording = "ההקלטה עדיין לא נוספה לטקסט. כדי לשמור את הפגישה, נסו לתמלל שוב או מחקו את ההקלטה."
    static let sessionNotCreated = "הפגישה עדיין לא נשמרה"
    static let sessionNotSaved = "יש שינויים שטרם נשמרו"
    static let sessionSaved = "כל השינויים נשמרו"
    static let sessionRecordingInProgress = "מקליט… בסיום לחצו על ״עצירה ותמלול״"
    static let sessionSaving = "שומר את הפגישה…"
    static let sessionRecordingNeedsTranscription = "יש לתמלל או למחוק את ההקלטה לפני השמירה"
    static let sessionProcessing = "מעבד את הפגישה… יש להמתין לסיום"
    
    static let optionalNotesPlaceholder = "הערות (לא חובה)"
    static let sessionSummaryFieldPlaceholder = "כתבו או הקליטו את סיכום הפגישה"
    static let patientNotesFieldPlaceholder = "כתבו או הקליטו הערות על המטופל/ת"
    
    static let myFormulationTitle = "הניסוח שלי"
    
    static let prepareNextSessionAction = "הכנה לפגישה הבאה"
    
    static let lastPreparationAction = "ההכנה האחרונה"
    
    static let outdatedBadge = "לא מעודכן"

    // MARK: - Getting Started / first-run

    static let introductionReview = "היכרות עם האפליקציה"
    static let introductionSkip = "דילוג"
    static let introductionNext = "הבא"
    static let introductionStart = "התחלה עם המטופלים שלי"
    static let introductionReturn = "חזרה לאפליקציה"
    static let introductionSampleAction = "התנסות עם נתונים לדוגמה"
    static let introductionPatientTitle = "כל התמונה, בתיק אחד"
    static let introductionPatientBody = "מטרת הטיפול, הפגישות, השאלונים וההערות — מרוכזים בתיק של כל מטופל/ת."
    static let introductionSessionTitle = "מתעדים בדרך שנוחה לכם"
    static let introductionSessionBody = "כתבו או הקליטו סיכום פגישה. כלי AI יכולים לעזור בניסוח ובהכנה לפגישה הבאה — אתם בודקים ומחליטים."
    static let introductionConnectTitle = "הטיפול ממשיך בין הפגישות"
    static let introductionConnectBody = "הזמינו מטופלים להתחבר לאפליקציה. אחרי החיבור אפשר לשלוח הודעות ולהפעיל גישה לשאלונים וליומנים."
    static let introductionProgressTitle = "רואים מה משתנה לאורך הדרך"
    static let introductionProgressBody = "גרפים מרכזים את תוצאות השאלונים. בחרו מגמה ושאלה כדי לראות מה השתפר, מה החמיר ומה נשאר יציב."
    static let introductionSampleTitle = "קודם להכיר, אחר כך להתחיל"
    static let introductionSampleBody = "נסו את האפליקציה עם מטופלים בדויים ותיקים מוכנים. הנתונים האמיתיים נשארים בנפרד, ולא נשלח דבר למטופלים."
    static let introductionSampleHint = "אפשר לצאת בכל רגע דרך ״חזרה למטופלים שלי״, ולחזור להתנסות מההגדרות."
    static let introductionGoal = "מטרת הטיפול"
    static let introductionSessionNotes = "סיכום פגישה"
    static let introductionWrite = "כתיבה"
    static let introductionRecord = "הקלטה ותמלול"
    static let introductionAI = "עזרה בניסוח עם AI"
    static let introductionMessage = "הודעה"
    static let introductionQuestionnaire = "הפעלת שאלונים"
    static let introductionDiary = "יומן"
    static let introductionConnected = "לאחר חיבור המטופל/ת"
    static let introductionTrend = "מגמה לאורך זמן"
    static let introductionSampleBadge = "נתונים לדוגמה"
    static let introductionSamplePatient = "תיק לדוגמה"
    static func introductionPage(_ page: Int, total: Int) -> String {
        "מסך \(page) מתוך \(total)"
    }

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
    static let gettingStartedGuideSettingsTitle = "התנסות עם נתונים לדוגמה"
    static let gettingStartedGuideSettingsSubtitle =
        "הכירו את העבודה באפליקציה בלי להשתמש במידע של מטופלים אמיתיים."
    static let sampleDataExploreTitle = "תיקים מוכנים להתנסות"
    static let sampleDataExploreBody = "מטופלים בדויים עם פגישות ושאלונים לדוגמה. אפשר לעיין, לערוך ולהוסיף נתונים בחופשיות."
    static let sampleDataSeparateTitle = "בנפרד מהתיקים שלך"
    static let sampleDataSeparateBody = "התיקים האמיתיים נשארים ללא שינוי. לא נשלחות הודעות או הזמנות, ולא מופעלת גישה לשאלונים למטופלים."
    static let sampleDataReturnTitle = "חזרה בכל רגע"
    static let sampleDataReturnBody = "לחצו על ״חזרה למטופלים שלי״ בראש המסך. השינויים בנתוני הדוגמה יישמרו במכשיר להתנסות הבאה."
    static let sampleDataStartAction = "התחלת התנסות"
    static let sampleDataActiveTitle = "מצב נתונים לדוגמה פעיל"

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
        "בדקו את התאריך ולחצו על ״שמירת הפגישה״. אפשר להוסיף סיכום עכשיו או בהמשך."
    static let tutorialCoachHintOpenSession =
        "לחצו על הפגישה שיצרתם/ן"
    static let tutorialCoachHintFillQuestionnaire = "לחצו על ״מילוי שאלון כאן״"
    static let tutorialCoachHintCompleteQuestionnaire =
        "סמנו בחירה לכל שאלה, ולחצו על ״שמירה״ למעלה מצד שמאל."
    static let tutorialCoachHintRecordNotes =
        "הקלידו סיכום לדוגמה או לחצו על ״הקלטת סיכום הפגישה״. בסיום ההקלטה לחצו על ״עצירה ותמלול״."
    static let tutorialCoachHintAISummary = "לחצו על ״יצירת סיכום AI מובנה״"
    static let tutorialCoachHintReturnSessions = "חזרו למסך הפגישות כדי להמשיך"
    static let tutorialCoachHintFollowGlow = "עקבו אחרי הכפתור המסומן"

    static let demoModeBannerTitle = "נתונים לדוגמה"
    static let demoModeBannerBody = "קליניקה לדוגמה — לצורך המחשה בלבד."
    static let demoModeExitShort = "חזרה למטופלים שלי"
    static let exitDemoModeAction = "חזרה למטופלים שלי"
    static let enterDemoModeAction = "התנסות עם נתונים לדוגמה"

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
    static let emptyQuestionnairesTitle = "עדיין אין שאלונים שמולאו"
    static let emptyQuestionnairesBody =
        "כאן יופיעו התשובות לאחר מילוי שאלון חדש. אפשר למלא יחד עם המטופל/ת כאן. למילוי עצמאי באפליקציה, חזרו לתיק המטופל/ת ובחרו ״שליחה למטופל/ת״ ואז ״הפעלת שאלונים״."
    static let emptyQuestionnairesPrimaryAction = "הוספת שאלון"
    static let questionnaireAnsweredDateLabel = "תאריך השאלון"
    static let questionnaireSessionAssociationLabel = "שיוך לפגישה"
    static let questionnaireNoSessionAssociation = "ללא שיוך לפגישה"
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
    static let selectPatientTitle = "בחירת מטופל/ת"
    static let sessionChoosePatientPlaceholder = "בחרו מטופל/ת"
    static let sessionChoosePatientHelp = "יש לבחור למי שייכת הפגישה לפני השמירה."
    static let upcomingSessionsSection = "פגישות היום והבאות"
    static let recentSessionsSection = "אחרונות"
    static let createSessionAction = "יצירת פגישה"
    static let noUpcomingSessionsLabel = "אין פגישות קרובות"
    
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
    
    static let aiTitle = aiChatNavigationTitle
    
    static let aiAction = "שיחת AI"
    
    static let aiModePickerTitle = "מצב"
    
    static let aiModeInsights = "תובנות"
    
    static let aiModeQuestionnaires = "שאלונים"
    
    static let aiModeGeneral = "כללי"
    
    static let aiModeChat = "שיחה"
    
    static let aiSendAction = "שליחה"
    
    static let aiChatTitle = "שיחה"
    
    static let aiChatNavigationTitle = "שיחת AI על המטופל/ת"
    
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
    static let sendToPatientAction = "שליחה למטופל/ת"
    static let sendPatientMessageAction = "שליחת הודעה"
    static let messageRecipientLabel = "אל המטופל/ת"
    static func messageRecipient(_ name: String) -> String { "אל: \(name)" }
    static let therapistMessageDeliveryExplanation = "ההודעות מופיעות באפליקציית CBTipul של המטופל/ת. כרגע אי אפשר להשיב להן דרך האפליקציה."
    static let messageSendExplanation = "ההודעה תישלח רק לאחר לחיצה על ״שליחה״."
    static let writePatientMessageAction = "כתיבת הודעה למטופל/ת"
    static let sentMessagesTitle = "הודעות שנשלחו"
    static let sentMessageTitle = "הודעה שנשלחה"
    static let messagesLoading = "טוען הודעות…"
    static let therapistMessagesEmptyTitle = "עדיין לא נשלחו הודעות"
    static let therapistMessagesEmptyBody = "כאן יופיעו ההודעות ששלחתם למטופל/ת, ותוכלו לראות אם נקראו."
    static let sentMessageUnreadStatus = "נשלחה · טרם נקראה"
    static let sentMessageReadStatus = "נשלחה · נקראה"
    static let messageSentInApp = "ההודעה נשלחה וזמינה באפליקציית המטופל/ת."
    static func messageSentAt(_ date: Date) -> String { "נשלחה: \(notificationTimestamp(date))" }
    static let messagesRequireConnection = "כדי לשלוח הודעה, המטופל/ת צריכים לפתוח את קישור ההזמנה ולהתחבר ל-CBTipul."
    static let messagesReturnToPatient = "חזרה לתיק המטופל/ת להזמנה"
    static let messagesDemoUnavailable = "במצב הדגמה לא נשלחות הודעות למטופלים."
    static let messagesUnavailable = "לא ניתן לשלוח הודעות מתוך התיק הזה. חזרו לתיק המטופל/ת ובדקו את החיבור לאפליקציה."
    static let sendPatientMessagePlaceholder = "כתבו הודעה למטופל/ת..."
    static let sendMessageAction = "שליחה"
    static let sendPatientMessageSending = "שולחים הודעה..."
    static let sendPatientMessageSuccess = "ההודעה נשלחה"
    static let sendPatientMessageFailed = "לא ניתן היה לשלוח את ההודעה. נסו שוב."
    static let sendPatientMessageTooLong = "ההודעה ארוכה מדי."
    static let sendPatientMessageEmpty = "יש לכתוב הודעה לפני השליחה."
    static let sendPatientMessagePatientNotFound = "לא ניתן היה למצוא את המטופל/ת."
    static let messagesTitle = "הודעות"
    static let newMessageLabel = "הודעה חדשה"
    static let showMessageAction = "הצגת ההודעה"
    static let messageDetailTitle = "הודעה"
    static let messageFromTherapist = "הודעה מהמטפל/ת"
    static let messageNewBadge = "חדש"
    static let messageUnreadStatus = "לא נקראה"
    static let messageReadStatus = "נקראה"
    static let patientMessagesEmptyTitle = "אין הודעות"
    static let noNewMessagesTitle = "אין הודעות חדשות"
    static func moreUnreadMessages(_ count: Int) -> String {
        if count == 1 {
            return "ועוד הודעה אחת שלא נקראה"
        }
        return "ועוד \(count) הודעות שלא נקראו"
    }
    static let patientMessagesLoadFailedTitle = "טעינת הודעות נכשלה"
    static let patientMessagesCardBody = "הודעות מהמטפל/ת"
    static let patientMessagesOpenAction = "פתיחת הודעות"
    static let allMessagesAction = "כל ההודעות"
    static func allMessagesActionWithUnreadCount(_ count: Int) -> String {
        "\(allMessagesAction) (\(count))"
    }
    static func patientMessagesUnreadCount(_ count: Int) -> String {
        "\(count)"
    }
    static let progressAndTrackingSection = "מעקב והתקדמות"
    static let graphsAndTrendsTitle = "גרפים ומגמות"
    static let questionnairesHistoryAction = "שאלונים"
    static let treatmentCourseSection = "מהלך הטיפול"
    static let diariesTitle = "יומנים"
    static let clinicalToolsSection = "כלים קליניים"
    static let patientConnectedStatus = "מחובר/ת ל-CBTipul"
    static let patientNotConnectedStatus = "לא מחובר/ת ל-CBTipul"
    static let patientConnectionChecking = "בודק חיבור…"
    static let diaryOneSentToPatient = "יומן 1 הופעל אצל המטופל/ת."

    static let patientInvitationFailedTitle = "לא ניתן היה ליצור הזמנה"

    static let patientInvitationInvalidPatientError = "לא ניתן להזמין מטופל/ת זה/ו."

    static let patientInvitationShareSubject = "הזמנה להתחבר ל-CBTipul"

    static func patientInvitationShareMessage(therapistName: String, invitationUrl: String) -> String {
        """
        היי,

        \(therapistName) הזמין/ה אותך להתחבר ל-CBTipul.

        דרך האפליקציה ניתן למלא שאלונים ויומנים ולצפות בתכנים שנשלחו אליך כחלק מהטיפול.

        לפתיחת ההזמנה:
        \(invitationUrl)

        ההזמנה אישית ומיועדת עבורך בלבד.
        """
    }

    static func patientInvitationEmailHTML(therapistName: String, invitationUrl: String) -> String {
        func escape(_ value: String) -> String {
            value.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&#39;")
        }
        return """
        <!doctype html>
        <html lang="he" dir="rtl">
        <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
        <body dir="rtl" style="margin:0;padding:0;background-color:#f2f5f7;color:#172b43;font-family:Arial,Helvetica,sans-serif;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:#f2f5f7;">
        <tr><td align="center" style="padding:24px 12px;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:560px;background-color:#ffffff;border:1px solid #dfe6eb;border-radius:20px;">
        <tr><td dir="rtl" align="right" style="padding:24px;background-color:#172b43;border-radius:20px 20px 0 0;">
        <p dir="ltr" style="margin:0;text-align:right;color:#ffffff;font-size:24px;font-weight:bold;letter-spacing:0.3px;">CBTipul</p>
        <p style="margin:8px 0 0;color:#d8e4ed;font-size:14px;">הזמנה אישית מהמטפל/ת שלך</p>
        </td></tr>
        <tr><td dir="rtl" align="right" style="padding:28px 24px 24px;">
        <h1 style="margin:0 0 20px;color:#172b43;font-size:28px;line-height:1.4;">הטיפול ממשיך גם בין הפגישות</h1>
        <p style="margin:0 0 16px;font-size:17px;line-height:1.8;"><strong>\(escape(therapistName))</strong> הזמין/ה אותך להתחבר ל־<span dir="ltr">CBTipul</span>.</p>
        <p style="margin:0 0 20px;color:#46596c;font-size:16px;line-height:1.8;">באפליקציה אפשר למלא שאלונים, לתעד מחשבות ורגשות ביומנים ולקרוא הודעות מהמטפל/ת — בהתאם למה שנפתח עבורך.</p>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
        <tr><td align="center" bgcolor="#18766f" style="border-radius:12px;">
        <a href="\(escape(invitationUrl))" style="display:block;padding:16px 20px;border:1px solid #18766f;border-radius:12px;color:#ffffff;background-color:#18766f;font-size:18px;font-weight:bold;text-decoration:none;text-align:center;">פתיחת ההזמנה</a>
        </td></tr></table>
        <p style="margin:16px 0 0;color:#46596c;font-size:14px;line-height:1.8;">מומלץ לפתוח את ההזמנה בטלפון שבו תשתמשו באפליקציה. במסך שייפתח תוכלו לקרוא את פרטי החיבור ולאשר את ההצטרפות.</p>
        </td></tr>
        <tr><td dir="rtl" align="right" style="padding:20px 24px;border-top:1px solid #e5ebef;">
        <p style="margin:0 0 10px;color:#46596c;font-size:13px;line-height:1.7;">הכפתור לא נפתח? אפשר להעתיק את הקישור לדפדפן:</p>
        <p dir="ltr" style="margin:0;text-align:left;font-size:12px;line-height:1.8;word-break:break-all;overflow-wrap:anywhere;"><a href="\(escape(invitationUrl))" style="color:#176d68;text-decoration:underline;">\(escape(invitationUrl))</a></p>
        </td></tr>
        </table>
        <p dir="rtl" style="margin:16px 12px 0;color:#536578;font-size:12px;line-height:1.8;">ההזמנה אישית ומיועדת עבורך בלבד.</p>
        </td></tr></table>
        </body></html>
        """
    }

    static let invitePreviewTitle = "הוזמנת ל-CBTipul"

    static func invitePreviewTherapistLine(_ therapistDisplayName: String) -> String {
        "\(therapistDisplayName) הזמין/ה אותך להתחבר ל-CBTipul."
    }

    static let invitePreviewExplanation =
        "דרך האפליקציה ניתן למלא שאלונים ויומנים ולצפות בתכנים שנשלחו אליך כחלק מהטיפול."

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
        "באפליקציה ניתן למלא שאלונים וכלים טיפוליים שהמטפל/ת מפעיל/ה עבורך. המידע שתזין/י נשמר לצורך השימוש בשירות והצגתו למטפל/ת שלך."

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
        "כעת ניתן למלא שאלונים וכלים טיפוליים שהמטפל/ת יפעיל/תפעיל עבורך."

    static let patientTasksTitle = "למילוי ולתרגול"

    static let patientTasksRefreshAction = "רענון"

    static let patientTasksEmptyTitle = "אין כרגע שאלונים או יומנים למילוי"

    static let patientTasksEmptyBody =
        "שאלונים ויומנים מהמטפל/ת שלך יופיעו כאן כשיהיו זמינים."

    static let patientQuestionnaireCardTitle = "שאלונים"

    static let patientQuestionnaireCardBody =
        "כל עוד הגישה פעילה, אפשר למלא שאלון חדש בכל פעם. כל מילוי נשמר בנפרד ומשותף עם המטפל/ת."

    static let patientQuestionnaireStartAction = "מילוי שאלון חדש"

    static let patientUpcomingTaskTitle = "משימה מהמטפל/ת"

    static let patientUpcomingTaskBody = "משימה זו תהיה זמינה בקרוב."

    static let patientDiaryOneCardTitle = "יומן 1"
    static let patientDiaryOneStartAction = "פתיחת היומן"

    static let patientDiaryOneCardBody =
        "אפשר לתאר אירוע, את המחשבות והרגשות שעלו ואת התגובה שלך."

    static let patientDiaryOneOngoingHint = "היומן נשאר זמין. בכל פעם אפשר להוסיף אירוע חדש."

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
        "הגישה לשאלונים אינה פעילה. אפשר לעיין במילויים קודמים, אך לא לשלוח מילוי חדש."

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

    static let settingsNotificationsSectionTitle = "התראות"

    static let settingsNotificationsReceiveTitle = "קבלת התראות"

    static let settingsNotificationsTherapistExplanation =
        "קבלת עדכונים על פעילות של מטופלים/ות באפליקציה."

    static let settingsNotificationsPatientExplanation =
        "קבלת עדכונים על שאלונים, יומנים והודעות מהמטפל/ת."

    static let settingsNotificationsOpenSystemSettings = "פתיחת הגדרות"

    static let settingsNotificationsPermissionDeniedMessage =
        "כדי לקבל התראות, יש לאשר אותן בהגדרות המערכת."

    static let settingsNotificationsDisableFailed =
        "לא ניתן היה לכבות את ההתראות. נסו שוב."

    static let settingsNotificationsEnableFailed =
        "לא ניתן היה להפעיל את ההתראות. נסו שוב."

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

    static let diaryOneThoughtTitle = "מחשבות אוטומטיות"

    static let diaryOneThoughtSingularTitle = "מחשבה אוטומטית"

    static let diaryOneThoughtQuestion = "איזו מחשבה אוטומטית עברה לי בראש?"

    static let diaryOneAddThoughtAction = "הוספת מחשבה"

    static let diaryOneRemoveThoughtAction = "הסרת מחשבה"

    static let diaryOneMyEntriesTitle = "הרשומות שלי"

    static let diaryOneFeelingTitle = "רגשות"

    static let diaryOneFeelingQuestion = "אילו רגשות הרגשתי?"

    static let diaryOneFeelingIntensityTitle = "עוצמת הרגש"

    static let diaryOneBehaviourTitle = "התנהגות"

    static let diaryOneBehaviourQuestion = "איך הגבתי?"

    static let diaryOnePhysicalSymptomsTitle = "תחושות גופניות"

    static let diaryOnePhysicalSymptomsQuestion = "האם הרגש לווה בתחושות גופניות?"

    static let diaryOneEmptyTitle = "אין רשומות ביומן 1 עדיין"

    static let diaryOneEmptyBody = "הוסיפו רשומה כדי לתעד אירוע, מחשבות אוטומטיות ורגשות."

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

    static func diaryAutomaticThoughtsPreview(_ thoughts: [String]) -> String {
        guard let first = thoughts.first, !first.isEmpty else { return "" }
        if thoughts.count > 1 {
            return "\(first) · \(diaryFeelingsMoreCount(thoughts.count - 1))"
        }
        return first
    }

    static let diaryOneValidationMessage =
        "יש למלא אירוע, לפחות מחשבה אוטומטית אחת והתנהגות, לבחור לפחות רגש אחד, ולבחור עוצמה לכל רגש."

    static let diaryOneValidationEvent = "יש למלא את האירוע."

    static let diaryOneValidationThought = "יש למלא לפחות מחשבה אוטומטית אחת."

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
    
    static let gad7GraphTitle = "חרדה · GAD-7"
    static let phq9GraphTitle = "דיכאון · PHQ-9"
    static let questionTrendsTrendPicker = "מגמה"
    static let questionTrendsQuestionPicker = "שאלה"
    static let questionTrendsGraphTitle = "ציוני השאלה לאורך זמן"
    static let questionTrendsTitle = "מגמות לפי שאלה"
    static let questionTrendsHelp = "בחרו מגמה ואז שאלה מהרשימה. הגרף מציג את ציוני השאלה בכל השאלונים שמולאו. ציון נמוך יותר משקף שיפור."
    static let questionTrendsMissing = "נדרשות לפחות שתי תשובות לכל שאלה. תשובות חסרות אינן נחשבות לציון 0 ואינן נכללות בהשוואה."
    static let questionTrendImproving = "שיפור"
    static let questionTrendImprovingHelp = "הציון לא עלה באף מילוי, וירד לפחות פעם אחת."
    static let questionTrendWorsening = "החמרה"
    static let questionTrendWorseningHelp = "הציון לא ירד באף מילוי, ועלה לפחות פעם אחת."
    static let questionTrendUnchanged = "ללא שינוי"
    static let questionTrendUnchangedHelp = "אותו ציון בכל המילויים."
    static let questionTrendMixed = "מגמה מעורבת"
    static let questionTrendMixedHelp = "היו גם עליות וגם ירידות בציון."
    static let questionTrendInsufficient = "אין מספיק תשובות"
    static let questionTrendInsufficientHelp = "פחות משתי תשובות לשאלה."
    static let questionTrendsNoQuestions = "אין שאלות שמתאימות למגמה זו."
    static let questionTrendsMissingAnswer = "לא נענתה"
    static let questionnaireGraphSingleShort = "מילוי אחד"
    static let questionnaireGraphUnchangedShort = "ללא שינוי"
    static func questionTrendsOption(_ title: String, count: Int) -> String { "\(title)\u{00A0}(\u{2066}\(count)\u{2069})" }
    static func questionTrendsMatchingCount(_ count: Int) -> String { "שאלות: \(count)" }
    static func questionTrendsReference(_ scale: String, number: Int) -> String { "שאלה \(number) · \u{2066}\(scale)\u{2069}" }
    static func questionTrendsCount(_ count: Int) -> String { "\(count) שאלונים" }
    static func questionnaireGraphChangeShort(_ difference: Int) -> String {
        if difference == 0 { return questionnaireGraphUnchangedShort }
        return difference > 0 ? "עלייה של \(difference)" : "ירידה של \(-difference)"
    }
    static let questionnaireGraphHelp = "כל נקודה מייצגת מילוי שאלון. התאריכים מתקדמים משמאל לימין."
    static let questionnaireGraphSingleResponse = "מוצג מילוי אחד. לאחר מילוי נוסף יהיה אפשר לראות שינוי לאורך זמן."
    static let questionnaireGraphNoAnswers = "אין תשובות להצגה עבור הבחירה הזו."
    static func questionnaireGraphLatest(score: Int, maximum: Int) -> String {
        "ציון אחרון: \(score) מתוך \(maximum)"
    }
    static func questionnaireGraphChange(_ difference: Int) -> String {
        if difference == 0 { return "ללא שינוי לעומת המילוי הקודם" }
        return difference > 0
            ? "עלייה של \(difference) לעומת המילוי הקודם"
            : "ירידה של \(-difference) לעומת המילוי הקודם"
    }

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

    static let sendQuestionnaireToPatientAction = "הפעלת שאלונים"
    static let fillQuestionnaireHereAction = "מילוי שאלון כאן"
    static let questionnaireLocalEntryHelp = "התשובות שתמלאו כאן יישמרו בתיק. פעולה זו אינה מפעילה גישה באפליקציית המטופל/ת."
    static let questionnaireSessionEntryHelp = "מילוי כאן שומר את התשובות בתיק ומשייך אותן לפגישה הזו."
    static let questionnairePatientEntryHelp = "הפעלת גישה למילוי חוזר באפליקציית המטופל/ת. כל מילוי נשמר בנפרד בהיסטוריית השאלונים, ללא שיוך לפגישה."
    static let questionnaireCompletedLabel = "השאלון מולא — הצגת התשובות"
    static let questionnairePendingExplanation = "השאלונים פעילים באפליקציית המטופל/ת. כל מילוי נוסף יופיע בהיסטוריית השאלונים."
    static let questionnaireRefreshAction = "בדיקה אם התקבלו תשובות"
    static let questionnaireSendingLabel = "מפעילים גישה לשאלונים…"
    static let questionnaireDemoSendingUnavailable = "במצב הדגמה אפשר למלא שאלון כאן. הפעלת גישה למטופלים זמינה רק בתיקים אמיתיים."
    static let questionnaireRefreshFailed = "לא ניתן היה לעדכן את התשובות. מוצג המידע שנטען קודם."
    static let questionnaireStatusRefreshFailed = "לא ניתן היה לבדוק אם הגישה לשאלונים פעילה. נסו שוב."

    static let patientNotConnectedTitle = "המטופל/ת עדיין לא מחובר/ת ל-CBTipul"

    static let patientNotConnectedBody =
        "יש לשתף קישור הזמנה ולהשלים את חיבור המטופל/ת ל-CBTipul לפני שליחה."

    static let questionnaireSentToPatient = "הגישה לשאלונים הופעלה"

    static let questionnaireAwaitingPatient = "שאלונים פעילים"

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
        "לא ניתן היה לעדכן את הגישה לשאלונים. נסו שוב."

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

extension L10n {
    static let thinkingErrorTitles = ["הכל או כלום", "הכללה", "מסננת שלילית", "הקטנה בערך תכונות חיוביות", "קפיצה למסקנות", "קריאת מחשבות", "ראיית העתיד", "העצמה או הקטנה", "טיעון רגשי", "הצהרות של מה אמור/חייב/צריך/אסור שיהיה", "שימוש בתוויות", "האשמה עצמית או האשמת אחרים"]
    static let thinkingErrorExplanations = ["רואה הכל בשחור או לבן ללא גוונים.", "אירוע בודד נראה כדפוס קבוע שלא ישתנה לעולם.", "רואה את השלילי ומתעלם מהחיובי.", "מתעלם מהתכונות החיוביות שלך.", "קפיצה למסקנה חסרת בסיס.", "מנחש ומניח שאנשים חושבים עליך דברים רעים.", "רואה שחורות; מניח שדברים יתפתחו לרעה.", "מוציא דברים מפרופורציה או מקטין בחשיבותם.", "מסיק מסקנות על סמך רגשות ולא עובדות.", "שימוש במילים כמו אסור, חייב, מוכרח, צריך, אמור.", "במקום לומר \"עשיתי טעות\", אתה אומר \"אני דפוק\" או \"אפס\".", "מטיל את כל האחריות על עצמך או על אחרים, בלי להביא בחשבון גורמים נוספים."]
    static let diaryThinkingErrorsTitle = "טעויות חשיבה"
    static let diaryAlternativeThoughtsTitle = "מחשבות חלופיות"
    static let diaryAlternativeThoughtTitle = "מחשבה חלופית"
    static let diaryTwoValidationErrors = "יש לבחור לפחות טעות חשיבה אחת."
    static let diaryTwoValidationAlternatives = "יש למלא לפחות מחשבה חלופית אחת."
    static let diaryTwoEmptyTitle = "אין רשומות ביומן 2 עדיין"
    static let diaryTwoLoadFailed = "לא ניתן היה לטעון את יומן 2. נסו שוב."
    static let patientEnableDiaryTwoAction = "הפעלת יומן 2"
    static let patientSendDiaryTwoDescription = "מאפשר למטופל/ת למלא יומן 2 באופן שוטף באפליקציה."
    static let diaryTwoSentToPatient = "יומן 2 הופעל אצל המטופל/ת."
    static let diaryEntryTherapistSource = "תיעוד המטפל"
    static let diaryEntryPatientSource = "תיעוד המטופל"
    static let diaryEntryEdit = "עריכת רשומה"
}

extension L10n {
    static let diaryTwoFeelingsTitle = "רגשות ועוצמה"
    static let diaryTwoDuplicateThinkingError = "יש לבחור כל טעות חשיבה פעם אחת בלבד."
    static let patientDiaryTwoCardBody = "תיעוד אירוע, מחשבות אוטומטיות ורגשות, זיהוי טעויות חשיבה ובחינת מחשבות חלופיות."
    static let patientDiaryTwoNotActive = "המטפל/ת סגר/ה את יומן 2 למילוי. הרשומות שכבר נשמרו נשארות ביומן."
    static let patientDiaryTwoAccessDenied = "החיבור לתיק הטיפולי אינו זמין כרגע. יש לפנות למטפל/ת."
    static let patientDiaryTwoInvalidFeelings = "יש לבחור לפחות רגש אחד ועוצמה בין 0 ל־100 לכל רגש."
}


extension L10n {
    static let diaryThreeSituationTitle = "אירוע / מצב"
    static let diaryThreeBeliefBefore = "אמונה לפני"
    static let diaryThreeBeliefAfter = "אמונה אחרי"
    static let diaryThreeIntensityBefore = "עוצמה לפני"
    static let diaryThreeIntensityAfter = "עוצמה אחרי"
    static let diaryThreeBelief = "אחוז אמונה"
    static let diaryThreeFeelingsBefore = "רגשות ועוצמה לפני"
    static let diaryThreeThoughtsAfter = "הערכה מחדש של המחשבות האוטומטיות"
    static let diaryThreeFeelingsAfter = "רגשות ועוצמה אחרי"
    static let diaryThreeRemoveFeeling = "הסרת רגש"
    static let diaryThreeValidationSituation = "יש לתאר את האירוע או המצב."
    static let diaryThreeValidationRatings = "יש למלא את כל אחוזי האמונה ועוצמות הרגש לפני ואחרי, בין 0 ל־100."
    static let diaryThreeEmptyTitle = "אין רשומות ביומן 3 עדיין"
    static let diaryThreeLoadFailed = "לא ניתן היה לטעון את יומן 3. נסו שוב."
    static let patientEnableDiaryThreeAction = "הפעלת יומן 3"
    static let patientSendDiaryThreeDescription = "מאפשר למטופל/ת למלא יומן 3 באופן שוטף באפליקציה."
    static let diaryThreeSentToPatient = "יומן 3 הופעל אצל המטופל/ת."
}

extension L10n {
    static let diaryThreeSendingPaused = "שליחת יומן 3 אינה זמינה כרגע. ניתן לצפות ברשומות קודמות."
    static let patientDiaryThreeCardBody = "תרגול מונחה בשבעה שלבים: מחשבות ורגשות לפני, בחינת מחשבות חלופיות והערכה מחדש."
    static let patientDiaryThreeNotActive = "המטפל/ת סגר/ה את יומן 3 למילוי. הרשומות שכבר נשמרו נשארות ביומן."
    static let patientDiaryThreeBeliefNow = "אמונה עכשיו"
    static let patientDiaryThreeIntensityNow = "עוצמה עכשיו"
    static let patientDiaryThreeRateEveryItem = "יש לבחור דירוג בין 0 ל־100 לכל פריט בשלב זה."
    static let patientDiaryThreeStep1 = "מה קרה? תארו בקצרה את האירוע או המצב."
    static let patientDiaryThreeStep2 = "מה עבר בראש באותו רגע? דרגו עד כמה האמנתם בכל מחשבה, בין 0 ל־100."
    static let patientDiaryThreeStep3 = "בחרו את הרגשות שהיו באותו רגע ודרגו את עוצמתם לפני התרגול."
    static let patientDiaryThreeStep4 = "אילו טעויות חשיבה אפשר לזהות במחשבות שתיארתם?"
    static let patientDiaryThreeStep5 = "מהי דרך נוספת לראות את המצב? כתבו מחשבות חלופיות ודרגו עד כמה אתם מאמינים בהן."
    static let patientDiaryThreeStep6 = "חזרו למחשבות המקוריות. עד כמה אתם מאמינים בכל אחת עכשיו?"
    static let patientDiaryThreeStep7 = "איך אתם מרגישים עכשיו? דרגו שוב את אותם רגשות. לאחר השמירה הרשומה תישלח למטפל/ת ולא ניתן לערוך אותה."
    static func patientDiaryThreeProgress(_ step: Int) -> String { "שלב \(step) מתוך 7" }
    static let patientDiaryThreeStepHints = [patientDiaryThreeStep1, patientDiaryThreeStep2, patientDiaryThreeStep3, patientDiaryThreeStep4, patientDiaryThreeStep5, patientDiaryThreeStep6, patientDiaryThreeStep7]
}

extension L10n {
    static let notificationDiaryThreeEntryAdded = "הוסיף/ה רשומה חדשה ליומן 3"
}
