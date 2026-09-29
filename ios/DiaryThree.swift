import Foundation
import OSLog
import Supabase


nonisolated struct DiaryThreeAutomaticThought: Codable, Equatable, Sendable {
    var text: String
    var beliefBefore: Int
    var beliefAfter: Int
}
nonisolated struct DiaryThreeFeeling: Codable, Equatable, Sendable {
    var name: String
    var intensityBefore: Int
    var intensityAfter: Int
}
nonisolated struct DiaryThreeAlternativeThought: Codable, Equatable, Sendable {
    var text: String
    var belief: Int
}

/// One Diary 3 record for a Patient. Not tied to a Session or assignment.
nonisolated struct DiaryThreeEntry: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let patientId: DatabaseID
    let therapistId: UUID
    let createdBy: DiaryOneEntryCreator
    var situation: String
    var automaticThoughts: [DiaryThreeAutomaticThought]
    var feelings: [DiaryThreeFeeling]
    var thinkingErrors: [ThinkingError]
    var alternativeThoughts: [DiaryThreeAlternativeThought]
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case therapistId = "therapist_id"
        case createdBy = "created_by"
        case situation
        case automaticThoughts = "automatic_thoughts"
        case feelings
        case thinkingErrors = "thinking_errors"
        case alternativeThoughts = "alternative_thoughts"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var automaticThoughtsPreview: String {
        L10n.diaryAutomaticThoughtsPreview(automaticThoughts.map(\.text))
    }
}

struct NewDiaryThreeEntry: Encodable {
    let patientId: UUID
    let therapistId: UUID
    let createdBy: DiaryOneEntryCreator
    let situation: String
    let automaticThoughts: [DiaryThreeAutomaticThought]
    let feelings: [DiaryThreeFeeling]
    let thinkingErrors: [ThinkingError]
    let alternativeThoughts: [DiaryThreeAlternativeThought]

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case therapistId = "therapist_id"
        case createdBy = "created_by"
        case situation, feelings
        case thinkingErrors = "thinking_errors"
        case automaticThoughts = "automatic_thoughts"
        case alternativeThoughts = "alternative_thoughts"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patientId, forKey: .patientId)
        try container.encode(therapistId, forKey: .therapistId)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(situation, forKey: .situation)
        try container.encode(automaticThoughts, forKey: .automaticThoughts)
        try container.encode(feelings, forKey: .feelings)
        try container.encode(thinkingErrors, forKey: .thinkingErrors)
        try container.encode(alternativeThoughts, forKey: .alternativeThoughts)
    }
}

struct DiaryThreeEntryClinicalUpdate: Encodable {
    let situation: String
    let automaticThoughts: [DiaryThreeAutomaticThought]
    let feelings: [DiaryThreeFeeling]
    let thinkingErrors: [ThinkingError]
    let alternativeThoughts: [DiaryThreeAlternativeThought]
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case situation, feelings
        case thinkingErrors = "thinking_errors"
        case automaticThoughts = "automatic_thoughts"
        case alternativeThoughts = "alternative_thoughts"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(situation, forKey: .situation)
        try container.encode(automaticThoughts, forKey: .automaticThoughts)
        try container.encode(feelings, forKey: .feelings)
        try container.encode(thinkingErrors, forKey: .thinkingErrors)
        try container.encode(alternativeThoughts, forKey: .alternativeThoughts)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

private struct DeletedDiaryThreeRow: Decodable {
    let id: UUID
}

let diaryThreeSelectColumns =
    "id, patient_id, therapist_id, created_by, situation, automatic_thoughts, feelings, thinking_errors, alternative_thoughts, created_at, updated_at"

/// Therapist CRUD for `public.diary_three_entries`. RLS is the authorization
/// boundary. Demo clinic IDs stay in memory because they are not UUIDs.
@Observable
@MainActor
final class DiaryThreeStore {
    private let client: SupabaseClient
    private var entriesByPatient: [String: [DiaryThreeEntry]] = [:]
    /// Demo clinic only — not used for real patients.
    private var demoEntriesByPatient: [String: [DiaryThreeEntry]] = [:]

    init(client: SupabaseClient) {
        self.client = client
    }

    func entries(for patientId: DatabaseID) -> [DiaryThreeEntry] {
        cached(for: patientId)
    }

