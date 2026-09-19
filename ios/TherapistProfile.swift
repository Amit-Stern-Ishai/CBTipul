import Foundation
import OSLog
import Supabase

/// Whether the therapist must provide a patient-facing display name
/// before continuing, or may skip.
enum TherapistDisplayNameRequirement {
    /// Post-sign-in prompt. Save or "לא עכשיו".
    case optional
    /// Future invitation (and Settings add/edit). Save or cancel/back —
    /// never skip and continue a protected action.
    case required
}

enum TherapistProfileError: LocalizedError {
    case notSignedIn
    case emptyDisplayName
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return L10n.therapistDisplayNameNotSignedInError
        case .emptyDisplayName:
            return L10n.therapistDisplayNameEmptyError
        case .saveFailed:
            return L10n.therapistDisplayNameSaveError
        }
    }
}

/// A row in `public.therapist_profiles`. Patient-facing therapist
/// identity only — never patient data.
nonisolated struct TherapistProfile: Codable, Equatable, Sendable {
    var therapistId: UUID
    var displayName: String

    enum CodingKeys: String, CodingKey {
        case therapistId = "therapist_id"
        case displayName = "display_name"
    }

    var hasValidDisplayName: Bool {
        Self.isValid(displayName)
    }

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValid(_ raw: String) -> Bool {
        !normalized(raw).isEmpty
    }
}

/// Reads and writes the signed-in therapist's `therapist_profiles` row
/// through the shared authenticated Supabase client (RLS).
@Observable
@MainActor
final class TherapistProfileService {
    private let client: SupabaseClient

    /// Last successfully fetched or saved profile for the current session.
    private(set) var cachedProfile: TherapistProfile?

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Current profile, or `nil` if no row exists yet.
    /// Invitation flow: present required editor when this returns `false`.
    func hasValidDisplayName() async throws -> Bool {
        try await getCurrentProfile()?.hasValidDisplayName == true
    }

    /// Current profile, or `nil` if no row exists yet.
    func getCurrentProfile() async throws -> TherapistProfile? {
        try ensureConfigured()
        let userId = try await requireUserId()
        do {
            let rows: [TherapistProfile] = try await client.from("therapist_profiles")
                .select("therapist_id, display_name")
                .eq("therapist_id", value: userId.uuidString.lowercased())
                .limit(1)
                .execute()
                .value
            let profile = rows.first
            cachedProfile = profile
            return profile
        } catch {
            AppLog.store.error(
                "Therapist profile fetch failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    /// Inserts or updates `display_name` for the signed-in therapist.
    /// Empty/whitespace-only names are rejected and not written.
    func saveDisplayName(_ raw: String) async throws -> TherapistProfile {
        try ensureConfigured()
        let trimmed = TherapistProfile.normalized(raw)
        guard TherapistProfile.isValid(trimmed) else {
            throw TherapistProfileError.emptyDisplayName
        }
        let userId = try await requireUserId()
        let record = TherapistProfile(therapistId: userId, displayName: trimmed)
        do {
            let saved: TherapistProfile = try await client.from("therapist_profiles")
                .upsert(record, onConflict: "therapist_id")
                .select("therapist_id, display_name")
                .single()
                .execute()
                .value
            cachedProfile = saved
            AppLog.store.info("Therapist display name saved")
            return saved
        } catch {
            AppLog.store.error(
                "Therapist display name save failed: \(error.localizedDescription, privacy: .public)"
            )
            throw TherapistProfileError.saveFailed
        }
    }

    func clearCache() {
        cachedProfile = nil
    }

    private func requireUserId() async throws -> UUID {
        do {
            return try await client.auth.session.user.id
        } catch {
            throw TherapistProfileError.notSignedIn
        }
    }

    private func ensureConfigured() throws {
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
    }
}
