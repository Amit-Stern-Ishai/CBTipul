import Foundation
import Supabase

/// Errors from the Whisper transcription API.
nonisolated enum WhisperError: LocalizedError {
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let message):
            return "Transcription failed: \(message)"
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
                "Could not read audio file: \(error.localizedDescription)"
            )
        }

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

            return response.text

        } catch let error as WhisperError {
            throw error

        } catch {
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
            let emotions: [Emotion]
            var possibleNats: [PossibleNAT]
            let behaviors: [Behavior]
            let cbtPatterns: [CBTPattern]
            let maintainingCycles: [MaintainingCycle]
            let developments: [Development]
            let therapistHypotheses: [TherapistHypothesis]
            var therapistReflections: [TherapistReflection]
            var followUpQuestions: [FollowUpQuestion]
            let unresolvedIssues: [String]

            enum CodingKeys: String, CodingKey {
                case sessionSummary = "session_summary"
                case keySituations = "key_situations"
                case emotions
                case possibleNats = "possible_nats"
                case behaviors
                case cbtPatterns = "cbt_patterns"
                case maintainingCycles = "maintaining_cycles"
                case developments
                case therapistHypotheses = "therapist_hypotheses"
                case therapistReflections = "therapist_reflections"
                case followUpQuestions = "follow_up_questions"
                case unresolvedIssues = "unresolved_issues"
            }
        }

        // MARK: - Key Situation

        struct KeySituation: Codable, Equatable {
            var situation: String
            var importance: String
        }

        // MARK: - Emotion

        struct Emotion: Codable, Equatable {
            let emotion: String
            let context: String
            let evidence: String
        }

        // MARK: - NAT

        struct PossibleNAT: Codable, Equatable {

            var thought: String
            var situation: String
            var emotion: String
            var behavior: String
            let source: String
            let confidence: String
            let possibleCognitivePatterns: [String]
            /// What the behavior leads to (e.g. brief relief that reinforces
            /// the cycle). Optional: older analyses were saved without it.
            var possibleConsequence: String?

            enum CodingKeys: String, CodingKey {
                case thought
                case situation
                case emotion
                case behavior
                case source
                case confidence
                case possibleCognitivePatterns =
                    "possible_cognitive_patterns"
                case possibleConsequence =
                    "possible_consequence"
            }
        }

        // MARK: - Behavior

        struct Behavior: Codable, Equatable {

            let behavior: String
            let type: String
            let context: String
            let possibleFunction: String

            enum CodingKeys: String, CodingKey {
                case behavior
                case type
                case context
                case possibleFunction =
                    "possible_function"
            }
        }

        // MARK: - CBT Pattern

        struct CBTPattern: Codable, Equatable {
            let pattern: String
            let evidence: String
            let confidence: String
        }

        // MARK: - Maintaining Cycle

        struct MaintainingCycle: Codable, Equatable {
            let cycle: String
            let evidence: String
            let confidence: String
        }

        // MARK: - Development

        struct Development: Codable, Equatable {
            let development: String
            let significance: String
        }

        // MARK: - Therapist Hypothesis

        struct TherapistHypothesis: Codable, Equatable {
            let hypothesis: String
            let evidence: String
            let confidence: String
        }

        // MARK: - Therapist Reflection

        struct TherapistReflection: Codable, Equatable {

            var observation: String
            var whyItMayMatter: String
            var questionToExplore: String
            let confidence: String

            enum CodingKeys: String, CodingKey {
                case observation
                case whyItMayMatter =
                    "why_it_may_matter"
                case questionToExplore =
                    "question_to_explore"
                case confidence
            }
        }

        // MARK: - Follow-up Question

        struct FollowUpQuestion: Codable, Equatable {

            var question: String
            var reason: String
            let category: String
            let priority: String
            /// The therapist's triage of the question, set in the app after
            /// the session — never returned by the AI.
            var status: Status?

            enum Status: String, Codable, Equatable {
                case discussed
                case followUp = "follow_up"
                case notRelevant = "not_relevant"
            }
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
                    "Session analysis failed"
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

            return result.analysis
        }
    
    // MARK: - Prepare Next Session

    /// The Edge Function's preparation for the patient's next session,
    /// matching the prepare-session response schema exactly.
    struct NextSessionPreparation: Decodable {

        let executiveSummary: String
        let whatChanged: [WhatChanged]
        let priorityFollowUps: [PriorityFollowUp]
        let recurringNats: [RecurringNAT]
        let cbtCycles: [CBTCycle]
        let questionnaireInsights: [QuestionnaireInsight]
        let supervisoryObservations: [SupervisoryObservation]
        let possibleTreatmentFocus: [TreatmentFocus]
        let suggestedQuestions: [SuggestedQuestion]
        let unresolvedIssues: [String]
        let coreBeliefHypothesis: CoreBeliefHypothesis?

        enum CodingKeys: String, CodingKey {
            case executiveSummary = "executive_summary"
            case whatChanged = "what_changed"
            case priorityFollowUps = "priority_follow_ups"
            case recurringNats = "recurring_nats"
            case cbtCycles = "cbt_cycles"
            case questionnaireInsights = "questionnaire_insights"
            case supervisoryObservations = "supervisory_observations"
            case possibleTreatmentFocus = "possible_treatment_focus"
            case suggestedQuestions = "suggested_questions"
            case unresolvedIssues = "unresolved_issues"
            case coreBeliefHypothesis = "core_belief_hypothesis"
        }

        struct WhatChanged: Decodable {
            let observation: String
            let evidence: String
            let significance: String
        }

        struct PriorityFollowUp: Decodable {
            let item: String
            let reason: String
            let source: String
            let priority: String
        }

        struct RecurringNAT: Decodable {
            let thought: String
            let situations: [String]
            let cognitivePatterns: [String]
            let evidence: String
            let confidence: String

            enum CodingKeys: String, CodingKey {
                case thought
                case situations
                case cognitivePatterns = "cognitive_patterns"
                case evidence
                case confidence
            }
        }

        struct CoreBeliefHypothesis: Decodable {
            let belief: String
            let evidence: [String]
            let confidence: String
        }

        /// One hypothesized maintenance cycle. Stages the AI could not
        /// evidence are null and simply omitted from display.
        struct CBTCycle: Decodable {
            let triggerSituation: String?
            let automaticThought: String?
            let emotion: String?
            let behavior: String?
            let shortTermConsequence: String?
            let longTermConsequence: String?
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

        struct QuestionnaireInsight: Decodable {
            let observation: String
            let evidence: String
            let clinicalRelevance: String

            enum CodingKeys: String, CodingKey {
                case observation
                case evidence
                case clinicalRelevance = "clinical_relevance"
            }
        }

        struct SupervisoryObservation: Decodable {
            let observation: String
            let whyItMatters: String
            let questionForTherapist: String
            let confidence: String

            enum CodingKeys: String, CodingKey {
                case observation
                case whyItMatters = "why_it_matters"
                case questionForTherapist = "question_for_therapist"
                case confidence
            }
        }

        struct TreatmentFocus: Decodable {
            let focus: String
            let rationale: String
            let priority: String
        }

        struct SuggestedQuestion: Decodable {
            let question: String
            let purpose: String
            let priority: String
        }
    }

    struct PrepareSessionResponse: Decodable {
        let preparation: NextSessionPreparation
        let usage: Usage

        struct Usage: Decodable {
            let totalTokens: Int
        }
    }

    /// Asks the Edge Function to prepare the therapist for the patient's
    /// next session from the compact patient context. Returns the full
    /// response so callers can also show the token usage.
    func prepareNextSession(patientContext: PatientContext) async throws -> PrepareSessionResponse {
        do {
            let response: PrepareSessionResponse =
                try await client.functions.invoke(
                    "prepare-session",
                    options: FunctionInvokeOptions(
                        body: ["patientContext": patientContext]
                    )
                )
            return response
        } catch let error as APIError {
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
                return "Invalid input."

            case .invalidResponse:
                return "Invalid response from server."

            case .server(let message):
                return message
            }
        }
    }
    
    
    struct APIErrorResponse: Codable, Equatable {

        let error: String
    }
}
