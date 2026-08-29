import Foundation

/// Compact, structured patient context for the "Prepare for Next Session"
/// Edge Function (Phase 2). Built from the models already in memory —
/// `Patient`, `Session`, `CompletedQuestionnaire`, and the saved
/// `WhisperService.CBTSessionAnalysis` reviews — and encoded straight to
/// JSON with snake_case keys.
///
/// Deliberately excludes identifying data (name, database IDs). Follow-up
/// questions appear only in `openFollowUps`, not inside the reviews, so
/// nothing is sent twice.
nonisolated struct PatientContext: Encodable {

    // MARK: - Sections

    /// Who the patient is, clinically. The app currently stores only the
    /// therapist's free-text patient notes; the other fields are filled in
    /// by the caller when known and omitted from the JSON otherwise.
    struct Overview: Encodable {
        var age: Int?
        var gender: String?
        var presentingProblems: String?
        var treatmentGoals: String?
        /// The therapist's free-text notes about the patient.
        var background: String?

        enum CodingKeys: String, CodingKey {
            case age
            case gender
            case presentingProblems = "presenting_problems"
            case treatmentGoals = "treatment_goals"
            case background
        }
    }

    /// One GAD-7 + PHQ-9 assessment. Answers keep their question positions
    /// (unanswered questions encode as null).
    struct Assessment: Encodable {
        let date: String
        let gad7Answers: [Int?]
        let gad7Score: Int
        let phq9Answers: [Int?]
        let phq9Score: Int
        let interferenceLevel: Int?

        enum CodingKeys: String, CodingKey {
            case date
            case gad7Answers = "gad7_answers"
            case gad7Score = "gad7_score"
            case phq9Answers = "phq9_answers"
            case phq9Score = "phq9_score"
            case interferenceLevel = "interference_level"
        }
    }

    /// A session's post-session notes.
    struct SessionNote: Encodable {
        let date: String
        let notes: String
    }

    /// The clinically relevant core of a saved AI session review. Reuses the
    /// analysis types as-is.
    struct SessionReview: Encodable {
        let date: String
        let summary: String
        let possibleNats: [WhisperService.PossibleNAT]
        let cbtCycles: [WhisperService.NextSessionPreparation.CBTCycle]
        let therapistHypotheses: [WhisperService.TherapistHypothesis]
        let assignmentsForNextWeek: [WhisperService.AssignmentForNextWeek]

        enum CodingKeys: String, CodingKey {
            case date
            case summary
            case possibleNats = "possible_nats"
            case cbtCycles = "cbt_cycles"
            case therapistHypotheses = "therapist_hypotheses"
            case assignmentsForNextWeek = "assignments_for_next_week"
        }
    }

    /// A follow-up question not yet marked discussed or not relevant.
    struct OpenFollowUp: Encodable {
        let sessionDate: String
        let question: String
        let reason: String

        enum CodingKeys: String, CodingKey {
            case sessionDate = "session_date"
            case question
            case reason
        }
    }

    /// The therapist's own formulation. Not stored in the app yet; provided
    /// by the caller when available.
    struct Formulation: Encodable {
        var formulation: String?
        var treatmentGoals: String?
        var currentFocus: String?

        enum CodingKeys: String, CodingKey {
            case formulation
            case treatmentGoals = "treatment_goals"
            case currentFocus = "current_focus"
        }
    }

    struct Metadata: Encodable {
        let sessionCount: Int
        let lastSessionDate: String?
        let upcomingFocus: String?

        enum CodingKeys: String, CodingKey {
            case sessionCount = "session_count"
            case lastSessionDate = "last_session_date"
            case upcomingFocus = "upcoming_focus"
        }
    }

    // MARK: - Payload

    let overview: Overview
    /// Last assessments, newest first.
    let assessments: [Assessment]
    /// Last sessions' notes, newest first.
    let recentSessions: [SessionNote]
    /// Last saved AI reviews, newest first.
    let recentReviews: [SessionReview]
    let openFollowUps: [OpenFollowUp]
    let formulation: Formulation
    let metadata: Metadata

    enum CodingKeys: String, CodingKey {
        case overview
        case assessments
        case recentSessions = "recent_sessions"
        case recentReviews = "recent_reviews"
        case openFollowUps = "open_follow_ups"
        case formulation
        case metadata
    }

    // MARK: - Building

    private static let maxAssessments = 6
    private static let maxSessionNotes = 5
    private static let maxReviews = 5

    /// Assembles the context from data already loaded for the patient.
    /// `questionnaires` is the patient's questionnaire history (any order),
    /// typically `store.cachedQuestionnaires(for: patient)`.
    @MainActor
    static func make(for patient: Patient,
                     questionnaires: [CompletedQuestionnaire],
                     overview: Overview? = nil,
                     formulation: Formulation = Formulation(),
                     upcomingFocus: String? = nil) -> PatientContext {

        let sessions = patient.sessions.sorted { $0.date > $1.date }

        let trimmedPatientNotes = patient.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        var resolvedOverview = overview ?? Overview()
        if resolvedOverview.background == nil, !trimmedPatientNotes.isEmpty {
            resolvedOverview.background = trimmedPatientNotes
        }

        let assessments = questionnaires
            .sorted { $0.answeredDate > $1.answeredDate }
            .prefix(maxAssessments)
            .map { record in
                Assessment(
                    date: dateString(record.answeredDate),
                    gad7Answers: record.questionnaire.gad7Answers,
                    gad7Score: record.questionnaire.gad7Score,
                    phq9Answers: record.questionnaire.phq9Answers,
                    phq9Score: record.questionnaire.phq9Score,
                    interferenceLevel: record.questionnaire.interferenceLevel
                )
            }

        let recentSessions = sessions
            .filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(maxSessionNotes)
            .map { SessionNote(date: dateString($0.date), notes: $0.notes) }

        let recentReviews = sessions
            .compactMap { session in
                session.structuredNotes.map { analysis in
                    SessionReview(
                        date: dateString(session.date),
                        summary: analysis.sessionSummary,
                        possibleNats: analysis.possibleNats,
                        cbtCycles: analysis.cbtCycles,
                        therapistHypotheses: analysis.therapistHypotheses,
                        assignmentsForNextWeek: analysis.assignmentsForNextWeek
                    )
                }
            }
            .prefix(maxReviews)

        let openFollowUps = sessions.flatMap { session in
            (session.structuredNotes?.followUpQuestions ?? [])
                .filter { $0.status != .discussed && $0.status != .notRelevant }
                .map {
                    OpenFollowUp(sessionDate: dateString(session.date),
                                 question: $0.question,
                                 reason: $0.reason)
                }
        }

        return PatientContext(
            overview: resolvedOverview,
            assessments: Array(assessments),
            recentSessions: Array(recentSessions),
            recentReviews: Array(recentReviews),
            openFollowUps: openFollowUps,
            formulation: formulation,
            metadata: Metadata(
                sessionCount: patient.sessions.count,
                lastSessionDate: sessions.first.map { dateString($0.date) },
                upcomingFocus: upcomingFocus
            )
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func dateString(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
