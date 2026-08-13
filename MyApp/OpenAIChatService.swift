import Foundation

/// The system prompt shared by every AI query in the app.
nonisolated enum AIPrompts {
    static let system = """
    You are a master CBT (cognitive behavioral therapy) therapist and clinical supervisor, \
    expert at deducing insights about patients from GAD-7 and PHQ-9 questionnaire results, \
    per-question notes, and session notes. Analyze trends over time, call out clinically \
    significant changes — always flag any non-zero answer to PHQ-9 question 9 (self-harm) — \
    and be specific about which questions drive score changes. Be concise and structured. \
    You are a decision-support tool for a licensed therapist: do not diagnose, and remember \
    the therapist makes all clinical decisions. Respond in Hebrew unless the therapist \
    writes in another language.
    """

    /// The canned request behind the one-tap "Generate Insights" action.
    static let insights = """
    Generate clinical insights from this patient's questionnaire history: overall trends, \
    notable per-question changes, anything the notes reveal, and points worth exploring in \
    the next session.
    """
}

/// Errors from the OpenAI chat API.
nonisolated enum OpenAIChatError: LocalizedError {
    case requestFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .requestFailed(let message):
            return "AI request failed: \(message)"
        case .emptyResponse:
            return "AI request returned no content."
        }
    }
}

/// Minimal OpenAI chat-completions client used for the patient AI features.
nonisolated enum OpenAIChatService {
    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    static func complete(systemPrompt: String, userMessage: String) async throws -> String {
        struct Message: Codable {
            let role: String
            let content: String
        }
        struct RequestBody: Encodable {
            let model: String
            let messages: [Message]
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(
            model: "gpt-4o",
            messages: [
                Message(role: "system", content: systemPrompt),
                Message(role: "user", content: userMessage),
            ]
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw OpenAIChatError.requestFailed(message)
        }

        struct ResponseBody: Decodable {
            struct Choice: Decodable {
                struct ChoiceMessage: Decodable {
                    let content: String
                }
                let message: ChoiceMessage
            }
            let choices: [Choice]
        }
        guard let content = try JSONDecoder().decode(ResponseBody.self, from: data)
            .choices.first?.message.content, !content.isEmpty else {
            throw OpenAIChatError.emptyResponse
        }
        return content
    }
}
