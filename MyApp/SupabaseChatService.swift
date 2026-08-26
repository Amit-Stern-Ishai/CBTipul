//
//  SupabaseChatService.swift
//  CBTipul
//
//  Created by Amit Ishai on 17/08/2026.
//

import Foundation
import OSLog
import Supabase

/// One turn of an AI chat conversation.
nonisolated struct ChatTurn {
    enum Role: String {
        case user
        case assistant
    }

    let role: Role
    let content: String
}

enum OpenAIChatError: LocalizedError {
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return L10n.emptyAIResponseError
        }
    }
}

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
        try await complete(
            systemPrompt: systemPrompt,
            turns: [ChatTurn(role: .user, content: userMessage)]
        )
    }

    /// Multi-turn variant: sends the whole conversation so the model can
    /// answer follow-up questions in context.
    func complete(systemPrompt: String, turns: [ChatTurn]) async throws -> String {
        let body = GatewayRequest(
            model: "gpt-4o-mini",
            messages: [GatewayRequest.Message(role: "system", content: systemPrompt)]
                + turns.map { .init(role: $0.role.rawValue, content: $0.content) },
            temperature: 0.4
        )

        AppLog.ai.info("Chat completion requested, turns: \(turns.count)")
        do {
            let response: OpenAIResponse = try await client.functions.invoke(
                "openai-gateway",
                options: FunctionInvokeOptions(body: body)
            )

            guard let content = response.choices.first?.message.content,
                  !content.isEmpty else {
                AppLog.ai.error("Chat completion returned an empty response")
                throw OpenAIChatError.emptyResponse
            }
            AppLog.ai.info("Chat completion succeeded, answer length: \(content.count)")
            return content
        } catch let error as OpenAIChatError {
            throw error
        } catch {
            AppLog.ai.error("Chat completion failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
