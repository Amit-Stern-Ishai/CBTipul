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

    private struct TranscriptionResponse: Decodable {
        let text: String
    }
    
    struct SessionReviewResponse: Decodable {

            let analysis: CBTSessionAnalysis
            let usage: Usage

            struct Usage: Decodable {
                let totalTokens: Int
            }
        }

        // MARK: - CBT Session Analysis

        struct CBTSessionAnalysis: Decodable {

            let sessionSummary: String

            let keySituations: [KeySituation]
            let emotions: [Emotion]
            let possibleNats: [PossibleNAT]
            let behaviors: [Behavior]
            let cbtPatterns: [CBTPattern]
            let maintainingCycles: [MaintainingCycle]
            let developments: [Development]
            let therapistHypotheses: [TherapistHypothesis]
            let therapistReflections: [TherapistReflection]
            let followUpQuestions: [FollowUpQuestion]
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

        struct KeySituation: Decodable {
            let situation: String
            let importance: String
        }

        // MARK: - Emotion

        struct Emotion: Decodable {
            let emotion: String
            let context: String
            let evidence: String
        }

        // MARK: - NAT

        struct PossibleNAT: Decodable {

            let thought: String
            let situation: String
            let emotion: String
            let behavior: String
            let source: String
            let confidence: String
            let possibleCognitivePatterns: [String]

            enum CodingKeys: String, CodingKey {
                case thought
                case situation
                case emotion
                case behavior
                case source
                case confidence
                case possibleCognitivePatterns =
                    "possible_cognitive_patterns"
            }
        }

        // MARK: - Behavior

        struct Behavior: Decodable {

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

        struct CBTPattern: Decodable {
            let pattern: String
            let evidence: String
            let confidence: String
        }

        // MARK: - Maintaining Cycle

        struct MaintainingCycle: Decodable {
            let cycle: String
            let evidence: String
            let confidence: String
        }

        // MARK: - Development

        struct Development: Decodable {
            let development: String
            let significance: String
        }

        // MARK: - Therapist Hypothesis

        struct TherapistHypothesis: Decodable {
            let hypothesis: String
            let evidence: String
            let confidence: String
        }

        // MARK: - Therapist Reflection

        struct TherapistReflection: Decodable {

            let observation: String
            let whyItMayMatter: String
            let questionToExplore: String
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

        struct FollowUpQuestion: Decodable {

            let question: String
            let reason: String
            let category: String
            let priority: String
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
    
    
    struct APIErrorResponse: Decodable {

        let error: String
    }
}
