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

    @MainActor
    static func makeBundle() -> Bundle {
        let calendar = Calendar.current
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: .now)) ?? .now
        }

        // MARK: Patient 1 — anxiety

        let p1ID = DatabaseID.text("demo-1")
        let p1s1ID = DatabaseID.text("demo-1-s1")
        let p1s2ID = DatabaseID.text("demo-1-s2")
        let p1s3ID = DatabaseID.text("demo-1-s3")

        let p1Session1 = Session(
            databaseID: p1s1ID,
            date: daysAgo(28),
            notes: "DEMO: שיחת היכרות. דיווח על דאגנות מוגברת בעבודה ובזוגיות.",
            type: .firstPhoneCall,
            structuredNotes: decodeAnalysis("""
            {
              "session_summary": "DEMO: שיחת היכרות קצרה. המטופלת מתארת דאגנות חוזרות בעבודה.",
              "key_situations": [
                {"situation": "ישיבת צוות", "why_it_matters": "מעוררת חשש מביקורת"}
              ],
              "possible_nats": [
                {
                  "thought": "אני אכשל ואכולס",
                  "situation": "לפני מצגת",
                  "emotion": "חרדה",
                  "behavior": "הימנעות מהכנה",
                  "source": "patient",
                  "confidence": "high",
                  "cognitive_patterns": [
                    {"pattern": "catastrophizing", "evidence": "קפיצה לתוצאה הגרועה ביותר", "confidence": "medium"}
                  ]
                }
              ],
              "cbt_cycles": [
                {
                  "trigger_situation": "מייל מהמנהל",
                  "automatic_thought": "משהו לא בסדר איתי",
                  "emotion": "חרדה",
                  "behavior": "בדיקות חוזרות של המייל",
                  "short_term_consequence": "הקלה רגעית",
                  "long_term_consequence": "עלייה בדאגנות",
                  "evidence": "תואר בפגישה",
                  "confidence": "medium"
                }
              ],
              "therapist_hypotheses": [
                {"hypothesis": "רגישות להערכה חברתית", "evidence": "דפוס חוזר בישיבות", "confidence": "medium"}
              ],
              "follow_up_questions": [
                {"question": "מה קורה בגוף לפני מצגת?", "reason": "למפות תסמינים", "status": null}
              ],
              "assignments_for_next_week": [
                {"assignment": "רישום דאגות יומי", "details": "10 דקות בערב"}
              ]
            }
            """)
        )

        let p1Session2 = Session(
            databaseID: p1s2ID,
            date: daysAgo(14),
            notes: "DEMO: אינטייק. מטרה ראשונית — הפחתת הימנעות מישיבות.",
            type: .intake,
            structuredNotes: decodeAnalysis("""
            {
              "session_summary": "DEMO: אינטייק מורחב. זוהו מצבי טריגר בעבודה וחברים.",
              "key_situations": [
                {"situation": "ארוחת ערב עם חברות", "why_it_matters": "הימנעות חברתית"}
              ],
              "possible_nats": [],
              "cbt_cycles": [],
              "therapist_hypotheses": [],
              "follow_up_questions": [
                {"question": "איך נראית הצלחה בטיפול אחרי חודשיים?", "reason": "חידוד מטרה", "status": null}
              ],
              "assignments_for_next_week": [
                {"assignment": "חשיפה קטנה לישיבה קצרה", "details": "נוכחות 20 דקות"}
              ]
            }
            """)
        )

        let p1Session3 = Session(
            databaseID: p1s3ID,
            date: daysAgo(3),
            notes: "DEMO: פסיכו-חינוך על מודל CBT. תרגול זיהוי מחשבות.",
            type: .psychoEducation,
            structuredNotes: decodeAnalysis("""
            {
              "session_summary": "DEMO: הוצג מודל CBT. המטופלת זיהתה שני מצבי טריגר מהשבוע.",
              "key_situations": [],
              "possible_nats": [
                {
                  "thought": "אם אשאל שאלה יחשבו שאני לא מבינה",
                  "situation": "ישיבה",
                  "emotion": "בושה",
                  "behavior": "שתיקה",
                  "source": "patient",
                  "confidence": "high",
                  "cognitive_patterns": [
                    {"pattern": "mind_reading", "evidence": "הנחה על מחשבות אחרים", "confidence": "high"}
                  ]
                }
              ],
              "cbt_cycles": [],
              "therapist_hypotheses": [],
              "follow_up_questions": [],
              "assignments_for_next_week": [
                {"assignment": "יומן מחשבות x3", "details": "מצב-מחשבה-רגש-התנהגות"}
              ]
            }
            """)
        )

        let patient1 = Patient(
            id: p1ID,
            firstName: "נועה",
            lastName: "כהן",
            status: .active,
            notes: "DEMO: מטופלת לדוגמה — חרדה חברתית/תפקודית בעבודה.",
            sessions: [p1Session1, p1Session2, p1Session3]
        )
        patient1.formulation = PatientFormulation(
            treatmentGoal: "DEMO: הפחתת הימנעות מישיבות והגדלת ביטחון בדיבור בקבוצה",
            coreBelief: "DEMO: אני לא מספיק טובה",
            keyAutomaticThoughts: ["אכשל מול כולם", "יבחינו שאני מבולבלת"],
            maintainingBehaviors: ["הימנעות מישיבות", "בדיקות יתר של מיילים"],
            keyCBTCycle: decodeCycle("""
                {
                  "trigger_situation": "הזמנה לישיבה",
                  "automatic_thought": "אמעד ואכלם",
                  "emotion": "חרדה",
                  "behavior": "ביטול השתתפות",
                  "short_term_consequence": "הקלה",
                  "long_term_consequence": "חיזוק האמונה שאי אפשר להתמודד",
                  "evidence": "דפוס חוזר",
                  "confidence": "medium"
                }
                """),
            therapistHypothesis: "DEMO: שמירה על דימוי מושלם מזינה הימנעות"
        )
        patient1.localName = "נועה כהן"

        // MARK: Patient 2 — low mood

        let p2ID = DatabaseID.text("demo-2")
        let p2s1ID = DatabaseID.text("demo-2-s1")
        let p2s2ID = DatabaseID.text("demo-2-s2")

        let p2Session1 = Session(
            databaseID: p2s1ID,
            date: daysAgo(21),
            notes: "DEMO: אינטייק. ירידה באנרגיה ובהנאה משבועות.",
            type: .intake,
            structuredNotes: decodeAnalysis("""
            {
              "session_summary": "DEMO: אינטייק בדיכאון קל-בינוני. פחות פעילות חברתית וספורט.",
              "key_situations": [
                {"situation": "בוקר באמצע השבוע", "why_it_matters": "קושי בהתנעה"}
              ],
              "possible_nats": [
                {
                  "thought": "אין טעם לנסות",
                  "situation": "לפני יציאה מהבית",
                  "emotion": "עצב",
                  "behavior": "הישארות במיטה",
                  "source": "patient",
                  "confidence": "high",
                  "cognitive_patterns": [
                    {"pattern": "all_or_nothing", "evidence": "אין אמצע בין הצלחה לכישלון", "confidence": "medium"}
                  ]
                }
              ],
              "cbt_cycles": [],
              "therapist_hypotheses": [
                {"hypothesis": "מעגל של חוסר פעילות מחזק מצב רוח ירוד", "evidence": "ירידה בפעילות", "confidence": "high"}
              ],
              "follow_up_questions": [],
              "assignments_for_next_week": [
                {"assignment": "פעילות נעימה קצרה כל יום", "details": "15 דקות"}
              ]
            }
            """)
        )

        let p2Session2 = Session(
            databaseID: p2s2ID,
            date: daysAgo(7),
            notes: "DEMO: התערבות התנהגותית — תכנון פעילויות.",
            type: .behavioralInterventions,
            structuredNotes: decodeAnalysis("""
            {
              "session_summary": "DEMO: נבנה לוח פעילויות לשבוע. דיווח על הליכה אחת שהצליחה.",
              "key_situations": [],
              "possible_nats": [],
              "cbt_cycles": [
                {
                  "trigger_situation": "סוף יום עבודה",
                  "automatic_thought": "אני מותש מדי בשביל כלום",
                  "emotion": "עייפות/עצב",
                  "behavior": "צפייה פסיבית במסך",
                  "short_term_consequence": "הסחת דעת",
                  "long_term_consequence": "פחות סיפוק",
                  "evidence": "תואר במפגש",
                  "confidence": "medium"
                }
              ],
              "therapist_hypotheses": [],
              "follow_up_questions": [
                {"question": "איזו פעילות נתנה את הציון הגבוה ביותר?", "reason": "חיזוק מוטיבציה", "status": null}
              ],
              "assignments_for_next_week": [
                {"assignment": "3 פעילויות מתוכננות", "details": "כולל דירוג הנאה/הישג"}
              ]
            }
            """)
        )

        let patient2 = Patient(
            id: p2ID,
            firstName: "יוסי",
            lastName: "לוי",
            status: .active,
            notes: "DEMO: מטופל לדוגמה — מצב רוח ירוד והימנעות מפעילות.",
            sessions: [p2Session1, p2Session2]
        )
        patient2.formulation = PatientFormulation(
            treatmentGoal: "DEMO: החזרת שגרת פעילות והנאה יומית",
            coreBelief: "DEMO: אני חסר ערך כשאני לא פרודוקטיבי",
            keyAutomaticThoughts: ["אין טעם", "אני מאכזב"],
            maintainingBehaviors: ["הימנעות מחברים", "דחיינות של ספורט"],
            keyCBTCycle: nil,
            therapistHypothesis: "DEMO: חיזוק שלילי דרך הימנעות"
        )
        patient2.localName = "יוסי לוי"

        // MARK: Patient 3 — early treatment / inactive-ish variety

        let p3ID = DatabaseID.text("demo-3")
        let p3s1ID = DatabaseID.text("demo-3-s1")

        let p3Session1 = Session(
            databaseID: p3s1ID,
            date: daysAgo(10),
            notes: "DEMO: שיחת טלפון ראשונה. מעוניינת בטיפול סביב דאגות משפחתיות.",
            type: .firstPhoneCall
        )

        let patient3 = Patient(
            id: p3ID,
            firstName: "מיכל",
            lastName: "אברהם",
            status: .inactive,
            notes: "DEMO: מטופלת לדוגמה בתחילת קשר — מעט נתונים עדיין.",
            sessions: [p3Session1]
        )
        patient3.formulation = PatientFormulation(
            treatmentGoal: "DEMO: הבהרת מטרות טיפול ראשוניות",
            coreBelief: nil,
            keyAutomaticThoughts: [],
            maintainingBehaviors: [],
            keyCBTCycle: nil,
            therapistHypothesis: nil
        )
        patient3.localName = "מיכל אברהם"

        // MARK: Questionnaires

        let q1 = completedQuestionnaire(
            id: .text("demo-1-q1"),
            sessionID: p1s2ID,
            date: daysAgo(14),
            gad7: [2, 2, 1, 2, 1, 2, 1],
            phq9: [1, 1, 0, 1, 0, 1, 0, 0, 0]
        )
        let q2 = completedQuestionnaire(
            id: .text("demo-1-q2"),
            sessionID: p1s3ID,
            date: daysAgo(3),
            gad7: [1, 2, 1, 1, 1, 1, 1],
            phq9: [1, 0, 0, 1, 0, 0, 0, 0, 0]
        )
        let q3 = completedQuestionnaire(
            id: .text("demo-2-q1"),
            sessionID: p2s1ID,
            date: daysAgo(21),
            gad7: [1, 1, 1, 0, 1, 0, 0],
            phq9: [2, 2, 1, 2, 1, 2, 1, 1, 0]
        )
        let q4 = completedQuestionnaire(
            id: .text("demo-2-q2"),
            sessionID: p2s2ID,
            date: daysAgo(7),
            gad7: [1, 0, 1, 0, 1, 0, 0],
            phq9: [1, 2, 1, 1, 1, 1, 1, 0, 0]
        )

        let questionnaires: [DatabaseID: [CompletedQuestionnaire]] = [
            p1ID: [q2, q1],
            p2ID: [q4, q3],
            p3ID: [],
        ]

        // MARK: Preparations

        let prep1 = decodePreparation("""
        {
          "preparation": {
            "executive_summary": "DEMO: התקדמות קלה בחרדה. לבדוק ביצוע משימות החשיפה.",
            "priority_follow_ups": [
              {"item": "בדיקת משימת החשיפה לישיבה", "reason": "משימה פתוחה", "source": "last_session"}
            ],
            "recurring_nats": [
              {
                "thought": "יבחינו שאני לא מבינה",
                "situations": ["ישיבות", "שאלות בקבוצה"],
                "cognitive_patterns": [
                  {"pattern": "mind_reading", "evidence": "חוזר במפגשים", "confidence": "high"}
                ],
                "evidence": "שני מפגשים אחרונים",
                "confidence": "high"
              }
            ],
            "cbt_cycles": [],
            "questionnaire_insights": [
              {
                "observation": "ירידה קלה ב-GAD-7",
                "evidence": "מ-11 ל-8 לערך",
                "clinical_relevance": "עקבי עם דיווח על חשיפה"
              }
            ],
            "treatment_focus": {
              "focus": "המשך חשיפות מדורגות בעבודה",
              "rationale": "הימנעות עדיין מרכזית"
            },
            "suggested_questions": [
              {"question": "מה היה הכי מפתיע בחשיפה?", "purpose": "חיזוק למידה"}
            ],
            "core_belief_hypothesis": {
              "belief": "אני לא מספיק טובה",
              "evidence": ["דאגות בישיבות", "הימנעות"],
              "confidence": "medium"
            },
            "assignments_to_check": [
              {"assignment": "יומן מחשבות x3", "details": "מהמפגש הקודם"}
            ]
          },
          "usage": {"totalTokens": 0}
        }
        """)

        let prep2 = decodePreparation("""
        {
          "preparation": {
            "executive_summary": "DEMO: יש תנועה בפעילות. לחזק תכנון ולהתמודד עם מחשבות 'אין טעם'.",
            "priority_follow_ups": [
              {"item": "סקירת דירוגי הנאה/הישג", "reason": "משימת השבוע", "source": "last_session"}
            ],
            "recurring_nats": [],
            "cbt_cycles": [],
            "questionnaire_insights": [
              {
                "observation": "PHQ-9 עדיין מוגבר",
                "evidence": "ציון בינוני",
                "clinical_relevance": "להמשיך הפעלה התנהגותית"
              }
            ],
            "treatment_focus": {
              "focus": "הפעלה התנהגותית עקבית",
              "rationale": "מפחיתה מעגל הימנעות"
            },
            "suggested_questions": [
              {"question": "איזו פעילות הייתה הכי קשה להתחיל?", "purpose": "זיהוי מחסומים"}
            ],
            "core_belief_hypothesis": null,
            "assignments_to_check": [
              {"assignment": "3 פעילויות מתוכננות", "details": null}
            ]
          },
          "usage": {"totalTokens": 0}
        }
        """)

        return Bundle(
            patients: [patient1, patient2, patient3],
            questionnairesByPatient: questionnaires,
            preparationsByPatient: [
                p1ID: prep1,
                p2ID: prep2,
            ]
        )
    }

    // MARK: - Helpers

    private static func completedQuestionnaire(
        id: DatabaseID,
        sessionID: DatabaseID,
        date: Date,
        gad7: [Int],
        phq9: [Int]
    ) -> CompletedQuestionnaire {
        var q = CombinedMoodQuestionnaire()
        q.gad7Answers = gad7.map { Optional($0) }
        q.phq9Answers = phq9.map { Optional($0) }
        q.interferenceLevel = 1
        return CompletedQuestionnaire(
            databaseID: id,
            sessionID: sessionID,
            answeredDate: date,
            questionnaire: q
        )
    }

    private static func decodeAnalysis(_ json: String) -> WhisperService.CBTSessionAnalysis {
        let data = Data(json.utf8)
        do {
            return try JSONDecoder().decode(WhisperService.CBTSessionAnalysis.self, from: data)
        } catch {
            // Keep demo mode usable if sample JSON drifts from the model.
            AppLog.store.error("Demo analysis JSON failed: \(String(describing: error), privacy: .public)")
            let fallback = """
            {"session_summary":"DEMO","key_situations":[],"possible_nats":[],"cbt_cycles":[],"therapist_hypotheses":[],"follow_up_questions":[],"assignments_for_next_week":[]}
            """
            return try! JSONDecoder().decode(
                WhisperService.CBTSessionAnalysis.self, from: Data(fallback.utf8))
        }
    }

    private static func decodePreparation(_ json: String) -> WhisperService.PrepareSessionResponse {
        let data = Data(json.utf8)
        do {
            return try JSONDecoder().decode(WhisperService.PrepareSessionResponse.self, from: data)
        } catch {
            // Keep demo mode usable if sample JSON drifts from the model.
            AppLog.store.error("Demo preparation JSON failed: \(String(describing: error), privacy: .public)")
            let fallback = """
            {"preparation":{"executive_summary":"DEMO","priority_follow_ups":[],"recurring_nats":[],"cbt_cycles":[],"questionnaire_insights":[],"treatment_focus":null,"suggested_questions":[],"core_belief_hypothesis":null,"assignments_to_check":[]},"usage":{"totalTokens":0}}
            """
            return try! JSONDecoder().decode(
                WhisperService.PrepareSessionResponse.self, from: Data(fallback.utf8))
        }
    }

    private static func decodeCycle(_ json: String) -> WhisperService.NextSessionPreparation.CBTCycle {
        try! JSONDecoder().decode(
            WhisperService.NextSessionPreparation.CBTCycle.self, from: Data(json.utf8))
    }
}
