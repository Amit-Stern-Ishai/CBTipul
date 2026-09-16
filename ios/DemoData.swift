import Foundation
import OSLog

/// Local-only sample clinic used for the first-run app tour.
///
/// Edit names, notes, scores and summaries here — nothing is uploaded to
/// Supabase while demo mode is active.
enum DemoData {
    static let idPrefix = "demo-"
    /// Bundled sample patients for browsing. Checklist “add / edit” steps
    /// look at user-created demo patients instead, so the tour isn’t
    /// marked done just from the seed clinic.
    static let showcaseIDValues: Set<String> = ["demo-1", "demo-2", "demo-3"]

    static func isDemoID(_ id: DatabaseID) -> Bool {
        if case .text(let value) = id {
            return value.hasPrefix(idPrefix)
        }
        return false
    }

    static func isShowcaseID(_ id: DatabaseID) -> Bool {
        if case .text(let value) = id {
            return showcaseIDValues.contains(value)
        }
        return false
    }

    /// A patient the therapist added while touring (counts for checklist).
    static func isTutorialPatientID(_ id: DatabaseID) -> Bool {
        isDemoID(id) && !isShowcaseID(id)
    }

    static func makeTutorialPatientID() -> DatabaseID {
        .text("demo-user-\(UUID().uuidString)")
    }

    struct Bundle {
        let patients: [Patient]
        let questionnairesByPatient: [DatabaseID: [CompletedQuestionnaire]]
        let preparationsByPatient: [DatabaseID: WhisperService.PrepareSessionResponse]
    }

    /// Session protocol order shared by all showcase patients.
    private static let showcaseSessionTypes: [SessionType] = [
        .intake, .intake, .psychoEducation,
        .diaryOne, .diaryOne, .diaryTwo, .diaryTwo,
    ]

