import Foundation
import OSLog
import Supabase

/// Errors from the Whisper transcription API.
nonisolated enum WhisperError: LocalizedError {
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let message):
            return L10n.transcriptionFailed(message)
        }
    }
}

/// Sends recorded audio to the Supabase Edge Function,
/// which forwards it to OpenAI Whisper.
nonisolated struct WhisperService {
    
    let client: SupabaseClient
    
    private let functionName = "whisper-transcribe"

    /// Transcribes the audio file at `fileURL`.
    /// `language` is an ISO-639-1 code; Hebrew by default.
    func transcribe(
        fileURL: URL,
        language: String = "he"
    ) async throws -> String {

        let audioData: Data

        do {
            audioData = try Data(contentsOf: fileURL)
        } catch {
            throw WhisperError.requestFailed(
                L10n.couldNotReadAudioFile(error.localizedDescription)
            )
        }

        AppLog.ai.info("Transcription requested, audio bytes: \(audioData.count)")
        do {
            let response: TranscriptionResponse =
                try await client.functions.invoke(
                    functionName,
                    options: FunctionInvokeOptions(
                        headers: [
                            "Content-Type": "audio/m4a",
                            "x-language": language
                        ],
                        body: audioData
                    )
                )

            AppLog.ai.info("Transcription succeeded, characters: \(response.text.count)")
            return response.text

        } catch let error as WhisperError {
            AppLog.ai.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
            throw error

        } catch {
            AppLog.ai.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
            throw WhisperError.requestFailed(
                error.localizedDescription
            )
        }
    }

    private struct TranscriptionResponse: Codable, Equatable {
        let text: String
    }
    
    struct SessionReviewResponse: Codable, Equatable {

            let analysis: CBTSessionAnalysis
            let usage: Usage

            struct Usage: Codable, Equatable {
                let totalTokens: Int
            }
        }

        // MARK: - CBT Session Analysis

        struct CBTSessionAnalysis: Codable, Equatable {

            var sessionSummary: String

            var keySituations: [KeySituation]
            var possibleNats: [PossibleNAT]
            /// Reuses the preparation's cycle type: the schemas are identical.
            let cbtCycles: [NextSessionPreparation.CBTCycle]
            let therapistHypotheses: [TherapistHypothesis]
            var followUpQuestions: [FollowUpQuestion]
            /// Homework suggested for the coming week.
            let assignmentsForNextWeek: [AssignmentForNextWeek]

            enum CodingKeys: String, CodingKey {
                case sessionSummary = "session_summary"
                case keySituations = "key_situations"
                case possibleNats = "possible_nats"
                case cbtCycles = "cbt_cycles"
                case therapistHypotheses = "therapist_hypotheses"
                case followUpQuestions = "follow_up_questions"
                case assignmentsForNextWeek = "assignments_for_next_week"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                sessionSummary = try container.decode(String.self, forKey: .sessionSummary)
                keySituations = try container.decode([KeySituation].self, forKey: .keySituations)
                possibleNats = try container.decode([PossibleNAT].self, forKey: .possibleNats)
                cbtCycles = try container.decode([NextSessionPreparation.CBTCycle].self, forKey: .cbtCycles)
                therapistHypotheses = try container.decode([TherapistHypothesis].self, forKey: .therapistHypotheses)
                followUpQuestions = try container.decode([FollowUpQuestion].self, forKey: .followUpQuestions)
                // Analyses saved before assignments existed decode to an
                // empty list instead of failing (and being dropped) entirely.
                assignmentsForNextWeek = try container.decodeIfPresent(
                    [AssignmentForNextWeek].self, forKey: .assignmentsForNextWeek) ?? []
            }
        }

        // MARK: - Key Situation

        struct KeySituation: Codable, Equatable {
            var situation: String
            var whyItMatters: String

            enum CodingKeys: String, CodingKey {
                case situation
                case whyItMatters = "why_it_matters"
            }
        }

        // MARK: - NAT

        struct PossibleNAT: Codable, Equatable {

            var thought: String
            var situation: String
            var emotion: String?
            var behavior: String?
            let source: String
            let confidence: String
            let cognitivePatterns: [CognitivePattern]

            enum CodingKeys: String, CodingKey {
                case thought
                case situation
                case emotion
                case behavior
                case source
                case confidence
                case cognitivePatterns = "cognitive_patterns"
            }
        }

        /// One possible classification of how a NAT may be structured. The
        /// NAT itself is always high confidence, but its interpretation as a
        /// particular pattern may deliberately be high/medium/low.
        struct CognitivePattern: Codable, Equatable {
            let pattern: String
            let evidence: String
            let confidence: String
        }

        // MARK: - Therapist Hypothesis

        struct TherapistHypothesis: Codable, Equatable {
            let hypothesis: String
            let evidence: String
            let confidence: String
        }

        // MARK: - Follow-up Question

        /// A question for the therapist — information missing from the
        /// session notes worth clarifying, not necessarily a question to
        /// ask the patient next session. The backend only returns questions
        /// it considers important, so there is no client-side ranking.
        struct FollowUpQuestion: Codable, Equatable {

            var question: String
            var reason: String
            /// The therapist's triage of the question, set in the app after
            /// the session — never returned by the AI.
            var status: Status?

            enum Status: String, Codable, Equatable {
                case discussed
                case followUp = "follow_up"
                case notRelevant = "not_relevant"
            }
        }

        // MARK: - Assignment For Next Week

        /// One homework assignment suggested for the coming week.
        struct AssignmentForNextWeek: Codable, Equatable {
            let assignment: String
            let details: String?
        }

        // MARK: - Analyze Session

        func analyzeSession(
            sessionNotes: String
        ) async throws -> CBTSessionAnalysis {

            let notes =
                sessionNotes.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard !notes.isEmpty else {
                throw APIError.invalidInput
            }

            AppLog.ai.info("Session analysis requested, notes characters: \(notes.count)")

            // --------------------------------------------------------------
            // Get authenticated session
            // --------------------------------------------------------------

            let session =
                try await client.auth.session

            // --------------------------------------------------------------
            // Edge Function URL
            // --------------------------------------------------------------

            let urlString =
                "\(SupabaseConfig.url)/functions/v1/analyze-session"

            guard let url =
                URL(string: urlString)
            else {
                throw APIError.invalidResponse
            }

            // --------------------------------------------------------------
            // Request
            // --------------------------------------------------------------

            var request =
                URLRequest(url: url)

            request.httpMethod =
                "POST"

            request.setValue(
                "application/json",
                forHTTPHeaderField:
                    "Content-Type"
            )

            request.setValue(
                "Bearer \(session.accessToken)",
                forHTTPHeaderField:
                    "Authorization"
            )

            // --------------------------------------------------------------
            // Body
            // --------------------------------------------------------------

            let requestBody = [
                "sessionNotes": notes
            ]

            request.httpBody =
                try JSONSerialization.data(
                    withJSONObject:
                        requestBody
                )

            // --------------------------------------------------------------
            // Call Edge Function
            // --------------------------------------------------------------

            let (
                data,
                response
            ) =
                try await URLSession.shared.data(
                    for: request
                )

            guard let httpResponse =
                response as? HTTPURLResponse
            else {
                throw APIError.invalidResponse
            }

            // --------------------------------------------------------------
            // Handle error
            // --------------------------------------------------------------

            guard
                200...299 ~= httpResponse.statusCode
            else {

                if let errorResponse =
                    try? JSONDecoder()
                        .decode(
                            APIErrorResponse.self,
                            from: data
                        )
                {
                    throw APIError.server(
                        errorResponse.error
                    )
                }

                throw APIError.server(
                    L10n.sessionAnalysisFailedError
                )
            }

            // --------------------------------------------------------------
            // Decode response
            // --------------------------------------------------------------

            let decoder =
                JSONDecoder()

            let result =
                try decoder.decode(
                    SessionReviewResponse.self,
                    from: data
                )

            AppLog.ai.info("Session analysis succeeded, tokens: \(result.usage.totalTokens)")
            return result.analysis
        }
    
    // MARK: - Prepare Next Session

    /// The Edge Function's preparation for the patient's next session,
    /// matching the prepare-session response schema exactly.
    struct NextSessionPreparation: Codable {

        let executiveSummary: String
        let priorityFollowUps: [PriorityFollowUp]
        let recurringNats: [RecurringNAT]
        let cbtCycles: [CBTCycle]
        let questionnaireInsights: [QuestionnaireInsight]
        let treatmentFocus: TreatmentFocus?
        let suggestedQuestions: [SuggestedQuestion]
        let coreBeliefHypothesis: CoreBeliefHypothesis?
        /// The previous session's assignments, echoed back as the list the
        /// therapist should check with the patient.
        let assignmentsToCheck: [AssignmentForNextWeek]

        enum CodingKeys: String, CodingKey {
            case executiveSummary = "executive_summary"
            case priorityFollowUps = "priority_follow_ups"
            case recurringNats = "recurring_nats"
            case cbtCycles = "cbt_cycles"
            case questionnaireInsights = "questionnaire_insights"
            case treatmentFocus = "treatment_focus"
            case suggestedQuestions = "suggested_questions"
            case coreBeliefHypothesis = "core_belief_hypothesis"
            case assignmentsToCheck = "assignments_to_check"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            executiveSummary = try container.decode(String.self, forKey: .executiveSummary)
            priorityFollowUps = try container.decode([PriorityFollowUp].self, forKey: .priorityFollowUps)
            recurringNats = try container.decode([RecurringNAT].self, forKey: .recurringNats)
            cbtCycles = try container.decode([CBTCycle].self, forKey: .cbtCycles)
            questionnaireInsights = try container.decode([QuestionnaireInsight].self, forKey: .questionnaireInsights)
            treatmentFocus = try container.decodeIfPresent(TreatmentFocus.self, forKey: .treatmentFocus)
            suggestedQuestions = try container.decode([SuggestedQuestion].self, forKey: .suggestedQuestions)
            coreBeliefHypothesis = try container.decodeIfPresent(CoreBeliefHypothesis.self, forKey: .coreBeliefHypothesis)
            // Preparations saved on device before assignments existed
            // decode to an empty list instead of failing entirely.
            assignmentsToCheck = try container.decodeIfPresent(
                [AssignmentForNextWeek].self, forKey: .assignmentsToCheck) ?? []
        }

        struct PriorityFollowUp: Codable {
            let item: String
            let reason: String
            let source: String
        }

        struct RecurringNAT: Codable {
            let thought: String
            let situations: [String]
            /// Shares the session review's pattern type: same schema, and
            /// the two endpoints deliberately use the same 12-label set.
            let cognitivePatterns: [CognitivePattern]
            let evidence: String
            let confidence: String

            enum CodingKeys: String, CodingKey {
                case thought
                case situations
                case cognitivePatterns = "cognitive_patterns"
                case evidence
                case confidence
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                thought = try container.decode(String.self, forKey: .thought)
                situations = try container.decode([String].self, forKey: .situations)
                evidence = try container.decode(String.self, forKey: .evidence)
                confidence = try container.decode(String.self, forKey: .confidence)
                if let patterns = try? container.decode([CognitivePattern].self,
                                                        forKey: .cognitivePatterns) {
                    cognitivePatterns = patterns
                } else {
                    // Preparations saved on device before the schema change
                    // stored patterns as plain strings; keep them readable
                    // with no evidence or confidence.
                    let names = (try? container.decode([String].self,
                                                       forKey: .cognitivePatterns)) ?? []
                    cognitivePatterns = names.map {
                        CognitivePattern(pattern: $0, evidence: "", confidence: "")
                    }
                }
            }
        }

        struct CoreBeliefHypothesis: Codable {
            let belief: String
            let evidence: [String]
            let confidence: String
        }

        /// One hypothesized maintenance cycle. Stages the AI could not
        /// evidence are null and simply omitted from display. Stage fields
        /// are mutable so the therapist's formulation can edit its own copy.
        struct CBTCycle: Codable, Equatable {
            var triggerSituation: String?
            var automaticThought: String?
            var emotion: String?
            var behavior: String?
            var shortTermConsequence: String?
            var longTermConsequence: String?
            let evidence: String
            let confidence: String

            enum CodingKeys: String, CodingKey {
                case triggerSituation = "trigger_situation"
                case automaticThought = "automatic_thought"
                case emotion
                case behavior
                case shortTermConsequence = "short_term_consequence"
                case longTermConsequence = "long_term_consequence"
                case evidence
                case confidence
            }
        }

        struct QuestionnaireInsight: Codable {
            let observation: String
            let evidence: String
            let clinicalRelevance: String

            enum CodingKeys: String, CodingKey {
                case observation
                case evidence
                case clinicalRelevance = "clinical_relevance"
            }
        }

        struct TreatmentFocus: Codable {
            let focus: String
            let rationale: String
        }

        struct SuggestedQuestion: Codable {
            let question: String
            let purpose: String
        }
    }

    struct PrepareSessionResponse: Codable {
        let preparation: NextSessionPreparation
        let usage: Usage

        struct Usage: Codable {
            let totalTokens: Int
        }
    }

    /// Request payload of the prepare-session Edge Function. The previous
    /// session's assignments are optional and omitted from the JSON when nil.
    private struct PrepareSessionRequest: Encodable {
        let patientContext: PatientContext
        let lastSessionAssignments: [AssignmentForNextWeek]?
    }

    /// Asks the Edge Function to prepare the therapist for the patient's
    /// next session from the compact patient context, plus the assignments
    /// saved on the immediately previous session (never aggregated across
    /// older sessions). Returns the full response so callers can also show
    /// the token usage.
    func prepareNextSession(
        patientContext: PatientContext,
        lastSessionAssignments: [AssignmentForNextWeek]? = nil
    ) async throws -> PrepareSessionResponse {
        AppLog.ai.info("Next-session preparation requested")
        do {
            let response: PrepareSessionResponse =
                try await client.functions.invoke(
                    "prepare-session",
                    options: FunctionInvokeOptions(
                        body: PrepareSessionRequest(
                            patientContext: patientContext,
                            lastSessionAssignments: lastSessionAssignments
                        )
                    )
                )
            AppLog.ai.info("Next-session preparation succeeded, tokens: \(response.usage.totalTokens)")
            return response
        } catch let error as APIError {
            AppLog.ai.error("Next-session preparation failed: \(error.localizedDescription, privacy: .public)")
            throw error
        } catch let error as FunctionsError {
            if case .httpError(_, let data) = error,
               let serverError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.server(serverError.error)
            }
            throw APIError.server(error.localizedDescription)
        } catch {
            throw APIError.server(error.localizedDescription)
        }
    }

    // MARK: - Challenge My Formulation

    /// Asks the Edge Function to critically examine the therapist's own
    /// formulation against the patient's longitudinal context. Read-only
    /// supervision: the result is never written back into the formulation.
    /// The function returns the supervision object directly (no envelope).
    func challengeFormulation(
        patientContext: PatientContext,
        formulation: PatientFormulation
    ) async throws -> FormulationSupervision {
        AppLog.ai.info("Formulation supervision requested")
        do {
            let supervision: FormulationSupervision =
                try await client.functions.invoke(
                    "challenge-formulation",
                    options: FunctionInvokeOptions(
                        body: ChallengeFormulationRequest(
                            patientContext: patientContext,
                            formulation: formulation
                        )
                    )
                )
            AppLog.ai.info("Formulation supervision succeeded")
            return supervision
        } catch let error as APIError {
            AppLog.ai.error("Formulation supervision failed: \(error.localizedDescription, privacy: .public)")
            throw error
        } catch let error as FunctionsError {
            if case .httpError(_, let data) = error,
               let serverError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.server(serverError.error)
            }
            throw APIError.server(error.localizedDescription)
        } catch {
            throw APIError.server(error.localizedDescription)
        }
    }

    // MARK: - What Am I Missing?

    /// Asks the Edge Function to look independently across the patient's
    /// longitudinal context for clinically meaningful patterns the therapist
    /// might be overlooking. Unlike `challengeFormulation`, the formulation
    /// is not the analytical target — the context is the primary input.
    /// Read-only supervision; an empty findings list is a valid result.
    func whatAmIMissing(
        patientContext: PatientContext
    ) async throws -> WhatAmIMissingResponse {
        AppLog.ai.info("What-am-I-missing review requested")
        do {
            let response: WhatAmIMissingResponse =
                try await client.functions.invoke(
                    "what-am-i-missing",
                    options: FunctionInvokeOptions(
                        body: WhatAmIMissingRequest(patientContext: patientContext)
                    )
                )
            AppLog.ai.info("What-am-I-missing review succeeded, findings: \(response.findings.count)")
            return response
        } catch let error as APIError {
            AppLog.ai.error("What-am-I-missing review failed: \(error.localizedDescription, privacy: .public)")
            throw error
        } catch let error as FunctionsError {
            if case .httpError(_, let data) = error,
               let serverError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.server(serverError.error)
            }
            throw APIError.server(error.localizedDescription)
        } catch {
            throw APIError.server(error.localizedDescription)
        }
    }

    // MARK: - Longitudinal Case Review

    /// Asks the Edge Function what has changed in this case over time, what
    /// has not, and what deserves attention now. Explicitly longitudinal —
    /// distinct from session preparation and the formulation supervision
    /// features. Read-only supervision; nothing is written back anywhere.
    func longitudinalCaseReview(
        patientContext: PatientContext
    ) async throws -> LongitudinalCaseReviewResponse {
        AppLog.ai.info("Longitudinal case review requested")
        do {
            let response: LongitudinalCaseReviewResponse =
                try await client.functions.invoke(
                    "longitudinal-case-review",
                    options: FunctionInvokeOptions(
                        body: ["patientContext": patientContext]
                    )
                )
            AppLog.ai.info("Longitudinal case review succeeded")
            return response
        } catch let error as APIError {
            AppLog.ai.error("Longitudinal case review failed: \(error.localizedDescription, privacy: .public)")
            throw error
        } catch let error as FunctionsError {
            if case .httpError(_, let data) = error,
               let serverError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.server(serverError.error)
            }
            throw APIError.server(error.localizedDescription)
        } catch {
            throw APIError.server(error.localizedDescription)
        }
    }

    enum APIError: LocalizedError {

        case invalidInput
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {

            case .invalidInput:
                return L10n.invalidInputError

            case .invalidResponse:
                return L10n.invalidServerResponseError

            case .server(let message):
                return message
            }
        }
    }
    
    
    struct APIErrorResponse: Codable, Equatable {

        let error: String
    }
}
// MARK: - Challenge My Formulation models

