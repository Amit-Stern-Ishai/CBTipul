package com.cbtipul.app.data

import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.model.Patient
import com.cbtipul.app.model.PatientFormulation
import com.cbtipul.app.model.PatientStatus
import com.cbtipul.app.model.Session
import com.cbtipul.app.model.SessionType
import java.util.Calendar
import java.util.Date
import java.util.UUID

/** Local-only sample clinic used for the first-run app tour. */
object DemoData {
    const val ID_PREFIX = "demo-"
    val showcaseIdValues: Set<String> = setOf("demo-1", "demo-2", "demo-3")

    fun isDemoId(id: DatabaseId): Boolean =
        id is DatabaseId.Text && id.value.startsWith(ID_PREFIX)

    fun isShowcaseId(id: DatabaseId): Boolean =
        id is DatabaseId.Text && id.value in showcaseIdValues

    fun isTutorialPatientId(id: DatabaseId): Boolean =
        isDemoId(id) && !isShowcaseId(id)

    fun makeTutorialPatientId(): DatabaseId =
        DatabaseId.Text("demo-user-${UUID.randomUUID()}")

    data class Bundle(
        val patients: List<Patient>,
        val questionnairesByPatient: Map<DatabaseId, List<CompletedQuestionnaire>>,
    )

    private val showcaseSessionTypes = listOf(
        SessionType.Intake,
        SessionType.Intake,
        SessionType.PsychoEducation,
        SessionType.DiaryOne,
        SessionType.DiaryOne,
        SessionType.DiaryTwo,
        SessionType.DiaryTwo,
    )