    @MainActor
    static func makeBundle() -> Bundle {
        let calendar = Calendar.current
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: .now)) ?? .now
        }
        /// Weekly spacing: session 1 oldest → session 7 today.
        func sessionDate(_ index1Based: Int) -> Date {
            daysAgo((7 - index1Based) * 7)
        }

        // MARK: - demo-1 ישראלה ישראלית — social anxiety

        let p1ID = DatabaseID.text("demo-1")
        let p1Notes = [
            // 1 intake — background + goals only
            """
            ישראלה מספרת על קושי מתמשך לדבר מול בעלי סמכות ובפני קהל בעבודה. התסכול בסיטואציות האלה מגיע לכ־90%, ומלווה בהימנעות (דילוג על ישיבות, העברת מצגות לאחרים). רקע: כמה שנים של דחיית דיבורים חשובים מחשש לביקורת. מטרת טיפול ראשונית שעליה הסכמנו: הורדת התסכול ל־50% באותן סיטואציות.
            """,
            // 2 intake — more background + clarify goal
            """
            העמקנו ברקע: מיילים למנהלת נדחים ימים, ובפגישות היא שותקת גם כשיש לה מה לומר. תיארה פחד ש"יראו שאינה יודעת" ובושה אחרי דיבורים. אין היסטוריה של טיפול CBT קודם. חידדנו את המטרה: לא להעלים חרדה לגמרי, אלא להוריד תסכול מ־90% ל־50% ולאפשר דיבור מול סמכות וקהל.
            """,
            // 3 psychoeducation — CBT explanation
            """
            הסבר על טיפול CBT: קשר בין מצב, מחשבה אוטומטית, רגש, תחושה בגוף והתנהגות. הראינו איך הימנעות מורידה חרדה לטווח קצר ומחזקת אותה לטווח ארוך. הצגנו שיומני מחשבות ישמשו לאיסוף דוגמאות מהשבוע. משימה: לשים לב השבוע למצבים מול סמכות/קהל בלי לשנות עדיין התנהגות.
            """,
            // 4 diary 1 — event, thought, emotion+intensity, response, body
            """
            מילוי יומן 1: אירוע — זימון לישיבה עם המנהלת. מחשבה — "אגיד משהו טיפשי והיא תחשוב שאני לא מקצועית". רגש — תסכול וחרדה בעוצמה 85. תגובה — ביקשה מעמית להציג במקומה. תחושה פיזית — דופק מהיר, לחץ בחזה ויובש בפה.
            """,
            // 5 diary 1
            """
            מילוי יומן 1: אירוע — עדכון קצר במעגל צוות. מחשבה — "כולם רואים שאני רועדת". רגש — בושה ותסכול בעוצמה 70 (נמוך מהשבוע הקודם). תגובה — דיברה משפט אחד ואז שתקה. תחושה פיזית — רעד קל בידיים וחום בפנים. ציינה שנשימה הייתה קצת יותר קלה מאשר בישיבות קודמות.
            """,
            // 6 diary 2 — + alternative thought + thinking error
            """
            מילוי יומן 2: אירוע — הצגת סטטוס מול שלושה עמיתים. מחשבה — "הם בטוח חושבים שאני מבולבלת". רגש — חרדה 65. מחשבה חלופית — "אולי הם מקשיבים לתוכן ולא שופטים אותי". טעות חשיבה — קריאת מחשבות (מנחשת שאחרים חושבים עליה לרעה בלי ראיות).
            """,
            // 7 diary 2
            """
            מילוי יומן 2: אירוע — שאלה למנהלת בישיבה. מחשבה — "אם אטעה — הכול אבוד". רגש — תסכול 55. מחשבה חלופית — "טעות נקודתית לא מוחקת את כל העבודה שלי". טעות חשיבה — הכל או כלום (רואה הצלחה מול כישלון בלי גוונים). דיווחה שהתסכול בסוף האירוע ירד לכ־45.
            """,
        ]
        let p1Sessions = makeSessions(
            patientKey: "demo-1",
            notes: p1Notes,
            date: sessionDate
        )
        let patient1 = Patient(
            id: p1ID,
            firstName: "ישראלה",
            lastName: "ישראלית",
            status: .active,
            notes: "חרדה חברתית מול סמכות וקהל. מטרה: תסכול 90%→50%. עובדת על הימנעות, מחשבות אוטומטיות וחשיפות מדורגות.",
            sessions: p1Sessions
        )
        patient1.localName = "ישראלה ישראלית"
        patient1.formulation = PatientFormulation(
            treatmentGoal: "הורדת רמת התסכול מ־90% ל־50% בסיטואציות של חרדה חברתית (סמכות / קהל)",
            coreBelief: "אני לא ראויה להישמע / יראו שאני לא מספיק טובה",
            keyAutomaticThoughts: [
                "יראו שאני לא יודעת",
                "אגיד משהו טיפשי",
                "המנהלת תחשוב שאני לא מקצועית",
            ],
            maintainingBehaviors: [
                "הימנעות מישיבות ומעבר מצגות לאחרים",
                "דחיינות במיילים לבעלי סמכות",
                "בדיקות יתר של ניסוחים לפני שליחה",
            ],
            keyCBTCycle: nil,
            therapistHypothesis: "מעגל הימנעות חברתית מוזן מקריאת מחשבות ופחד מהערכה שלילית; חשיפה מדורגת + אתגור מחשבות מפחיתים תסכול לאורך זמן."
        )

        // GAD-led rocky improvement; PHQ stays mild.
        let p1Questionnaires = makeQuestionnaires(
            patientKey: "demo-1",
            sessionIDs: p1Sessions.compactMap(\.databaseID),
            date: sessionDate,
            gad7Series: [
                [2, 3, 2, 3, 2, 2, 2], // s2 ~16
                [2, 2, 2, 3, 2, 2, 2], // s3 ~15
                [3, 2, 2, 2, 2, 2, 2], // s4 rocky bump ~15
                [2, 2, 2, 2, 1, 2, 1], // s5 ~12
                [2, 1, 2, 2, 1, 1, 1], // s6 ~10
                [1, 2, 1, 2, 1, 1, 1], // s7 ~9
            ],
            phq9Series: [
                [1, 1, 1, 1, 0, 1, 0, 0, 0],
                [1, 1, 0, 1, 0, 1, 0, 0, 0],
                [1, 1, 1, 1, 0, 1, 0, 0, 0],
                [1, 0, 1, 1, 0, 0, 0, 0, 0],
                [0, 1, 0, 1, 0, 0, 0, 0, 0],
                [0, 1, 0, 1, 0, 0, 0, 0, 0],
            ],
            interference: [2, 2, 2, 1, 1, 1]
        )

        // MARK: - demo-2 אדם אדמוני — health anxiety

        let p2ID = DatabaseID.text("demo-2")
        let p2Notes = [
            // 1 intake
            """
            אדם מתאר חרדת בריאות שנמשכת כחמש שנים. הפחד התחיל אחרי שבר קרסול בזמן ריצה, ומאז כל תחושה בגוף מתפרשת כסכנה. עוצמת הפחד בסיטואציות מפעילות מגיעה לכ־85%. מטרה ראשונית שהגדרנו יחד: הורדת עוצמת הפחד ל־40% באותן סיטואציות.
            """,
            // 2 intake
            """
            רקע נוסף: בדיקות גוגל יומיות, מדידות דופק חוזרות, ולעיתים פניות לרופא גם אחרי בדיקות תקינות. נמנע מריצה וממאמץ משמעותי מאז השבר. אין אבחנה רפואית פעילה שמסבירה את הפחד הנוכחי. חידדנו מטרה: להפחית פחד מ־85% ל־40% ולאפשר חזרה הדרגתית לפעילות בלי בדיקות ביטחון קבועות.
            """,
            // 3 psychoeducation
            """
            הסבר על CBT בחרדת בריאות: תחושה גופנית → פרשנות מאיימת → חרדה → בדיקת ביטחון/הימנעות → חיזוק הפחד. הדגשנו שהבדיקות מורידות חרדה רגעית ומשמרות אותה. הצגנו יומן ככלי להפריד בין עובדה (תחושה) לפרשנות. משימה: לשים לב לתחושות אחרי מאמץ קל בלי לשנות עדיין הרגלים.
            """,
            // 4 diary 1
            """
            מילוי יומן 1: אירוע — עליית מדרגות בדרך לעבודה. מחשבה — "הדופק הזה הוא סימן לבעיית לב". רגש — פחד בעוצמה 80. תגובה — עצר, מדד דופק בטלפון וחיפש תסמינים בגוגל. תחושה פיזית — דופק מהיר, הזעה קלה ולחץ בחזה.
            """,
            // 5 diary 1
            """
            מילוי יומן 1: אירוע — הליכה מהירה בפארק. מחשבה — "אם משהו יקרה — אף אחד לא יעזור בזמן". רגש — פחד 70, עם רגע של הקלה באמצע. תגובה — המשיך ללכת בלי מד דופק כ־10 דקות ואז בדק פעם אחת. תחושה פיזית — נשימה כבדה בהתחלה שהתמתנה בהמשך.
            """,
            // 6 diary 2
            """
            מילוי יומן 2: אירוע — כאב שריר בשוק אחרי הליכה. מחשבה — "בטוח שזה קריש / משהו מסוכן". רגש — פחד 75. מחשבה חלופית — "אחרי מאמץ כאב שריר נפוץ ובדרך כלל חולף". טעות חשיבה — ראיית העתיד (רואה שחורות ומניח שהדברים יתפתחו לרעה).
            """,
            // 7 diary 2
            """
            מילוי יומן 2: אירוע — ריצה קלה במסלול מוכר. מחשבה — "אני מרגיש בסכנה — כנראה באמת קורה משהו רע". רגש — פחד שיא 55, בסוף כ־40. מחשבה חלופית — "תחושת סכנה היא חרדה, לא הוכחה רפואית". טעות חשיבה — טיעון רגשי (מסיק מסקנות מהרגש במקום מעובדות).
            """,
        ]
        let p2Sessions = makeSessions(
            patientKey: "demo-2",
            notes: p2Notes,
            date: sessionDate
        )
        let patient2 = Patient(
            id: p2ID,
            firstName: "אדם",
            lastName: "אדמוני",
            status: .active,
            notes: "חרדת בריאות ~5 שנים מאז שבר קרסול בריצה. מטרה: פחד 85%→40%. ERP עדין, צמצום בדיקות ביטחון וחזרה לפעילות.",
            sessions: p2Sessions
        )
        patient2.localName = "אדם אדמוני"
        patient2.formulation = PatientFormulation(
            treatmentGoal: "הורדת עוצמת הפחד מ־85% ל־40% בסיטואציות של חרדת בריאות",
            coreBelief: "הגוף שלי שביר — משהו חמור מתפספס",
            keyAutomaticThoughts: [
                "זה הלב / מחלה חמורה",
                "פספסו ממצא בבדיקות",
                "אם לא אבדוק עכשיו יהיה מאוחר",
            ],
            maintainingBehaviors: [
                "מדידת דופק ובדיקות גוף חוזרות",
                "חיפושי גוגל רפואיים",
                "הימנעות מריצה וממאמץ",
            ],
            keyCBTCycle: nil,
            therapistHypothesis: "חרדת בריאות מתוחזקת ע״י בדיקות ביטחון והימנעות ממאמץ מאז טראומת השבר; חשיפה עם מניעת תגובה מפחיתה את הפחד."
        )

        let p2Questionnaires = makeQuestionnaires(
            patientKey: "demo-2",
            sessionIDs: p2Sessions.compactMap(\.databaseID),
            date: sessionDate,
            gad7Series: [
                [3, 3, 2, 3, 2, 2, 3], // ~18
                [3, 2, 2, 3, 2, 2, 2], // ~16
                [2, 3, 2, 2, 2, 2, 2], // rocky ~15
                [2, 2, 2, 2, 2, 1, 2], // ~13
                [2, 2, 1, 2, 1, 1, 2], // ~11
                [1, 2, 1, 2, 1, 1, 1], // ~9
            ],
            phq9Series: [
                [1, 1, 2, 1, 1, 1, 1, 0, 0],
                [1, 1, 1, 1, 1, 1, 0, 0, 0],
                [1, 1, 2, 1, 1, 1, 0, 0, 0],
                [1, 0, 1, 1, 1, 0, 0, 0, 0],
                [0, 1, 1, 1, 0, 0, 0, 0, 0],
                [0, 0, 1, 1, 0, 0, 0, 0, 0],
            ],
            interference: [2, 2, 2, 2, 1, 1]
        )

        // MARK: - demo-3 ברכה ברכיה — mild depression after move

        let p3ID = DatabaseID.text("demo-3")
        let p3Notes = [
            // 1 intake
            """
            ברכה מתארת דכאון קל מאז מעבר דירה — ייאוש בערבים עד כ־100%. מספרת על ירידה בהנאה, קושי להתחיל משימות, וריחוק מחברות מהשכונה הישנה. הדירה החדשה עדיין לא מרגישה כמו בית. מטרה ראשונית: הורדת תחושת הייאוש ל־50%.
            """,
            // 2 intake
            """
            רקע: המעבר היה לפני כחודשיים, בלי רשת תמיכה מקומית. מתארת בידוד בערבים ודחיינות בסידור הבית. אין אפיזודה דיכאונית חמורה בעבר; השינוי קשור במעבר. חידדנו מטרה: ייאוש מ־100% ל־50%, לצד חזרה לפעילויות קטנות ותחושת שייכות במקום החדש.
            """,
            // 3 psychoeducation
            """
            הסבר על CBT בדכאון: מחשבות שליליות וחוסר פעילות מזינים זה את זה במעגל. הצגנו כיצד שינוי התנהגות קטן יכול להשפיע על מצב הרוח גם לפני שחוזר "החשק". יומנים ישמשו לתפוס אירועים ומחשבות מהשבוע. משימה: לשים לב לערבים הקשים בלי לדרוש מעצמה שינוי גדול עדיין.
            """,
            // 4 diary 1
            """
            מילוי יומן 1: אירוע — ניסיון לסדר קרטונים בסלון. מחשבה — "אין טעם, זה לא ייגמר לעולם". רגש — ייאוש בעוצמה 90. תגובה — הפסיקה אחרי דקות ועברה למסך. תחושה פיזית — כבדות בגוף ועייפות חזקה.
            """,
            // 5 diary 1
            """
            מילוי יומן 1: אירוע — סיבוב קצר בבניין החדש. מחשבה — "אף אחד פה לא יהיה חבר אמיתי". רגש — עצב וייאוש 75. תגובה — חייכה לשכנה ואז חזרה מהר לדירה. תחושה פיזית — לחץ בגרון ודמעות קרובות. ציינה שהיציאה בכל זאת הרגישה קצת פחות כבדה מהשבוע שעבר.
            """,
            // 6 diary 2
            """
            מילוי יומן 2: אירוע — דירה מבולגנת בערב אחרי יום עבודה. מחשבה — "אני כישלון מוחלט שלא מצליחה לבנות בית". רגש — ייאוש 80. מחשבה חלופית — "מעבר הוא תהליך; עשיתי כבר כמה צעדים קטנים". טעות חשיבה — שימוש בתוויות (במקום "עשיתי מעט היום" אומרת "אני כישלון").
            """,
            // 7 diary 2
            """
            מילוי יומן 2: אירוע — שיחה עם חברה מהעיר הקודמת ואז ערב בבית קפה קרוב. מחשבה — "בלי הסביבה הישנה אני לבד לתמיד". רגש — ייאוש שיא 60, בסוף כ־50. מחשבה חלופית — "אפשר לבנות קשרים חדשים לאט, כמו שהיו פעם". טעות חשיבה — הכללה (אירוע של בדידות זמנית נראה כדפוס קבוע שלא ישתנה).
            """,
        ]
        let p3Sessions = makeSessions(
            patientKey: "demo-3",
            notes: p3Notes,
            date: sessionDate
        )
        let patient3 = Patient(
            id: p3ID,
            firstName: "ברכה",
            lastName: "ברכיה",
            status: .active,
            notes: "דכאון קל אחרי מעבר דירה. מטרה: ייאוש 100%→50%. הפעלה התנהגותית, שבירת הימנעות ובניית שייכות במקום החדש.",
            sessions: p3Sessions
        )
        patient3.localName = "ברכה ברכיה"
        patient3.formulation = PatientFormulation(
            treatmentGoal: "הורדת רמת הייאוש מ־100% ל־50% מתחושת הדכאון אחרי מעבר הדירה",
            coreBelief: "בלי הסביבה הישנה אני לבד / לא אצליח לבנות בית",
            keyAutomaticThoughts: [
                "לעולם לא ארגיש בבית",
                "אין טעם להתחיל לסדר",
                "אני לא מצליחה לבנות חיים מחדש",
            ],
            maintainingBehaviors: [
                "הימנעות מסידור הדירה",
                "צמצום קשרים חברתיים",
                "בידוד בערבים מול מסך",
            ],
            keyCBTCycle: nil,
            therapistHypothesis: "מעגל הימנעות אחרי אובדן הקשר הישן משמר דכאון קל; הפעלה התנהגותית ובניית שייכות מקומית מפחיתים ייאוש."
        )

        // PHQ-led rocky improvement; GAD milder.
        let p3Questionnaires = makeQuestionnaires(
            patientKey: "demo-3",
            sessionIDs: p3Sessions.compactMap(\.databaseID),
            date: sessionDate,
            gad7Series: [
                [2, 1, 2, 1, 1, 1, 1],
                [1, 2, 1, 1, 1, 1, 1],
                [2, 1, 2, 1, 1, 1, 0],
                [1, 1, 1, 1, 1, 0, 1],
                [1, 1, 1, 0, 1, 0, 0],
                [1, 0, 1, 1, 0, 0, 0],
            ],
            phq9Series: [
                [2, 3, 2, 2, 2, 2, 1, 1, 0], // ~15
                [2, 2, 2, 2, 2, 2, 1, 1, 0], // ~14
                [2, 3, 2, 2, 1, 2, 1, 1, 0], // rocky ~14
                [2, 2, 1, 2, 1, 1, 1, 0, 0], // ~10
                [1, 2, 1, 2, 1, 1, 1, 0, 0], // ~9
                [1, 1, 1, 1, 1, 1, 0, 0, 0], // ~6
            ],
            interference: [3, 2, 2, 2, 1, 1]
        )

        return Bundle(
            patients: [patient1, patient2, patient3],
            questionnairesByPatient: [
                p1ID: p1Questionnaires,
                p2ID: p2Questionnaires,
                p3ID: p3Questionnaires,
            ],
            preparationsByPatient: [:]
        )
    }

    // MARK: - Helpers

    private static func makeSessions(
        patientKey: String,
        notes: [String],
        date: (Int) -> Date
    ) -> [Session] {
        zip(showcaseSessionTypes.indices, showcaseSessionTypes).map { offset, type in
            let n = offset + 1
            return Session(
                databaseID: .text("\(patientKey)-s\(n)"),
                date: date(n),
                notes: notes[offset].trimmingCharacters(in: .whitespacesAndNewlines),
                type: type
            )
        }
    }

    /// Questionnaires for sessions 2…7 (none on the first intake).
    private static func makeQuestionnaires(
        patientKey: String,
        sessionIDs: [DatabaseID],
        date: (Int) -> Date,
        gad7Series: [[Int]],
        phq9Series: [[Int]],
        interference: [Int]
    ) -> [CompletedQuestionnaire] {
        // sessionIDs[0] = s1 (no questionnaire); [1...] = s2...s7
        let paired = zip(gad7Series.indices, zip(gad7Series, zip(phq9Series, interference)))
        return paired.map { index, triple in
            let (gad7, rest) = triple
            let (phq9, interferenceLevel) = rest
            let sessionNumber = index + 2 // s2...s7
            return completedQuestionnaire(
                id: .text("\(patientKey)-q\(index + 1)"),
                sessionID: sessionIDs[sessionNumber - 1],
                date: date(sessionNumber),
                gad7: gad7,
                phq9: phq9,
                interferenceLevel: interferenceLevel
            )
        }
        // Newest-first matches existing demo ordering habits in the UI cache.
        .reversed()
    }

    private static func completedQuestionnaire(
        id: DatabaseID,
        sessionID: DatabaseID,
        date: Date,
        gad7: [Int],
        phq9: [Int],
        interferenceLevel: Int
    ) -> CompletedQuestionnaire {
        var q = CombinedMoodQuestionnaire()
        q.gad7Answers = gad7.map { Optional($0) }
        q.phq9Answers = phq9.map { Optional($0) }
        q.interferenceLevel = interferenceLevel
        return CompletedQuestionnaire(
            databaseID: id,
            sessionID: sessionID,
            answeredDate: date,
            questionnaire: q
        )
    }
}