/// Request body of the `challenge-formulation` Edge Function.
nonisolated struct ChallengeFormulationRequest: Encodable {
    let patientContext: PatientContext
    let formulation: PatientFormulation
}

/// The AI's supervision of the therapist's formulation. Read-only clinical
/// reflection: never merged back into `PatientFormulation`. Any array may
/// be empty — finding little to challenge is a valid result.
nonisolated struct FormulationSupervision: Decodable {
    let supportingEvidence: [SupervisionPoint]
    let challengingEvidence: [SupervisionPoint]
    let possibleBlindSpots: [SupervisionPoint]
    let alternativeFormulations: [AlternativeFormulation]
    let questionsToExplore: [SuggestedQuestion]
    let treatmentImplications: [TreatmentImplication]

    enum CodingKeys: String, CodingKey {
        case supportingEvidence = "supporting_evidence"
        case challengingEvidence = "challenging_evidence"
        case possibleBlindSpots = "possible_blind_spots"
        case alternativeFormulations = "alternative_formulations"
        case questionsToExplore = "questions_to_explore"
        case treatmentImplications = "treatment_implications"
    }
}

nonisolated struct SupervisionPoint: Decodable {
    let observation: String
    let evidence: String
    let confidence: String
}

nonisolated struct AlternativeFormulation: Decodable {
    let formulation: String
    let evidence: String
    let whatItWouldExplain: String
    let confidence: String

    enum CodingKeys: String, CodingKey {
        case formulation
        case evidence
        case whatItWouldExplain = "what_it_would_explain"
        case confidence
    }
}

