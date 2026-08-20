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
}
