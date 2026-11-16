import Foundation
import SwiftUI
import Supabase

nonisolated enum PatientNameRules {
    static let version = "2026-10-29"
    static let type = "patient_name_storage"
    static func valid(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.unicodeScalars.count <= 200 &&
        !name.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
    }
    static func revision(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { $0 >= 48 && $0 <= 57 }
    }
    static func older(_ value: String, than current: String) -> Bool {
        let lhs = value.drop(while: { $0 == "0" }), rhs = current.drop(while: { $0 == "0" })
        return lhs.count == rhs.count ? lhs.lexicographicallyPrecedes(rhs) : lhs.count < rhs.count
    }
    static let title = "שמירת שמות מטופלים וסנכרון בין מכשירים"
    static let notice = """
מעתה שמות המטופלים יישמרו בשרתי CBTipul בצורה מוצפנת, כדי לאפשר סנכרון בין מכשירים ובהמשך גם בחירת מטופל/ת בסביבת העבודה במחשב.

לאחר אישורך, שמות המטופלים השמורים במכשיר זה יועברו לשרת באמצעות חיבור מוצפן וישויכו לרשומות המטופלים הקיימות. שמות שתזינו או תשנו בהמשך יישמרו גם הם באופן זה.

ההצפנה מנוהלת בשרת: מערכות CBTipul המורשות יכולות לפענח את השמות לצורך מתן השירות. זו אינה הצפנה מקצה לקצה.

שדה שם המטופל/ת לא יצורף אוטומטית לבקשות לכלי בינה מלאכותית. מידע מזהה שהוזן בתוך טקסט חופשי מטופל בנפרד לפי מדיניות עיבוד התוכן.

בחירה באישור והמשך מאשרת את השמירה והסנכרון המתוארים כאן. בחירה בלא עכשיו לא תעלה שמות ותשאיר את תהליך ההגדרה ממתין.
"""
}
nonisolated struct NameConsentReceipt: Codable {
    let therapist_id: String; let consent_type: String; let required_version: String
    let accepted_version: String?; let accepted_at: String?; let revoked_at: String?
    let status: String; let revision: Int64
    func validate(account: String) throws {
        func date(_ s: String?) -> Bool {
            guard let s else { return false }
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.date(from: s) != nil || ISO8601DateFormatter().date(from: s) != nil
        }
        guard therapist_id.lowercased() == account.lowercased(), consent_type == PatientNameRules.type,
              required_version == PatientNameRules.version, revision >= 0, revision <= 9_007_199_254_740_991,
              ["required", "accepted", "declined", "revoked"].contains(status),
              accepted_at == nil || date(accepted_at), revoked_at == nil || date(revoked_at),
              status != "accepted" || (accepted_version == required_version && date(accepted_at) && revoked_at == nil),
              status != "revoked" || date(revoked_at) else { throw NameSyncFailure(code: "invalid_response") }
    }
}
nonisolated struct NameConsentDecision: Codable {
    var p_consent_type = PatientNameRules.type
    var p_required_version = PatientNameRules.version
    let p_decision: String; let p_request_id: String; let p_expected_revision: Int64
}
nonisolated struct ServerPatientName: Codable {
    let patient_id: String; let name: String?; let revision: String; let updated_at: String?
}
nonisolated struct PatientNamePage: Decodable { let names: [ServerPatientName]; let next_after: String? }
nonisolated struct PatientNameSetResult: Decodable {
    let patient_id: String; let revision: String; let updated_at: String; let unchanged: Bool
}
nonisolated struct PatientNameEdit: Codable, Equatable {
    let id: String; let name: String; let initial: Bool
    init(name: String, initial: Bool) { id = UUID().uuidString; self.name = name; self.initial = initial }
}
nonisolated struct PatientNameEntry: Codable {
    var confirmed: String?; var revision = "0"; var pending: PatientNameEdit?
    var initialized = false
}
nonisolated struct PatientNameSyncSnapshot: Codable {
    var entries: [String: PatientNameEntry] = [:]
    var consentDecision: NameConsentDecision?
    var migrationVersion: String?
    var confirmedIDs: Set<String>?
    var approvalVersion: String?
}
nonisolated struct NameSyncFailure: Error, LocalizedError {
    let code: String
    var errorDescription: String? {
        switch code {
        case "invalid_name": "יש להזין שם שאינו ריק, עד 200 תווים וללא תווי בקרה."
        case "consent_required": L10n.patientNameConsentRequired
        case "revision_conflict": L10n.patientNameChanged
        default: L10n.patientNameSaveFailed
        }
    }
    static func from(_ error: Error) -> Self {
        if let e = error as? Self { return e }
        if case let FunctionsError.httpError(status, data) = error {
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let nested = body?["error"] as? [String: Any]
            return Self(code: body?["code"] as? String ?? nested?["code"] as? String ?? body?["error"] as? String ?? "http_\(status)")
        }
        if let e = error as? PostgrestError { return Self(code: e.message.hasPrefix("consent_") ? e.message : e.code ?? "service") }
        return Self(code: "connection")
    }
}