nonisolated struct SuggestedQuestion: Decodable {
    let question: String
    let purpose: String
    let priority: String
}

nonisolated struct TreatmentImplication: Decodable {
    let implication: String
    let rationale: String
    let priority: String
}

// MARK: - What Am I Missing? models

/// Request body of the `what-am-i-missing` Edge Function. Deliberately just
/// the context: the formulation is not a separate analytical target here.
nonisolated struct WhatAmIMissingRequest: Encodable {
    let patientContext: PatientContext
}

/// The AI's independent look across the patient's history. Read-only
/// supervision: never merged back into `PatientFormulation`. An empty
/// findings list means nothing significant stood out — a valid result.
nonisolated struct WhatAmIMissingResponse: Decodable {
    let findings: [MissingFinding]
}

/// One pattern, connection, discrepancy, or unanswered question the
/// therapist might be overlooking. `category` is one of the machine values
/// (recurring_nat, cognitive_pattern, maintaining_behavior, cbt_cycle,
/// discrepancy, persistent_symptom, repeated_situation, unexplored_theme,
/// possible_connection, treatment_opportunity, risk_review); the UI maps
/// them to friendly labels.
nonisolated struct MissingFinding: Decodable {
    let title: String
    let observation: String
    let evidence: String
    let whyItMightMatter: String
    let questionForTherapist: String
    let category: String
    let confidence: String
    let priority: String

    enum CodingKeys: String, CodingKey {
        case title
        case observation
        case evidence
        case whyItMightMatter = "why_it_might_matter"
        case questionForTherapist = "question_for_therapist"
        case category
        case confidence
        case priority
    }
}

