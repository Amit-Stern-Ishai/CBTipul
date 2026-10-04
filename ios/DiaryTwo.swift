import Foundation
import OSLog
import Supabase


/// One Diary 2 record for a Patient. Not tied to a Session or assignment.
nonisolated struct DiaryTwoEntry: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let patientId: DatabaseID
    let therapistId: UUID
    let createdBy: DiaryOneEntryCreator
    var event: String
    var automaticThoughts: [String]
    var feelings: [DiaryFeeling]
    var thinkingErrors: [ThinkingError]
    var alternativeThoughts: [String]
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case therapistId = "therapist_id"
        case createdBy = "created_by"
        case event
        case automaticThoughts = "automatic_thoughts"
        case feelings
        case thinkingErrors = "thinking_errors"
        case alternativeThoughts = "alternative_thoughts"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var automaticThoughtsPreview: String {
        L10n.diaryAutomaticThoughtsPreview(automaticThoughts)
    }
}

struct NewDiaryTwoEntry: Encodable {
    let patientId: UUID
    let therapistId: UUID
    let createdBy: DiaryOneEntryCreator
    let event: String
    let automaticThoughts: [String]
    let feelings: [DiaryFeeling]
    let thinkingErrors: [ThinkingError]
    let alternativeThoughts: [String]

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case therapistId = "therapist_id"
        case createdBy = "created_by"
        case event, feelings
        case thinkingErrors = "thinking_errors"
        case automaticThoughts = "automatic_thoughts"
        case alternativeThoughts = "alternative_thoughts"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patientId, forKey: .patientId)
        try container.encode(therapistId, forKey: .therapistId)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(event, forKey: .event)
        try container.encode(automaticThoughts, forKey: .automaticThoughts)
        try container.encode(feelings, forKey: .feelings)
        try container.encode(thinkingErrors, forKey: .thinkingErrors)
        try container.encode(alternativeThoughts, forKey: .alternativeThoughts)
    }
}

struct DiaryTwoEntryClinicalUpdate: Encodable {
    let event: String
    let automaticThoughts: [String]
    let feelings: [DiaryFeeling]
    let thinkingErrors: [ThinkingError]
    let alternativeThoughts: [String]
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case event, feelings
        case thinkingErrors = "thinking_errors"
        case automaticThoughts = "automatic_thoughts"
        case alternativeThoughts = "alternative_thoughts"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(event, forKey: .event)
        try container.encode(automaticThoughts, forKey: .automaticThoughts)
        try container.encode(feelings, forKey: .feelings)
        try container.encode(thinkingErrors, forKey: .thinkingErrors)
        try container.encode(alternativeThoughts, forKey: .alternativeThoughts)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

private struct DeletedDiaryTwoRow: Decodable {
    let id: UUID
}

let diaryTwoSelectColumns =
    "id, patient_id, therapist_id, created_by, event, automatic_thoughts, feelings, thinking_errors, alternative_thoughts, created_at, updated_at"

/// Therapist CRUD for `public.diary_two_entries`. RLS is the authorization
/// boundary. Demo clinic IDs stay in memory because they are not UUIDs.
@Observable
@MainActor
final class DiaryTwoStore {
    private let client: SupabaseClient
    private var entriesByPatient: [String: [DiaryTwoEntry]] = [:]
    /// Demo clinic only — not used for real patients.
    private var demoEntriesByPatient: [String: [DiaryTwoEntry]] = [:]

    init(client: SupabaseClient) {
        self.client = client
    }

    func entries(for patientId: DatabaseID) -> [DiaryTwoEntry] {
        cached(for: patientId)
    }

