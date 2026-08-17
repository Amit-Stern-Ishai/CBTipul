//
//  SupabaseChatService.swift
//  CBTipul
//
//  Created by Amit Ishai on 17/08/2026.
//

import Foundation
import Supabase

/// Calls OpenAI chat through the `openai-gateway` Supabase Edge Function,
/// so the OpenAI API key stays on the server instead of in the app.
/// (Image text extraction still calls OpenAI directly.)
nonisolated struct SupabaseChatService {
    let client: SupabaseClient

    /// Request body forwarded by the gateway to OpenAI.
    private struct GatewayRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
    }

    private struct OpenAIResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }
            let message: Message
        }

        let choices: [Choice]
    }

    func complete(systemPrompt: String, userMessage: String) async throws -> String {
        let body = GatewayRequest(
            model: "gpt-4o-mini",
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userMessage),
            ],
            temperature: 0.4
        )

        let response: OpenAIResponse = try await client.functions.invoke(
            "openai-gateway",
            options: FunctionInvokeOptions(body: body)
        )

        guard let content = response.choices.first?.message.content,
              !content.isEmpty else {
            throw OpenAIChatError.emptyResponse
        }
        return content
    }
}