/// Account-scoped memory plus durable unfinished legacy migration input. iCloud mappings are read only.
@MainActor @Observable final class PatientNameSync {
    typealias Call = (String, Data) async throws -> Data
    private let call: Call
    private let storage: any DraftPersistence
    private let eligible: () -> Bool
    private let fullAccess: () -> Bool
    private(set) var account: String?
    private var generation = 0
    private var snapshot = PatientNameSyncSnapshot()
    private var owned: Set<String> = []
    private var deleting: Set<String> = []
    private var legacy: [String: String] = [:]
    private var rowNames: [String: String?] = [:]
    private var rowLegacy: [String: String] = [:]
    private var rowsReceived = false
    private(set) var writeRevision = 0
    var waitForPatientRows = false
    /// Presence is authoritative even for null. These values are never persisted.
    func receivePatientRows(_ records: [ClinicalLoadedRecord]) throws {
        var names: [String: String?] = [:]
        var fallbacks: [String: String] = [:]
        for record in records {
            let id = record.id.lowercased()
            if let value = record.values["decryptedName"] {
                switch value {
                case .string(let name): names.updateValue(name, forKey: id)
                case .null: names.updateValue(nil, forKey: id)
                default: throw NameSyncFailure(code: "invalid_response")
                }
            }
            if (names[id] ?? nil) == nil, let name = try? readLegacy?(id), !name.isEmpty { fallbacks[id] = name }
        }
        rowNames = names; rowLegacy = fallbacks; rowsReceived = true
        register(Dictionary(uniqueKeysWithValues: records.map { ($0.id, Optional<String>.none) }))
        for (id, name) in names where name != nil {
            if snapshot.entries[id]?.pending?.initial == true { snapshot.entries[id]?.pending = nil }
        }
    }
    private var lastRefresh = Date.distantPast
    private var rerun = false
    private var diskReady = false
    private(set) var legacyChecked = false
    private(set) var busy = false
    private(set) var accepted = false
    private(set) var failed = false
    /// Only an explicit approval attempt may produce feedback on the approval gate.
    private(set) var approvalFailed = false
    private var consentRevision: Int64?
    private(set) var consentChecked = false
    var loadOwned: (() async throws -> [String: String?])?
    var migrationComplete: Bool { snapshot.migrationVersion == PatientNameRules.version }
    private var hasOwnedLegacy: Bool { owned.contains { snapshot.entries[$0]?.pending != nil } }
    private var migrationApproved: Bool { snapshot.approvalVersion == PatientNameRules.version }
    func shouldGate(therapist: Bool, demo: Bool) -> Bool { therapist && !demo && legacyChecked && hasOwnedLegacy && !migrationApproved }
    var changed: (() -> Void)?
    var readLegacy: ((String) throws -> String?)?
    var hasPending: Bool { snapshot.entries.values.contains { $0.pending != nil } }
    init(call: @escaping Call, storage: any DraftPersistence = DeviceDraftStorage(service: "CBTipul.patient-name-sync.v1"),
         eligible: @escaping () -> Bool, fullAccess: @escaping () -> Bool) {
        self.call = call; self.storage = storage; self.eligible = eligible; self.fullAccess = fullAccess
    }
    convenience init(client: SupabaseClient) {
        self.init(call: { name, data in
            let params = try JSONDecoder().decode([String: AnyJSON].self, from: data)
            if name == "patient-names" {
                #if DEBUG
                if case .string(let operation) = params["operation"] { print("PatientLaunchTrace request=patient-names operation=\(operation) t=\(ProcessInfo.processInfo.systemUptime)") }
                #endif
                let response: AnyJSON = try await client.functions.invoke(name, options: FunctionInvokeOptions(body: params))
                return try JSONEncoder().encode(response)
            }
            return try await client.rpc(name, params: params).execute().data
        }, eligible: { ProcessInfo.processInfo.environment["CBTIPUL_NAME_SYNC_TESTS"] != "1" && EntitlementState.shared.role == .therapist && !EntitlementState.shared.isLocalDemo },
           fullAccess: { EntitlementState.shared.access == .full })
        waitForPatientRows = true
        loadOwned = {
            struct Owned: Decodable { let id: String }
            var result: [String: String?] = [:]; var offset = 0
            repeat {
                let page: [Owned] = try await client.from("Patients").select("id").order("id").range(from: offset, to: offset + 499).execute().value
                for row in page { result.updateValue(nil, forKey: row.id) }
                if page.count < 500 { break }; offset += 500
            } while true
            return result
        }
    }
    func setAccount(_ value: String?) {
        let value = value?.lowercased()
        guard account != value else { return }
        rowNames = [:]; rowLegacy = [:]; rowsReceived = false; writeRevision = 0
        generation += 1; PatientNameResolver.clear(); legacyChecked = false; account = value; snapshot = .init(); owned = []; deleting = []; legacy = [:]
        busy = false; rerun = false; accepted = false; failed = false; approvalFailed = false; consentRevision = nil; consentChecked = false; lastRefresh = .distantPast; diskReady = false
        guard let value else { changed?(); return }
        do { snapshot = try storage.load(PatientNameSyncSnapshot.self, key: value) ?? .init(); diskReady = true; discardConfirmedCache() }
        catch { failed = true }
        changed?()
    }
    func hasConfirmed(_ id: String) -> Bool {
        (rowNames[id.lowercased()] ?? nil) != nil || snapshot.confirmedIDs?.contains(id.lowercased()) == true || snapshot.entries[id.lowercased()]?.confirmed != nil
    }
    private func discardConfirmedCache() {
        // Preserve all unfinished input. Only values already acknowledged by the server are discarded.
        snapshot.confirmedIDs = (snapshot.confirmedIDs ?? []).union(snapshot.entries.filter { $0.value.confirmed != nil && $0.value.pending == nil }.keys)
        snapshot.entries = snapshot.entries.filter { $0.value.pending != nil }.mapValues { var e = $0; e.confirmed = nil; return e }
    }
    private func persist() throws {
        guard let account, diskReady else { throw NameSyncFailure(code: "local_storage") }
        var durable = snapshot
        // Confirmed server values are session memory only. Only unfinished legacy input is retained.
        durable.entries = snapshot.entries.filter { $0.value.pending != nil }.mapValues {
            var entry = $0; entry.confirmed = nil; return entry
        }
        durable.confirmedIDs = (snapshot.confirmedIDs ?? []).union(snapshot.entries.filter { $0.value.confirmed != nil && $0.value.pending == nil }.keys)
        snapshot.confirmedIDs = durable.confirmedIDs
        try storage.save(durable, key: account)
    }
    func register(_ values: [String: String?]) {
        guard account != nil else { return }
        owned = Set(values.keys.map { $0.lowercased() }.filter { UUID(uuidString: $0) != nil }).subtracting(deleting)
        legacy = Dictionary(uniqueKeysWithValues: values.compactMap { key, value in
            guard owned.contains(key.lowercased()), !hasConfirmed(key.lowercased()), let value, PatientNameRules.valid(value) else { return nil }
            return (key.lowercased(), value)
        })
    }
    func displayed(_ id: String, legacy fallback: String?) -> String? {
        guard account != nil else { return fallback }
        let key = id.lowercased()
        let entry = snapshot.entries[key]
        if let value = rowNames[key] { return value ?? entry?.pending?.name ?? rowLegacy[key] ?? fallback }
        return entry?.pending?.name ?? entry?.confirmed ?? rowLegacy[key] ?? fallback
    }
    /// Ordinary writes are awaited, never persisted as offline name intents.
    func edit(_ id: String, name: String) async throws {
        guard PatientNameRules.valid(name), UUID(uuidString: id) != nil else { throw NameSyncFailure(code: "invalid_name") }
        let epoch = generation; let id = id.lowercased()
        let rows = try await fetch(epoch)
        guard let row = rows[id] else { throw NameSyncFailure(code: "patient_not_found") }
        struct SetName: Encodable { let operation = "set"; let patient_id: String; let name: String; let expected_revision: String }
        let result: PatientNameSetResult = try await request("patient-names", SetName(patient_id: id, name: name, expected_revision: row.revision), epoch)
        guard result.patient_id.lowercased() == id, PatientNameRules.revision(result.revision), !result.updated_at.isEmpty else { throw NameSyncFailure(code: "invalid_response") }
        writeRevision += 1
        owned.insert(id)
        snapshot.entries[id] = PatientNameEntry(confirmed: name, revision: result.revision, initialized: true)
        if rowNames.keys.contains(id) { rowNames.updateValue(name, forKey: id) }
        changed?()
    }
    func rememberCreated(_ id: String, name: String) async throws { try await edit(id, name: name) }
    func beginDeletion(_ id: String) { deleting.insert(id.lowercased()); owned.remove(id.lowercased()) }
    func cancelDeletion(_ id: String) { deleting.remove(id.lowercased()); owned.insert(id.lowercased()) }
    func remove(_ id: String) {
        let id = id.lowercased(); owned.remove(id); legacy.removeValue(forKey: id); snapshot.entries.removeValue(forKey: id)
        do { try persist() } catch { failed = true }
    }
    private func check(_ epoch: Int) throws {
        guard epoch == generation, account != nil, eligible() else { throw CancellationError() }
    }
    private func request<P: Encodable, R: Decodable>(_ method: String, _ payload: P, _ epoch: Int) async throws -> R {
        try check(epoch)
        let data: Data
        do { data = try await call(method, JSONEncoder().encode(payload)) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw NameSyncFailure.from(error) }
        try check(epoch)
        if method == "get_my_consent" || method == "record_my_consent" {
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let object, ["therapist_id", "consent_type", "required_version", "accepted_version", "accepted_at", "revoked_at", "status", "revision"].allSatisfy({ object.keys.contains($0) }) else { throw NameSyncFailure(code: "invalid_response") }
        }
        do { return try JSONDecoder().decode(R.self, from: data) }
        catch { throw NameSyncFailure(code: "invalid_response") }
    }
    private func lookup(_ epoch: Int) async throws -> NameConsentReceipt {
        let receipt: NameConsentReceipt = try await request("get_my_consent", ["p_consent_type": PatientNameRules.type, "p_required_version": PatientNameRules.version], epoch)
        try receipt.validate(account: account!)
        guard consentRevision == nil || receipt.revision >= consentRevision! else { throw NameSyncFailure(code: "invalid_response") }
        consentRevision = receipt.revision; accepted = receipt.status == "accepted"; consentChecked = true
        snapshot.approvalVersion = accepted ? PatientNameRules.version : nil
        return receipt
    }
    private func reopenStorage() {
        guard !diskReady, let account else { return }
        do { snapshot = try storage.load(PatientNameSyncSnapshot.self, key: account) ?? .init(); diskReady = true; discardConfirmedCache() }
        catch { failed = true }
    }
    func decide(_ decision: String = "accepted", userInitiated: Bool = true) async {
        reopenStorage()
        guard !busy, account != nil, eligible() else { return }
        guard diskReady else { if userInitiated { approvalFailed = true }; return }
        let epoch = generation; busy = true; failed = false; accepted = false
        if userInitiated { approvalFailed = false }
        var decisionConfirmed = false
        defer { if epoch == generation { busy = false } }
        do {
            if let pending = snapshot.consentDecision,
               pending.p_consent_type != PatientNameRules.type || pending.p_required_version != PatientNameRules.version {
                snapshot.consentDecision = nil; try persist()
            }
            if snapshot.consentDecision == nil {
                let current = try await lookup(epoch)
                snapshot.consentDecision = NameConsentDecision(p_decision: decision, p_request_id: UUID().uuidString, p_expected_revision: current.revision)
                try persist()
            }
            let receipt: NameConsentReceipt = try await request("record_my_consent", snapshot.consentDecision!, epoch)
            try receipt.validate(account: account!)
            guard consentRevision == nil || receipt.revision >= consentRevision! else { throw NameSyncFailure(code: "invalid_response") }
            consentRevision = receipt.revision; accepted = receipt.status == "accepted"
            snapshot.consentDecision = nil; if accepted { snapshot.approvalVersion = PatientNameRules.version }; try persist(); decisionConfirmed = true; consentChecked = true
            if accepted { Task { await refresh(force: true) } }
        } catch is CancellationError {
            // Keep the durable decision for the next background resume.
        } catch {
            guard epoch == generation else { return }
            if userInitiated { approvalFailed = true }
            if !decisionConfirmed { accepted = false }; failed = true
            let code = NameSyncFailure.from(error).code
            if code == "consent_required" { accepted = false; _ = try? await lookup(epoch) }
            if ["consent_revision_conflict", "consent_request_superseded", "consent_request_id_reused"].contains(code) {
                snapshot.consentDecision = nil; try? persist()
                _ = try? await lookup(epoch)
            }
        }
    }
    func retryMigration() async {
        if snapshot.consentDecision != nil { await decide(userInitiated: false) } else { await refresh(force: true) }
    }
    func refresh(force: Bool = false) async {
        guard !waitForPatientRows || rowsReceived else { return }
        reopenStorage()
        guard account != nil, eligible(), diskReady else { return }
        if busy { rerun = true; return }
        guard force || Date().timeIntervalSince(lastRefresh) > 30 else { return }
        busy = true; lastRefresh = Date(); let epoch = generation
        defer {
            if epoch == generation {
                busy = false
                if rerun { rerun = false; Task { await refresh(force: true) } }
            }
        }
        do {
            if !legacyChecked {
                if !migrationComplete {
                    if !rowsReceived, let loadOwned { let values = try await loadOwned(); try check(epoch); register(values) }
                    let confirmed = (snapshot.confirmedIDs ?? []).union(snapshot.entries.filter { $0.value.confirmed != nil && $0.value.pending == nil }.keys)
                    for id in owned where !confirmed.contains(id) && (rowNames[id] ?? nil) == nil {
                        if let value = try readLegacy?(id) ?? legacy[id], PatientNameRules.valid(value) {
                            var entry = snapshot.entries[id] ?? .init()
                            if entry.pending == nil { entry.pending = .init(name: value, initial: true) }
                            snapshot.entries[id] = entry
                        }
                    }
                }
                legacyChecked = true
                if !hasPending { snapshot.migrationVersion = PatientNameRules.version }
            }
            // Approval requests are idempotent and resume after a lost receipt.
            if hasOwnedLegacy && snapshot.consentDecision != nil {
                busy = false; await decide(userInitiated: false); return
            }
            try persist()
            // Ordinary reads rely on the normal terms flow and the encrypted API.
            failed = false; try await sync(epoch)
        } catch is CancellationError {
            // Cancellation is an unfinished background operation, not a visible error.
        } catch {
            guard epoch == generation else { return }
            failed = true
            let code = NameSyncFailure.from(error).code
            // The deployed API may still reject ordinary reads. Never turn that
            // rejection into name-specific UI or consent requests for a clean account.
            if code == "consent_required", hasOwnedLegacy, !migrationApproved { _ = try? await lookup(epoch) }
        }
    }
    private func fetch(_ epoch: Int) async throws -> [String: ServerPatientName] {
        struct Query: Encodable { let operation = "list"; let after: String?; let limit = 100
            enum CodingKeys: String, CodingKey { case operation, after, limit }
            func encode(to encoder: Encoder) throws { var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(operation, forKey: .operation); try c.encode(after, forKey: .after); try c.encode(limit, forKey: .limit) }
        }
        var after: String?; var seen: Set<String> = []; var result: [String: ServerPatientName] = [:]
        repeat {
            let page: PatientNamePage = try await request("patient-names", Query(after: after), epoch)
            for row in page.names {
                guard UUID(uuidString: row.patient_id) != nil, PatientNameRules.revision(row.revision), row.name == nil || PatientNameRules.valid(row.name!) else { throw NameSyncFailure(code: "invalid_response") }
                result[row.patient_id.lowercased()] = row
            }
            after = page.next_after
            if let after { guard UUID(uuidString: after) != nil, seen.insert(after).inserted else { throw NameSyncFailure(code: "invalid_response") } }
        } while after != nil
        return result
    }
    private func adopt(_ rows: [String: ServerPatientName]) throws {
        for (id, row) in rows where owned.contains(id) {
            guard !rowNames.keys.contains(id) || snapshot.entries[id]?.pending != nil else { continue }
            var entry = snapshot.entries[id] ?? .init()
            guard !PatientNameRules.older(row.revision, than: entry.revision) else { continue }
            if let name = row.name {
                entry.confirmed = name; entry.revision = row.revision; entry.initialized = true
                if entry.pending != nil { entry.pending = nil }
            } else {
                entry.confirmed = nil; entry.revision = row.revision
            }
            snapshot.entries[id] = entry
            if rowNames.keys.contains(id) { rowNames.updateValue(row.name, forKey: id) }
        }
        try persist(); changed?()
    }
    private func sync(_ epoch: Int) async throws {
        let migrating = !migrationComplete
        // Never re-read a confirmed legacy source, including late iCloud copies.
        if rowsReceived && owned.allSatisfy({ rowNames.keys.contains($0) }) {
            if !hasOwnedLegacy { return }
            if !migrationApproved { _ = try await lookup(epoch); guard migrationApproved else { return } }
        }
        var rows = try await fetch(epoch); try adopt(rows)
        // Only automatic upload of existing device-local input requires this approval.
        // Reading server names, including names that resolve legacy conflicts, does not.
        if hasOwnedLegacy && !migrationApproved {
            _ = try await lookup(epoch)
            guard migrationApproved else { return }
            try persist()
        }
        for id in owned.sorted() {
            var attempts = 0
            while owned.contains(id), let intent = snapshot.entries[id]?.pending, attempts < 3 {
                guard let row = rows[id] else { break }
                // Initial reconciliation never replaces an existing server name.
                if migrating && row.name != nil { break }
                if row.name == intent.name {
                    snapshot.entries[id]?.pending = nil; try persist(); changed?(); break
                }
                if !intent.initial && row.name != nil && !fullAccess() { failed = true; break }
                attempts += 1
                struct SetName: Encodable { let operation = "set"; let patient_id: String; let name: String; let expected_revision: String }
                do {
                    let result: PatientNameSetResult = try await request("patient-names", SetName(patient_id: id, name: intent.name, expected_revision: intent.initial ? "0" : row.revision), epoch)
                    guard owned.contains(id) else { break }
                    guard result.patient_id.lowercased() == id, PatientNameRules.revision(result.revision), !result.updated_at.isEmpty else { throw NameSyncFailure(code: "invalid_response") }
                    writeRevision += 1
                    snapshot.entries[id]?.confirmed = intent.name; snapshot.entries[id]?.revision = result.revision; snapshot.entries[id]?.initialized = true
                    if snapshot.entries[id]?.pending?.id == intent.id { snapshot.entries[id]?.pending = nil }
                    if rowNames.keys.contains(id) { rowNames.updateValue(intent.name, forKey: id) }
                    rows[id] = ServerPatientName(patient_id: id, name: intent.name, revision: result.revision, updated_at: result.updated_at)
                    try persist(); changed?()
                } catch {
                    try check(epoch)
                    guard owned.contains(id) else { break }
                    let code = NameSyncFailure.from(error).code
                    if code == "revision_conflict" {
                        rows = try await fetch(epoch); try adopt(rows)
                        // A newer intent is processed instead; the obsolete payload is never retried.
                        continue
                    }
                    if ["patient_not_found", "patient_ownership_changed"].contains(code) { remove(id); break }
                    throw error
                }
            }
            if snapshot.entries[id]?.pending != nil && !(migrating && rows[id]?.name != nil) { failed = true }
        }
        if migrating {
            let reconciled = owned.allSatisfy { id in
                (legacy[id] == nil && snapshot.entries[id]?.pending == nil) || rows[id]?.name != nil
            }
            guard reconciled, !failed else { throw NameSyncFailure(code: "migration_incomplete") }
            let previous = snapshot.migrationVersion
            snapshot.migrationVersion = PatientNameRules.version
            do { try persist() } catch { snapshot.migrationVersion = previous; throw error }
        }
    }
}

struct PatientNameSetupView: View {
    let sync: PatientNameSync
    var blocking = false
    var retry: (() async -> Void)?
    var logout: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(PatientNameRules.title).font(.title2.bold())
                    Text(PatientNameRules.notice)
                    if sync.approvalFailed { Text(L10n.patientNameApprovalFailed).foregroundStyle(Theme.error) }

                    if !sync.accepted {
                        Button("אישור והמשך") { Task { await sync.decide(); if !blocking && sync.accepted && !sync.failed { dismiss() } } }
                            .buttonStyle(.borderedProminent).disabled(sync.busy)
                    }
                    Button(action: { logout?() }) {
                        Text(blocking ? "לא עכשיו — יציאה מהחשבון" : "יציאה מהחשבון")
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }.padding(24)
            }.background(Theme.base)
                .toolbar { if !blocking { ToolbarItem(placement: .cancellationAction) { Button("סגירה") { dismiss() } } } }
        }.appTextSize().interactiveDismissDisabled(blocking)
    }
}
