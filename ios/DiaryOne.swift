import Foundation
import OSLog
import Supabase

enum DiaryOneEntryCreator: String, Codable, Sendable {
    case therapist
    case patient
}

/// One Diary 1 record for a Patient. Not tied to a Session or assignment.
nonisolated struct DiaryOneEntry: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let patientId: DatabaseID
    let therapistId: UUID
    let createdBy: DiaryOneEntryCreator
    var event: String
    var thought: String
    var feeling: String
    var feelingIntensity: Int
    var behaviour: String
    var physicalSymptoms: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case patientId = "patient_id"
        case therapistId = "therapist_id"
        case createdBy = "created_by"
        case event
        case thought
        case feeling
        case feelingIntensity = "feeling_intensity"
        case behaviour
        case physicalSymptoms = "physical_symptoms"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct NewDiaryOneEntry: Encodable {
    let patientId: UUID
    let therapistId: UUID
    let createdBy: DiaryOneEntryCreator
    let event: String
    let thought: String
    let feeling: String
    let feelingIntensity: Int
    let behaviour: String
    let physicalSymptoms: String?

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case therapistId = "therapist_id"
        case createdBy = "created_by"
        case event, thought, feeling, behaviour
        case feelingIntensity = "feeling_intensity"
        case physicalSymptoms = "physical_symptoms"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patientId, forKey: .patientId)
        try container.encode(therapistId, forKey: .therapistId)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(event, forKey: .event)
        try container.encode(thought, forKey: .thought)
        try container.encode(feeling, forKey: .feeling)
        try container.encode(feelingIntensity, forKey: .feelingIntensity)
        try container.encode(behaviour, forKey: .behaviour)
        try container.encode(physicalSymptoms, forKey: .physicalSymptoms)
    }
}

private struct DiaryOneEntryClinicalUpdate: Encodable {
    let event: String
    let thought: String
    let feeling: String
    let feelingIntensity: Int
    let behaviour: String
    let physicalSymptoms: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case event, thought, feeling, behaviour
        case feelingIntensity = "feeling_intensity"
        case physicalSymptoms = "physical_symptoms"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(event, forKey: .event)
        try container.encode(thought, forKey: .thought)
        try container.encode(feeling, forKey: .feeling)
        try container.encode(feelingIntensity, forKey: .feelingIntensity)
        try container.encode(behaviour, forKey: .behaviour)
        try container.encode(physicalSymptoms, forKey: .physicalSymptoms)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

private struct DeletedDiaryOneRow: Decodable {
    let id: UUID
}

/// Therapist CRUD for `public.diary_one_entries`. RLS is the authorization
/// boundary. Demo clinic IDs stay in memory because they are not UUIDs.
@Observable
@MainActor
final class DiaryOneStore {
    private let client: SupabaseClient
    private var entriesByPatient: [String: [DiaryOneEntry]] = [:]
    /// Demo clinic only — not used for real patients.
    private var demoEntriesByPatient: [String: [DiaryOneEntry]] = [:]

    init(client: SupabaseClient) {
        self.client = client
    }

    func entries(for patientId: DatabaseID) -> [DiaryOneEntry] {
        cached(for: patientId)
    }