    fun makeBundle(): Bundle {
        val calendar = Calendar.getInstance()
        fun daysAgo(days: Int): Date {
            val c = calendar.clone() as Calendar
            c.time = Date()
            c.set(Calendar.HOUR_OF_DAY, 0)
            c.set(Calendar.MINUTE, 0)
            c.set(Calendar.SECOND, 0)
            c.set(Calendar.MILLISECOND, 0)
            c.add(Calendar.DAY_OF_YEAR, -days)
            return c.time
        }
        fun sessionDate(index1Based: Int): Date = daysAgo((7 - index1Based) * 7)

        val p1Id = DatabaseId.Text("demo-1")
        val p1Notes = listOf(
            """
            ישראלה מספרת על קושי מתמשך לדבר מול בעלי סמכות ובפני קהל בעבודה. התסכול בסיטואציות האלה מגיע לכ־90%, ומלווה בהימנעות (דילוג על ישיבות, העברת מצגות לאחרים). רקע: כמה שנים של דחיית דיבורים חשובים מחשש לביקורת. מטרת טיפול ראשונית שעליה הסכמנו: הורדת התסכול ל־50% באותן סיטואציות.
            """.trimIndent(),
            """
            העמקנו ברקע: מיילים למנהלת נדחים ימים, ובפגישות היא שותקת גם כשיש לה מה לומר. תיארה פחד ש"יראו שאינה יודעת" ובושה אחרי דיבורים. אין היסטוריה של טיפול CBT קודם. חידדנו את המטרה: לא להעלים חרדה לגמרי, אלא להוריד תסכול מ־90% ל־50% ולאפשר דיבור מול סמכות וקהל.
            """.trimIndent(),
            """
            הסבר על טיפול CBT: קשר בין מצב, מחשבה אוטומטית, רגש, תחושה בגוף והתנהגות. הראינו איך הימנעות מורידה חרדה לטווח קצר ומחזקת אותה לטווח ארוך. הצגנו שיומני מחשבות ישמשו לאיסוף דוגמאות מהשבוע. משימה: לשים לב השבוע למצבים מול סמכות/קהל בלי לשנות עדיין התנהגות.
            """.trimIndent(),
            """
            מילוי יומן 1: אירוע — זימון לישיבה עם המנהלת. מחשבה — "אגיד משהו טיפשי והיא תחשוב שאני לא מקצועית". רגש — תסכול וחרדה בעוצמה 85. תגובה — ביקשה מעמית להציג במקומה. תחושה פיזית — דופק מהיר, לחץ בחזה ויובש בפה.
            """.trimIndent(),
            """
            מילוי יומן 1: אירוע — עדכון קצר במעגל צוות. מחשבה — "כולם רואים שאני רועדת". רגש — בושה ותסכול בעוצמה 70 (נמוך מהשבוע הקודם). תגובה — דיברה משפט אחד ואז שתקה. תחושה פיזית — רעד קל בידיים וחום בפנים. ציינה שנשימה הייתה קצת יותר קלה מאשר בישיבות קודמות.
            """.trimIndent(),
            """
            מילוי יומן 2: אירוע — הצגת סטטוס מול שלושה עמיתים. מחשבה — "הם בטוח חושבים שאני מבולבלת". רגש — חרדה 65. מחשבה חלופית — "אולי הם מקשיבים לתוכן ולא שופטים אותי". טעות חשיבה — קריאת מחשבות (מנחשת שאחרים חושבים עליה לרעה בלי ראיות).
            """.trimIndent(),
            """
            מילוי יומן 2: אירוע — שאלה למנהלת בישיבה. מחשבה — "אם אטעה — הכול אבוד". רגש — תסכול 55. מחשבה חלופית — "טעות נקודתית לא מוחקת את כל העבודה שלי". טעות חשיבה — הכל או כלום (רואה הצלחה מול כישלון בלי גוונים). דיווחה שהתסכול בסוף האירוע ירד לכ־45.
            """.trimIndent(),
        )
        val p1Sessions = makeSessions("demo-1", p1Notes, ::sessionDate)
        val patient1 = Patient(
            id = p1Id,
            firstName = "ישראלה",
            lastName = "ישראלית",
            status = PatientStatus.Active,
            notes = "חרדה חברתית מול סמכות וקהל. מטרה: תסכול 90%→50%. עובדת על הימנעות, מחשבות אוטומטיות וחשיפות מדורגות.",
            sessions = p1Sessions,
            localName = "ישראלה ישראלית",
            formulation = PatientFormulation(
                treatmentGoal = "הורדת רמת התסכול מ־90% ל־50% בסיטואציות של חרדה חברתית (סמכות / קהל)",
                coreBelief = "אני לא ראויה להישמע / יראו שאני לא מספיק טובה",
                keyAutomaticThoughts = listOf(
                    "יראו שאני לא יודעת",
                    "אגיד משהו טיפשי",
                    "המנהלת תחשוב שאני לא מקצועית",
                ),
                maintainingBehaviors = listOf(
                    "הימנעות מישיבות ומעבר מצגות לאחרים",
                    "דחיינות במיילים לבעלי סמכות",
                    "בדיקות יתר של ניסוחים לפני שליחה",
                ),
                keyCBTCycle = null,
                therapistHypothesis = "מעגל הימנעות חברתית מוזן מקריאת מחשבות ופחד מהערכה שלילית; חשיפה מדורגת + אתגור מחשבות מפחיתים תסכול לאורך זמן.",
            ),
        )
        val p1Questionnaires = makeQuestionnaires(
            patientKey = "demo-1",
            sessionIds = p1Sessions.mapNotNull { it.databaseId },
            date = ::sessionDate,
            gad7Series = listOf(
                listOf(2, 3, 2, 3, 2, 2, 2),
                listOf(2, 2, 2, 3, 2, 2, 2),
                listOf(3, 2, 2, 2, 2, 2, 2),
                listOf(2, 2, 2, 2, 1, 2, 1),
                listOf(2, 1, 2, 2, 1, 1, 1),
                listOf(1, 2, 1, 2, 1, 1, 1),
            ),
            phq9Series = listOf(
                listOf(1, 1, 1, 1, 0, 1, 0, 0, 0),
                listOf(1, 1, 0, 1, 0, 1, 0, 0, 0),
                listOf(1, 1, 1, 1, 0, 1, 0, 0, 0),
                listOf(1, 0, 1, 1, 0, 0, 0, 0, 0),
                listOf(0, 1, 0, 1, 0, 0, 0, 0, 0),
                listOf(0, 1, 0, 1, 0, 0, 0, 0, 0),
            ),
            interference = listOf(2, 2, 2, 1, 1, 1),
        )

        val p2Id = DatabaseId.Text("demo-2")
        val p2Notes = listOf(
            """
            אדם מתאר חרדת בריאות שנמשכת כחמש שנים. הפחד התחיל אחרי שבר קרסול בזמן ריצה, ומאז כל תחושה בגוף מתפרשת כסכנה. עוצמת הפחד בסיטואציות מפעילות מגיעה לכ־85%. מטרה ראשונית שהגדרנו יחד: הורדת עוצמת הפחד ל־40% באותן סיטואציות.
            """.trimIndent(),
            """
            רקע נוסף: בדיקות גוגל יומיות, מדידות דופק חוזרות, ולעיתים פניות לרופא גם אחרי בדיקות תקינות. נמנע מריצה וממאמץ משמעותי מאז השבר. אין אבחנה רפואית פעילה שמסבירה את הפחד הנוכחי. חידדנו מטרה: להפחית פחד מ־85% ל־40% ולאפשר חזרה הדרגתית לפעילות בלי בדיקות ביטחון קבועות.
            """.trimIndent(),
            """
            הסבר על CBT בחרדת בריאות: תחושה גופנית → פרשנות מאיימת → חרדה → בדיקת ביטחון/הימנעות → חיזוק הפחד. הדגשנו שהבדיקות מורידות חרדה רגעית ומשמרות אותה. הצגנו יומן ככלי להפריד בין עובדה (תחושה) לפרשנות. משימה: לשים לב לתחושות אחרי מאמץ קל בלי לשנות עדיין הרגלים.
            """.trimIndent(),
            """
            מילוי יומן 1: אירוע — עליית מדרגות בדרך לעבודה. מחשבה — "הדופק הזה הוא סימן לבעיית לב". רגש — פחד בעוצמה 80. תגובה — עצר, מדד דופק בטלפון וחיפש תסמינים בגוגל. תחושה פיזית — דופק מהיר, הזעה קלה ולחץ בחזה.
            """.trimIndent(),
            """
            מילוי יומן 1: אירוע — הליכה מהירה בפארק. מחשבה — "אם משהו יקרה — אף אחד לא יעזור בזמן". רגש — פחד 70, עם רגע של הקלה באמצע. תגובה — המשיך ללכת בלי מד דופק כ־10 דקות ואז בדק פעם אחת. תחושה פיזית — נשימה כבדה בהתחלה שהתמתנה בהמשך.
            """.trimIndent(),
            """
            מילוי יומן 2: אירוע — כאב שריר בשוק אחרי הליכה. מחשבה — "בטוח שזה קריש / משהו מסוכן". רגש — פחד 75. מחשבה חלופית — "אחרי מאמץ כאב שריר נפוץ ובדרך כלל חולף". טעות חשיבה — ראיית העתיד (רואה שחורות ומניח שהדברים יתפתחו לרעה).
            """.trimIndent(),
            """
            מילוי יומן 2: אירוע — ריצה קלה במסלול מוכר. מחשבה — "אני מרגיש בסכנה — כנראה באמת קורה משהו רע". רגש — פחד שיא 55, בסוף כ־40. מחשבה חלופית — "תחושת סכנה היא חרדה, לא הוכחה רפואית". טעות חשיבה — טיעון רגשי (מסיק מסקנות מהרגש במקום מעובדות).
            """.trimIndent(),
        )
        val p2Sessions = makeSessions("demo-2", p2Notes, ::sessionDate)
        val patient2 = Patient(
            id = p2Id,
            firstName = "אדם",
            lastName = "אדמוני",
            status = PatientStatus.Active,
            notes = "חרדת בריאות ~5 שנים מאז שבר קרסול בריצה. מטרה: פחד 85%→40%. ERP עדין, צמצום בדיקות ביטחון וחזרה לפעילות.",
            sessions = p2Sessions,
            localName = "אדם אדמוני",
            formulation = PatientFormulation(
                treatmentGoal = "הורדת עוצמת הפחד מ־85% ל־40% בסיטואציות של חרדת בריאות",
                coreBelief = "הגוף שלי שביר — משהו חמור מתפספס",
                keyAutomaticThoughts = listOf(
                    "זה הלב / מחלה חמורה",
                    "פספסו ממצא בבדיקות",
                    "אם לא אבדוק עכשיו יהיה מאוחר",
                ),
                maintainingBehaviors = listOf(
                    "מדידת דופק ובדיקות גוף חוזרות",
                    "חיפושי גוגל רפואיים",
                    "הימנעות מריצה וממאמץ",
                ),
                keyCBTCycle = null,
                therapistHypothesis = "חרדת בריאות מתוחזקת ע״י בדיקות ביטחון והימנעות ממאמץ מאז טראומת השבר; חשיפה עם מניעת תגובה מפחיתה את הפחד.",
            ),
        )
        val p2Questionnaires = makeQuestionnaires(
            patientKey = "demo-2",
            sessionIds = p2Sessions.mapNotNull { it.databaseId },
            date = ::sessionDate,
            gad7Series = listOf(
                listOf(3, 3, 2, 3, 2, 2, 3),
                listOf(3, 2, 2, 3, 2, 2, 2),
                listOf(2, 3, 2, 2, 2, 2, 2),
                listOf(2, 2, 2, 2, 2, 1, 2),
                listOf(2, 2, 1, 2, 1, 1, 2),
                listOf(1, 2, 1, 2, 1, 1, 1),
            ),
            phq9Series = listOf(
                listOf(1, 1, 2, 1, 1, 1, 1, 0, 0),
                listOf(1, 1, 1, 1, 1, 1, 0, 0, 0),
                listOf(1, 1, 2, 1, 1, 1, 0, 0, 0),
                listOf(1, 0, 1, 1, 1, 0, 0, 0, 0),
                listOf(0, 1, 1, 1, 0, 0, 0, 0, 0),
                listOf(0, 0, 1, 1, 0, 0, 0, 0, 0),
            ),
            interference = listOf(2, 2, 2, 2, 1, 1),
        )

        val p3Id = DatabaseId.Text("demo-3")
        val p3Notes = listOf(
            """
            ברכה מתארת דכאון קל מאז מעבר דירה — ייאוש בערבים עד כ־100%. מספרת על ירידה בהנאה, קושי להתחיל משימות, וריחוק מחברות מהשכונה הישנה. הדירה החדשה עדיין לא מרגישה כמו בית. מטרה ראשונית: הורדת תחושת הייאוש ל־50%.
            """.trimIndent(),
            """
            רקע: המעבר היה לפני כחודשיים, בלי רשת תמיכה מקומית. מתארת בידוד בערבים ודחיינות בסידור הבית. אין אפיזודה דיכאונית חמורה בעבר; השינוי קשור במעבר. חידדנו מטרה: ייאוש מ־100% ל־50%, לצד חזרה לפעילויות קטנות ותחושת שייכות במקום החדש.
            """.trimIndent(),
            """
            הסבר על CBT בדכאון: מחשבות שליליות וחוסר פעילות מזינים זה את זה במעגל. הצגנו כיצד שינוי התנהגות קטן יכול להשפיע על מצב הרוח גם לפני שחוזר "החשק". יומנים ישמשו לתפוס אירועים ומחשבות מהשבוע. משימה: לשים לב לערבים הקשים בלי לדרוש מעצמה שינוי גדול עדיין.
            """.trimIndent(),
            """
            מילוי יומן 1: אירוע — ניסיון לסדר קרטונים בסלון. מחשבה — "אין טעם, זה לא ייגמר לעולם". רגש — ייאוש בעוצמה 90. תגובה — הפסיקה אחרי דקות ועברה למסך. תחושה פיזית — כבדות בגוף ועייפות חזקה.
            """.trimIndent(),
            """
            מילוי יומן 1: אירוע — סיבוב קצר בבניין החדש. מחשבה — "אף אחד פה לא יהיה חבר אמיתי". רגש — עצב וייאוש 75. תגובה — חייכה לשכנה ואז חזרה מהר לדירה. תחושה פיזית — לחץ בגרון ודמעות קרובות. ציינה שהיציאה בכל זאת הרגישה קצת פחות כבדה מהשבוע שעבר.
            """.trimIndent(),
            """
            מילוי יומן 2: אירוע — דירה מבולגנת בערב אחרי יום עבודה. מחשבה — "אני כישלון מוחלט שלא מצליחה לבנות בית". רגש — ייאוש 80. מחשבה חלופית — "מעבר הוא תהליך; עשיתי כבר כמה צעדים קטנים". טעות חשיבה — שימוש בתוויות (במקום "עשיתי מעט היום" אומרת "אני כישלון").
            """.trimIndent(),
            """
            מילוי יומן 2: אירוע — שיחה עם חברה מהעיר הקודמת ואז ערב בבית קפה קרוב. מחשבה — "בלי הסביבה הישנה אני לבד לתמיד". רגש — ייאוש שיא 60, בסוף כ־50. מחשבה חלופית — "אפשר לבנות קשרים חדשים לאט, כמו שהיו פעם". טעות חשיבה — הכללה (אירוע של בדידות זמנית נראה כדפוס קבוע שלא ישתנה).
            """.trimIndent(),
        )
        val p3Sessions = makeSessions("demo-3", p3Notes, ::sessionDate)
        val patient3 = Patient(
            id = p3Id,
            firstName = "ברכה",
            lastName = "ברכיה",
            status = PatientStatus.Active,
            notes = "דכאון קל אחרי מעבר דירה. מטרה: ייאוש 100%→50%. הפעלה התנהגותית, שבירת הימנעות ובניית שייכות במקום החדש.",
            sessions = p3Sessions,
            localName = "ברכה ברכיה",
            formulation = PatientFormulation(
                treatmentGoal = "הורדת רמת הייאוש מ־100% ל־50% מתחושת הדכאון אחרי מעבר הדירה",
                coreBelief = "בלי הסביבה הישנה אני לבד / לא אצליח לבנות בית",
                keyAutomaticThoughts = listOf(
                    "לעולם לא ארגיש בבית",
                    "אין טעם להתחיל לסדר",
                    "אני לא מצליחה לבנות חיים מחדש",
                ),
                maintainingBehaviors = listOf(
                    "הימנעות מסידור הדירה",
                    "צמצום קשרים חברתיים",
                    "בידוד בערבים מול מסך",
                ),
                keyCBTCycle = null,
                therapistHypothesis = "מעגל הימנעות אחרי אובדן הקשר הישן משמר דכאון קל; הפעלה התנהגותית ובניית שייכות מקומית מפחיתים ייאוש.",
            ),
        )
        val p3Questionnaires = makeQuestionnaires(
            patientKey = "demo-3",
            sessionIds = p3Sessions.mapNotNull { it.databaseId },
            date = ::sessionDate,
            gad7Series = listOf(
                listOf(2, 1, 2, 1, 1, 1, 1),
                listOf(1, 2, 1, 1, 1, 1, 1),
                listOf(2, 1, 2, 1, 1, 1, 0),
                listOf(1, 1, 1, 1, 1, 0, 1),
                listOf(1, 1, 1, 0, 1, 0, 0),
                listOf(1, 0, 1, 1, 0, 0, 0),
            ),
            phq9Series = listOf(
                listOf(2, 3, 2, 2, 2, 2, 1, 1, 0),
                listOf(2, 2, 2, 2, 2, 2, 1, 1, 0),
                listOf(2, 3, 2, 2, 1, 2, 1, 1, 0),
                listOf(2, 2, 1, 2, 1, 1, 1, 0, 0),
                listOf(1, 2, 1, 2, 1, 1, 1, 0, 0),
                listOf(1, 1, 1, 1, 1, 1, 0, 0, 0),
            ),
            interference = listOf(3, 2, 2, 2, 1, 1),
        )

        return Bundle(
            patients = listOf(patient1, patient2, patient3),
            questionnairesByPatient = mapOf(
                p1Id to p1Questionnaires,
                p2Id to p2Questionnaires,
                p3Id to p3Questionnaires,
            ),
        )
    }

