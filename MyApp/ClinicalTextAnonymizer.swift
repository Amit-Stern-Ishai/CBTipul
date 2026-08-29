import Foundation
import OSLog
import Supabase

/// Errors from the clinical-text anonymization Edge Function.
nonisolated enum ClinicalTextAnonymizerError: LocalizedError {
    case anonymizationFailed

    var errorDescription: String? {
        L10n.anonymizationFailedError
    }
}

/// Sends patient-related free text to the `anonymize-clinical-text` Edge
/// Function and returns the anonymized replacement.
///
/// No user-entered clinical free text may be written to Supabase before it
/// has passed through here — on any failure the caller must abort the save,
/// never fall back to the original text.
nonisolated struct ClinicalTextAnonymizer {

    let client: SupabaseClient

    /// Identifiers of the authenticated therapist (never of a patient) that
    /// the function should treat as known, e.g. the therapist's display
    /// name. The app currently stores no therapist name, so this stays
    /// empty until one exists.
    var therapistIdentifiers: [String] = []

    private struct Request: Encodable {
        let text: String
        let therapistIdentifiers: [String]
    }

    private struct Response: Decodable {
        let anonymizedText: String
        let usage: Usage?

        struct Usage: Decodable {
            let totalTokens: Int
        }
    }

    /// Anonymizes the text. Input that is empty after trimming returns an
    /// empty string without calling the function; a failed call, invalid
    /// response, or empty result throws `ClinicalTextAnonymizerError`.
    ///
    /// The clinical text itself — original or anonymized — is never logged.
    func anonymize(_ text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        AppLog.ai.info("Anonymization requested, characters: \(trimmed.count)")
        let response: Response
        do {
            response = try await client.functions.invoke(
                "anonymize-clinical-text",
                options: FunctionInvokeOptions(
                    body: Request(text: trimmed, therapistIdentifiers: therapistIdentifiers)
                )
            )
        } catch {
            AppLog.ai.error("Anonymization failed: \(error.localizedDescription, privacy: .public)")
            throw ClinicalTextAnonymizerError.anonymizationFailed
        }

        let anonymized = response.anonymizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !anonymized.isEmpty else {
            AppLog.ai.error("Anonymization returned an empty result")
            throw ClinicalTextAnonymizerError.anonymizationFailed
        }
        AppLog.ai.info("Anonymization succeeded, tokens: \(response.usage?.totalTokens ?? 0)")
        return anonymized
    }
}

/// Decides which texts still need anonymization before being persisted to
/// Supabase, so unchanged text that was already safely stored is never
/// reprocessed and new or edited text always is.
///
/// Texts loaded back from Supabase and texts returned by the anonymizer are
/// remembered as safe; everything else must pass through the anonymize
/// closure before it may be uploaded. Lives in the persistence layer
/// (`PatientStore`) so no screen can accidentally bypass it. A main-actor
/// class (not a struct): its async methods must mutate the safe set across
/// suspension points, which actor-isolated struct properties disallow.
@MainActor
final class ClinicalTextGate {

    /// Runs one text through the Edge Function. Injectable so tests can
    /// substitute a mock anonymizer.
    private let anonymize: @Sendable (String) async throws -> String

    /// Trimmed texts that are already safe to persist remotely.
    private var safeTexts: Set<String> = []

    init(anonymize: @escaping @Sendable (String) async throws -> String) {
        self.anonymize = anonymize
    }

    /// Remembers text that is already stored on the backend (or otherwise
    /// known safe) so re-saving it unchanged skips the Edge Function.
    func markSafe(_ text: String?) {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return }
        safeTexts.insert(trimmed)
    }

    /// The value to persist for one field: `nil` for empty input, the text
    /// itself when it is already safe, otherwise the anonymized replacement.
    /// Throws without any fallback when anonymization fails.
    func prepare(_ text: String) async throws -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if safeTexts.contains(trimmed) { return trimmed }
        let anonymized = try await anonymize(trimmed)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !anonymized.isEmpty else { throw ClinicalTextAnonymizerError.anonymizationFailed }
        safeTexts.insert(anonymized)
        return anonymized
    }

    /// Prepares independent per-question notes, keeping each note at its own
    /// index. Empty slots stay empty without calling the function.
    func prepare(notes: [String]) async throws -> [String] {
        var result: [String] = []
        for note in notes {
            result.append(try await prepare(note) ?? "")
        }
        return result
    }
}