    func loadEntries(for patientId: DatabaseID) async throws -> [DiaryTwoEntry] {
        if DemoData.isDemoID(patientId) {
            return cached(for: patientId)
        }
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let patientUUID = patientId.uuidValue else {
            throw AuthError.notConfigured
        }
        do {
            let rows: [DiaryTwoEntry] = try await client.from("diary_two_entries")
                .select(diaryTwoSelectColumns)
                .eq("patient_id", value: patientUUID)
                .order("created_at", ascending: false)
                .execute()
                .value
            entriesByPatient[patientId.queryValue] = rows
            AppLog.store.info("Diary 2 entries loaded")
            return rows
        } catch {
            AppLog.store.error(
                "Diary 2 load failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    /// Notification targets must be fetched using both identifiers, even if cached.
    func loadEntry(id: UUID, patientId: DatabaseID) async throws -> DiaryTwoEntry? {
        if DemoData.isDemoID(patientId) {
            return DiaryTwoEntryLookup.accepted(cached(for: patientId).first { $0.id == id }, id: id, patientId: patientId)
        }
        guard let patientUUID = patientId.uuidValue else { return nil }
        let rows: [DiaryTwoEntry] = try await client.from("diary_two_entries")
            .select(diaryTwoSelectColumns)
            .eq("id", value: id)
            .eq("patient_id", value: patientUUID)
            .limit(1).execute().value
        guard let entry = DiaryTwoEntryLookup.accepted(rows.first, id: id, patientId: patientId) else { return nil }
        upsertCache(entry)
        return entry
    }

    func createEntry(
        patientId: DatabaseID,
        event: String,
        automaticThoughts: [String],
        feelings: [DiaryFeeling],
        thinkingErrors: [ThinkingError],
        alternativeThoughts: [String]
    ) async throws -> DiaryTwoEntry {
        try await EntitlementState.shared.requireWrite(localDemo: DemoData.isDemoID(patientId))
        if DemoData.isDemoID(patientId) {
            let entry = DiaryTwoEntry(
                id: UUID(),
                patientId: patientId,
                therapistId: UUID(),
                createdBy: .therapist,
                event: event,
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
            let saved: DiaryTwoEntry = try await client.from("diary_two_entries")
                .insert(
                    NewDiaryTwoEntry(
                        patientId: patientUUID,
                        therapistId: therapistId,
                        createdBy: .therapist,
                        event: event,
                        automaticThoughts: automaticThoughts,
                        feelings: feelings,
                        thinkingErrors: thinkingErrors,
                        alternativeThoughts: alternativeThoughts
                    )
                )
                .select(diaryTwoSelectColumns)
                .single()
                .execute()
                .value
            upsertCache(saved)
            AppLog.store.info("Diary 2 entry created")
            return saved
        } catch {
            AppLog.store.error(
                "Diary 2 create failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    func updateEntry(
        id: UUID,
        patientId: DatabaseID,
        event: String,
        automaticThoughts: [String],
        feelings: [DiaryFeeling],
        thinkingErrors: [ThinkingError],
        alternativeThoughts: [String]
    ) async throws -> DiaryTwoEntry {
        try await EntitlementState.shared.requireWrite(localDemo: DemoData.isDemoID(patientId))
        guard !entries(for: patientId).contains(where: { $0.id == id && $0.createdBy == .patient }) else { throw PatientStoreError.updateRejected }
        if DemoData.isDemoID(patientId) {
            guard var entry = cached(for: patientId).first(where: { $0.id == id }) else {
                throw AuthError.notConfigured
            }
            entry.event = event
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
            let saved: DiaryTwoEntry = try await client.from("diary_two_entries")
                .update(
                    DiaryTwoEntryClinicalUpdate(
                        event: event,
                        automaticThoughts: automaticThoughts,
                        feelings: feelings,
                        thinkingErrors: thinkingErrors,
                        alternativeThoughts: alternativeThoughts,
                        updatedAt: Self.timestampString(from: Date())
                    )
                )
                .eq("id", value: id)
                .eq("created_by", value: "therapist")
                .eq("patient_id", value: patientId.queryValue)
                .select(diaryTwoSelectColumns)
                .single()
                .execute()
                .value
            upsertCache(saved)
            AppLog.store.info("Diary 2 entry updated")
            return saved
        } catch {
            AppLog.store.error(
                "Diary 2 update failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    func deleteEntry(id: UUID, patientId: DatabaseID) async throws {
        try await EntitlementState.shared.requireWrite(localDemo: DemoData.isDemoID(patientId))
        guard !entries(for: patientId).contains(where: { $0.id == id && $0.createdBy == .patient }) else { throw PatientStoreError.updateRejected }
        if DemoData.isDemoID(patientId) {
            var list = cached(for: patientId)
            list.removeAll { $0.id == id }
            storeCache(list, for: patientId)
            return
        }
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        do {
            let deleted: [DeletedDiaryTwoRow] = try await client.from("diary_two_entries")
                .delete()
                .eq("id", value: id)
                .eq("created_by", value: "therapist")
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
            AppLog.store.info("Diary 2 entry deleted")
        } catch {
            AppLog.store.error(
                "Diary 2 delete failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    private func cached(for patientId: DatabaseID) -> [DiaryTwoEntry] {
        let key = patientId.queryValue
        let list = DemoData.isDemoID(patientId)
            ? (demoEntriesByPatient[key] ?? [])
            : (entriesByPatient[key] ?? [])
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    private func upsertCache(_ entry: DiaryTwoEntry) {
        var list = cached(for: entry.patientId).filter { $0.id != entry.id }
        list.append(entry)
        storeCache(list, for: entry.patientId)
    }

    private func storeCache(_ list: [DiaryTwoEntry], for patientId: DatabaseID) {
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


enum DiaryTwoEntryLookup {
    static func accepted(_ entry: DiaryTwoEntry?, id: UUID, patientId: DatabaseID) -> DiaryTwoEntry? {
        guard let entry, entry.id == id, entry.patientId.matches(patientId.queryValue) else { return nil }
        return entry
    }
}
