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
