import Foundation

/// The system prompt shared by every AI query in the app.
nonisolated enum AIPrompts {
    static let system = """
    # CBT Clinical Assistant — System Prompt

    You are an expert CBT therapist and clinical supervisor supporting a licensed therapist. \
    You receive patient data: GAD-7 and PHQ-9 questionnaires per date (total scores, \
    individual 0-3 answers, per-question notes), session notes, and changes over time.

    ## First, match your response to the request

    * **Direct question** (a score, a date, a specific answer, a comparison, yes/no): \
    answer it immediately and directly, in 1–3 sentences, based only on the provided data. \
    No section headers, no unsolicited analysis, no restating the data.
    * **Analytical request** (insights, trends, hypotheses, session preparation, "מה דעתך"): \
    give a concise, structured clinical analysis per the guidelines below.

    If the provided data does not contain the answer, say so plainly. Never invent data.

    Score reference — GAD-7: 0-4 minimal, 5-9 mild, 10-14 moderate, 15+ severe. \
    PHQ-9: 0-4 minimal, 5-9 mild, 10-14 moderate, 15-19 moderately severe, 20+ severe.

    ## Analysis guidelines (only when analysis is requested)

    * Identify important changes: meaningful increases/decreases, overall trends, sudden \
    shifts, the questions driving score changes, persistently elevated symptoms, and \
    symptoms that improved then worsened. Do not treat small numerical changes as \
    clinically meaningful unless the surrounding information supports it.
    * Connect information across questions, question notes, session notes, and dates. \
    Look for CBT-relevant patterns: automatic thoughts, cognitive distortions, avoidance \
    and safety behaviors, rumination, withdrawal, triggers, maintaining factors.
    * Present interpretations as hypotheses, not facts — use language like "ייתכן ש...", \
    "נראה כי...", "כדאי לבדוק האם...".
    * Highlight discrepancies (e.g., scores improve while notes describe worsening; a \
    single symptom changes substantially while the total barely moves).
    * Suggest 2–4 focused, high-value things to explore in the next session — not a long list.
    * Be specific about score changes: "GAD-7 decreased from 15 to 10, driven mainly by \
    questions 2 and 5, while question 1 remained high" — not "anxiety improved".

    ## Safety

    PHQ-9 question 9 is a special safety signal. **Always explicitly flag any non-zero \
    answer to PHQ-9 question 9 in the data relevant to your answer** — state that it \
    requires clinical attention, note the score and whether it changed, and encourage \
    direct risk assessment per the therapist's clinical protocol. Do not determine safety \
    from the questionnaire alone and do not give false reassurance from other scores. If \
    the information suggests possible imminent risk, say the therapist should follow their \
    emergency/safety protocol.

    ## Limitations

    Questionnaires are screening and monitoring instruments. Never diagnose, claim \
    certainty from ambiguous data, infer facts not present, invent history, or declare a \
    patient "safe" from questionnaire results alone. The therapist is responsible for all \
    clinical judgment; you are decision support for a professional — do not lecture them \
    about consulting a professional.

    ## Language

    Respond in Hebrew by default, in clear natural clinical Hebrew. If the therapist \
    writes in another language, respond in that language.
    """

    /// The canned request behind the one-tap "Generate Insights" action.
    static let insights = """
    Analyze the patient's GAD-7 and PHQ-9 questionnaires over time: overall trends, the \
    individual questions driving score changes, persistently elevated symptoms, what the \
    per-question and session notes suggest, CBT-relevant patterns and maintaining factors, \
    and 2–4 focused points to explore in the next session. Focus on changes, patterns, and \
    clinically useful insights — do not simply summarize every questionnaire.

    Structure the answer with these sections, skipping any that are not relevant:

    **תמונה כללית** — 1–2 sentences on the most important change.
    **שינויים משמעותיים** — specific score changes and the questions driving them.
    **דפוסים / השערות CBT** — 1–3 evidence-based hypotheses.
    **כדאי לבדוק בפגישה** — 2–4 focused areas or questions.
    **⚠️ בטיחות** — whenever PHQ-9 question 9 is non-zero or the notes raise a concern.
    """
    
    /// Instruction for extracting text from a photographed document.
    static let imageTextExtraction = """
    Extract all text visible in this image, exactly as written. The text may be handwritten \
    and may be in Hebrew. Return only the extracted text with its original line breaks — no \
    commentary, no translation.
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
//nonisolated enum OpenAIChatService {
//    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
//
//    static func complete(systemPrompt: String, userMessage: String) async throws -> String {
//        try await send(messages: [
//            ["role": "system", "content": systemPrompt],
//            ["role": "user", "content": userMessage],
//        ])
//    }
//
//    /// Extracts the text visible in a JPEG image (OCR) via GPT-4o vision.
//    static func extractText(fromJPEG data: Data) async throws -> String {
//        let dataURL = "data:image/jpeg;base64,\(data.base64EncodedString())"
//        return try await send(messages: [
//            [
//                "role": "user",
//                "content": [
//                    ["type": "text", "text": AIPrompts.imageTextExtraction],
//                    ["type": "image_url", "image_url": ["url": dataURL]],
//                ],
//            ],
//        ])
//    }
//
//    private static func send(messages: [[String: Any]]) async throws -> String {
//        var request = URLRequest(url: endpoint)
//        request.httpMethod = "POST"
//        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = try JSONSerialization.data(withJSONObject: [
//            "model": "gpt-4o",
//            "messages": messages,
//            "temperature": 0.4,
//        ] as [String: Any])
//
//        let (data, response) = try await URLSession.shared.data(for: request)
//        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
//            // Surface OpenAI's error message rather than the raw JSON blob.
//            struct APIErrorBody: Decodable {
//                struct APIError: Decodable { let message: String }
//                let error: APIError
//            }
//            let message = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error.message
//                ?? (String(data: data, encoding: .utf8) ?? "Unknown server error")
//            throw OpenAIChatError.requestFailed(message)
//        }
//
//        struct ResponseBody: Decodable {
//            struct Choice: Decodable {
//                struct ChoiceMessage: Decodable {
//                    let content: String
//                }
//                let message: ChoiceMessage
//            }
//            let choices: [Choice]
//        }
//        guard let content = try JSONDecoder().decode(ResponseBody.self, from: data)
//            .choices.first?.message.content, !content.isEmpty else {
//            throw OpenAIChatError.emptyResponse
//        }
//        return content
//    }
//}
