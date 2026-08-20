//import Foundation
//
///// Errors from the Whisper transcription API.
//nonisolated enum WhisperError: LocalizedError {
//    case requestFailed(String)
//
//    var errorDescription: String? {
//        switch self {
//        case .requestFailed(let message):
//            return "Transcription failed: \(message)"
//        }
//    }
//}
//
///// Sends recorded audio to OpenAI Whisper and returns the transcribed text.
//nonisolated enum WhisperService {
//    private static let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
//
//    /// Transcribes the audio file at `fileURL`. `language` is an ISO-639-1
//    /// code; Hebrew by default since that's what sessions are held in.
//    static func transcribe(fileURL: URL, language: String = "he") async throws -> String {
//        let boundary = "Boundary-\(UUID().uuidString)"
//
//        var request = URLRequest(url: endpoint)
//        request.httpMethod = "POST"
//        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
//        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
//
//        var body = Data()
//        body.appendText("--\(boundary)\r\n")
//        body.appendText("Content-Disposition: form-data; name=\"model\"\r\n\r\nwhisper-1\r\n")
//        body.appendText("--\(boundary)\r\n")
//        body.appendText("Content-Disposition: form-data; name=\"language\"\r\n\r\n\(language)\r\n")
//        body.appendText("--\(boundary)\r\n")
//        body.appendText("Content-Disposition: form-data; name=\"file\"; filename=\"voice-note.m4a\"\r\n")
//        body.appendText("Content-Type: audio/m4a\r\n\r\n")
//        body.append(try Data(contentsOf: fileURL))
//        body.appendText("\r\n--\(boundary)--\r\n")
//
//        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
//        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
//            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
//            throw WhisperError.requestFailed(message)
//        }
//
//        struct TranscriptionResponse: Decodable {
//            let text: String
//        }
//        return try JSONDecoder().decode(TranscriptionResponse.self, from: data).text
//    }
//}
//
//private extension Data {
//    mutating func appendText(_ string: String) {
//        append(Data(string.utf8))
//    }
//}