    private fun makeSessions(
        patientKey: String,
        notes: List<String>,
        date: (Int) -> Date,
    ): List<Session> =
        showcaseSessionTypes.mapIndexed { offset, type ->
            val n = offset + 1
            Session(
                databaseId = DatabaseId.Text("$patientKey-s$n"),
                date = date(n),
                notes = notes[offset].trim(),
                type = type,
            )
        }

    private fun makeQuestionnaires(
        patientKey: String,
        sessionIds: List<DatabaseId>,
        date: (Int) -> Date,
        gad7Series: List<List<Int>>,
        phq9Series: List<List<Int>>,
        interference: List<Int>,
    ): List<CompletedQuestionnaire> =
        gad7Series.indices.map { index ->
            val sessionNumber = index + 2
            completedQuestionnaire(
                id = DatabaseId.Text("$patientKey-q${index + 1}"),
                sessionId = sessionIds[sessionNumber - 1],
                date = date(sessionNumber),
                gad7 = gad7Series[index],
                phq9 = phq9Series[index],
                interferenceLevel = interference[index],
            )
        }.reversed()

    private fun completedQuestionnaire(
        id: DatabaseId,
        sessionId: DatabaseId,
        date: Date,
        gad7: List<Int>,
        phq9: List<Int>,
        interferenceLevel: Int,
    ) = CompletedQuestionnaire(
        databaseId = id,
        sessionId = sessionId,
        answeredDate = date,
        questionnaire = CombinedMoodQuestionnaire(
            gad7Answers = gad7.map { it },
            phq9Answers = phq9.map { it },
            interferenceLevel = interferenceLevel,
        ),
    )
}