    func loadEntries(for patientId: DatabaseID) async throws -> [DiaryOneEntry] {
        if DemoData.isDemoID(patientId) {
            return cached(for: patientId)
        }
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        guard let patientUUID = patientId.uuidValue else {
            throw AuthError.notConfigured
        }
        do {
            let rows: [DiaryOneEntry] = try await client.from("diary_one_entries")
                .select(
                    "id, patient_id, therapist_id, created_by, event, thought, feeling, feeling_intensity, behaviour, physical_symptoms, created_at, updated_at"
                )
                .eq("patient_id", value: patientUUID)
                .order("created_at", ascending: false)
                .execute()
                .value
            entriesByPatient[patientId.queryValue] = rows
            AppLog.store.info("Diary 1 entries loaded")
            return rows
        } catch {
            AppLog.store.error(
                "Diary 1 load failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    func createEntry(
        patientId: DatabaseID,
        event: String,
        thought: String,
        feeling: String,
        feelingIntensity: Int,
        behaviour: String,
        physicalSymptoms: String?
    ) async throws -> DiaryOneEntry {
        let symptoms = Self.nullIfEmpty(physicalSymptoms)
        if DemoData.isDemoID(patientId) {
            let entry = DiaryOneEntry(
                id: UUID(),
                patientId: patientId,
                therapistId: UUID(),
                createdBy: .therapist,
                event: event,
                thought: thought,
                feeling: feeling,
                feelingIntensity: feelingIntensity,
                behaviour: behaviour,
                physicalSymptoms: symptoms,
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
            let saved: DiaryOneEntry = try await client.from("diary_one_entries")
                .insert(
                    NewDiaryOneEntry(
                        patientId: patientUUID,
                        therapistId: therapistId,
                        createdBy: .therapist,
                        event: event,
                        thought: thought,
                        feeling: feeling,
                        feelingIntensity: feelingIntensity,
                        behaviour: behaviour,
                        physicalSymptoms: symptoms
                    )
                )
                .select(
                    "id, patient_id, therapist_id, created_by, event, thought, feeling, feeling_intensity, behaviour, physical_symptoms, created_at, updated_at"
                )
                .single()
                .execute()
                .value
            upsertCache(saved)
            AppLog.store.info("Diary 1 entry created")
            return saved
        } catch {
            AppLog.store.error(
                "Diary 1 create failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    func updateEntry(
        id: UUID,
        patientId: DatabaseID,
        event: String,
        thought: String,
        feeling: String,
        feelingIntensity: Int,
        behaviour: String,
        physicalSymptoms: String?
    ) async throws -> DiaryOneEntry {
        let symptoms = Self.nullIfEmpty(physicalSymptoms)
        if DemoData.isDemoID(patientId) {
            guard var entry = cached(for: patientId).first(where: { $0.id == id }) else {
                throw AuthError.notConfigured
            }
            entry.event = event
            entry.thought = thought
            entry.feeling = feeling
            entry.feelingIntensity = feelingIntensity
            entry.behaviour = behaviour
            entry.physicalSymptoms = symptoms
            entry.updatedAt = .now
            upsertCache(entry)
            return entry
        }
        guard SupabaseConfig.isConfigured else { throw AuthError.notConfigured }
        do {
            let saved: DiaryOneEntry = try await client.from("diary_one_entries")
                .update(
                    DiaryOneEntryClinicalUpdate(
                        event: event,
                        thought: thought,
                        feeling: feeling,
                        feelingIntensity: feelingIntensity,
                        behaviour: behaviour,
                        physicalSymptoms: symptoms,
                        updatedAt: Self.timestampString(from: Date())
                    )
                )
                .eq("id", value: id)
                .select(
                    "id, patient_id, therapist_id, created_by, event, thought, feeling, feeling_intensity, behaviour, physical_symptoms, created_at, updated_at"
                )
                .single()
                .execute()
                .value
            upsertCache(saved)
            AppLog.store.info("Diary 1 entry updated")
            return saved
        } catch {
            AppLog.store.error(
                "Diary 1 update failed: \(error.localizedDescription, privacy: .public)"
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
            let deleted: [DeletedDiaryOneRow] = try await client.from("diary_one_entries")
                .delete()
                .eq("id", value: id)
                .select("id")
                .execute()
                .value
            guard !deleted.isEmpty else {
                throw AuthError.notConfigured
            }
            var list = cached(for: patientId)
            list.removeAll { $0.id == id }
            storeCache(list, for: patientId)
            AppLog.store.info("Diary 1 entry deleted")
        } catch {
            AppLog.store.error(
                "Diary 1 delete failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    private func cached(for patientId: DatabaseID) -> [DiaryOneEntry] {
        let key = patientId.queryValue
        let list = DemoData.isDemoID(patientId)
            ? (demoEntriesByPatient[key] ?? [])
            : (entriesByPatient[key] ?? [])
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    private func upsertCache(_ entry: DiaryOneEntry) {
        var list = cached(for: entry.patientId).filter { $0.id != entry.id }
        list.append(entry)
        storeCache(list, for: entry.patientId)
    }

    private func storeCache(_ list: [DiaryOneEntry], for patientId: DatabaseID) {
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

    private static func nullIfEmpty(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