// MARK: - Longitudinal Case Review models

/// The AI's longitudinal view of the case: what changed, what didn't, and
/// what deserves attention now. Read-only supervision — never persisted and
/// never merged into the patient's data or formulation. Any array may be
/// empty when the history doesn't support further conclusions.
nonisolated struct LongitudinalCaseReviewResponse: Decodable {
    let overallTrajectory: String
    let improvements: [LongitudinalFinding]
    let persistentDifficulties: [LongitudinalFinding]
    let recurringPatterns: [LongitudinalFinding]
    let importantChanges: [LongitudinalFinding]
    let treatmentGoalProgress: [TreatmentGoalProgress]
    let formulationEvolution: [LongitudinalFinding]
    let clinicalAttentionPoints: [LongitudinalFinding]
    let questionsForTherapist: [String]

    enum CodingKeys: String, CodingKey {
        case overallTrajectory = "overall_trajectory"
        case improvements
        case persistentDifficulties = "persistent_difficulties"
        case recurringPatterns = "recurring_patterns"
        case importantChanges = "important_changes"
        case treatmentGoalProgress = "treatment_goal_progress"
        case formulationEvolution = "formulation_evolution"
        case clinicalAttentionPoints = "clinical_attention_points"
        case questionsForTherapist = "questions_for_therapist"
    }
}

/// One longitudinal observation with its evidence and a possible (never
/// authoritative) interpretation.
nonisolated struct LongitudinalFinding: Decodable {
    let observation: String
    let evidence: String
    let interpretation: String
    let confidence: String
}

/// Progress on one treatment goal. `status` is a machine value
/// (progressing, partially_progressing, unchanged, worsening, achieved,
/// unclear); the UI maps it to a friendly label. The suggestion is an area
/// to consider, not an instruction.
nonisolated struct TreatmentGoalProgress: Decodable {
    let goal: String
    let status: String
    let currentEstimate: String
    let evidence: String
    let suggestion: String
    let confidence: String

    enum CodingKeys: String, CodingKey {
        case goal
        case status
        case currentEstimate = "current_estimate"
        case evidence
        case suggestion
        case confidence
    }
}