    func loadEntries(for patientId: DatabaseID) async throws -> [DiaryThreeEntry] {
        if DemoData.isDemoID(patientId) {
            return cached(for: patientId)
        }
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let patientUUID = patientId.uuidValue else {
            throw AuthError.notConfigured
        }
        do {
            let rows: [DiaryThreeEntry] = try await client.from("diary_three_entries")
                .select(diaryThreeSelectColumns)
                .eq("patient_id", value: patientUUID)
                .order("created_at", ascending: false)
                .execute()
                .value
            entriesByPatient[patientId.queryValue] = rows
            AppLog.store.info("Diary 3 entries loaded")
            return rows
        } catch {
            AppLog.store.error(
                "Diary 3 load failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    func createEntry(
        patientId: DatabaseID,
        situation: String,
        automaticThoughts: [DiaryThreeAutomaticThought],
        feelings: [DiaryThreeFeeling],
        thinkingErrors: [ThinkingError],
        alternativeThoughts: [DiaryThreeAlternativeThought]
    ) async throws -> DiaryThreeEntry {
        if DemoData.isDemoID(patientId) {
            let entry = DiaryThreeEntry(
                id: UUID(),
                patientId: patientId,
                therapistId: UUID(),
                createdBy: .therapist,
                situation: situation,
                automaticThoughts: automaticThoughts,
                feelings: feelings,
                thinkingErrors: thinkingErrors,
                alternativeThoughts: alternativeThoughts,
                createdAt: .now,
                updatedAt: .now
            )
            upsertCache(entry)
            return entry
        }
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let patientUUID = patientId.uuidValue else { throw AuthError.notConfigured }
        let therapistId = try await requireTherapistId()
        do {
            let saved: DiaryThreeEntry = try await client.from("diary_three_entries")
                .insert(
                    NewDiaryThreeEntry(
                        patientId: patientUUID,
                        therapistId: therapistId,
                        createdBy: .therapist,
                        situation: situation,
                        automaticThoughts: automaticThoughts,
                        feelings: feelings,
                        thinkingErrors: thinkingErrors,
                        alternativeThoughts: alternativeThoughts
                    )
                )
                .select(diaryThreeSelectColumns)
                .single()
                .execute()
                .value
            upsertCache(saved)
            AppLog.store.info("Diary 3 entry created")
            return saved
        } catch {
            AppLog.store.error(
                "Diary 3 create failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    func updateEntry(
        id: UUID,
        patientId: DatabaseID,
        situation: String,
        automaticThoughts: [DiaryThreeAutomaticThought],
        feelings: [DiaryThreeFeeling],
        thinkingErrors: [ThinkingError],
        alternativeThoughts: [DiaryThreeAlternativeThought]
    ) async throws -> DiaryThreeEntry {
        if DemoData.isDemoID(patientId) {
            guard var entry = cached(for: patientId).first(where: { $0.id == id }) else {
                throw AuthError.notConfigured
            }
            entry.situation = situation
            entry.automaticThoughts = automaticThoughts
            entry.feelings = feelings
            entry.thinkingErrors = thinkingErrors
            entry.alternativeThoughts = alternativeThoughts
            entry.updatedAt = .now
            upsertCache(entry)
            return entry
        }
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        do {
            let saved: DiaryThreeEntry = try await client.from("diary_three_entries")
                .update(
                    DiaryThreeEntryClinicalUpdate(
                        situation: situation,
                        automaticThoughts: automaticThoughts,
                        feelings: feelings,
                        thinkingErrors: thinkingErrors,
                        alternativeThoughts: alternativeThoughts,
                        updatedAt: Self.timestampString(from: Date())
                    )
                )
                .eq("id", value: id)
                .eq("patient_id", value: patientId.queryValue)
                .select(diaryThreeSelectColumns)
                .single()
                .execute()
                .value
            upsertCache(saved)
            AppLog.store.info("Diary 3 entry updated")
            return saved
        } catch {
            AppLog.store.error(
                "Diary 3 update failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    func deleteEntry(id: UUID, patientId: DatabaseID) async throws {
        if DemoData.isDemoID(patientId) {
            var list = cached(for: patientId)
            list.removeAll { $0.id == id }
            storeCache(list, for: patientId)
            return
        }
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        do {
            let deleted: [DeletedDiaryThreeRow] = try await client.from("diary_three_entries")
                .delete()
                .eq("id", value: id)
                .eq("patient_id", value: patientId.queryValue)
                .select("id")
                .execute()
                .value
            guard !deleted.isEmpty else {
                throw AuthError.notConfigured
            }
            var list = cached(for: patientId)
            list.removeAll { $0.id == id }
            storeCache(list, for: patientId)
            AppLog.store.info("Diary 3 entry deleted")
        } catch {
            AppLog.store.error(
                "Diary 3 delete failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    private func cached(for patientId: DatabaseID) -> [DiaryThreeEntry] {
        let key = patientId.queryValue
        let list = DemoData.isDemoID(patientId)
            ? (demoEntriesByPatient[key] ?? [])
            : (entriesByPatient[key] ?? [])
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    private func upsertCache(_ entry: DiaryThreeEntry) {
        var list = cached(for: entry.patientId).filter { $0.id != entry.id }
        list.append(entry)
        storeCache(list, for: entry.patientId)
    }

    private func storeCache(_ list: [DiaryThreeEntry], for patientId: DatabaseID) {
        let sorted = list.sorted { $0.createdAt > $1.createdAt }
        if DemoData.isDemoID(patientId) {
            demoEntriesByPatient[patientId.queryValue] = sorted
        } else {
            entriesByPatient[patientId.queryValue] = sorted
        }
    }

    private func requireTherapistId() async throws -> UUID {
        try await client.auth.session.user.id
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
