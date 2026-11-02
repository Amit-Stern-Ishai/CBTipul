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
}
nonisolated struct NameSyncFailure: Error, LocalizedError {
    let code: String
    var errorDescription: String? { code == "invalid_name" ? "יש להזין שם שאינו ריק, עד 200 תווים וללא תווי בקרה." : "סנכרון השמות ממתין. אפשר לנסות שוב." }
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

/// Device/account-scoped durable intent. Legacy synchronizable mappings are read only.
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
    private var lastRefresh = Date.distantPast
    private var rerun = false
    private var diskReady = false
    private(set) var busy = false
    private(set) var accepted = false
    private(set) var failed = false
    private var consentRevision: Int64?
    private(set) var consentChecked = false
    var loadOwned: (() async throws -> [String: String?])?
    var migrationComplete: Bool { snapshot.migrationVersion == PatientNameRules.version }
    func shouldGate(therapist: Bool, demo: Bool) -> Bool { therapist && !demo && !migrationComplete }
    var changed: (() -> Void)?
    var readLegacy: ((String) -> String?)?
    var hasPending: Bool { snapshot.entries.values.contains { $0.pending != nil } }
    init(call: @escaping Call, storage: any DraftPersistence = DeviceDraftStorage(service: "CBTipul.patient-name-sync.v1"),
         eligible: @escaping () -> Bool, fullAccess: @escaping () -> Bool) {
        self.call = call; self.storage = storage; self.eligible = eligible; self.fullAccess = fullAccess
    }
    convenience init(client: SupabaseClient) {
        self.init(call: { name, data in
            let params = try JSONDecoder().decode([String: AnyJSON].self, from: data)
            if name == "patient-names" {
                let response: AnyJSON = try await client.functions.invoke(name, options: FunctionInvokeOptions(body: params))
                return try JSONEncoder().encode(response)
            }
            return try await client.rpc(name, params: params).execute().data
        }, eligible: { ProcessInfo.processInfo.environment["CBTIPUL_NAME_SYNC_TESTS"] != "1" && EntitlementState.shared.role == .therapist && !EntitlementState.shared.isLocalDemo },
           fullAccess: { EntitlementState.shared.access == .full })
        loadOwned = {
            struct Owned: Decodable { let id: String }
            var result: [String: String?] = [:]; var offset = 0
            repeat {
                let page: [Owned] = try await client.from("Patients").select("id").order("id").range(from: offset, to: offset + 499).execute().value
                for row in page { result.updateValue(PatientIdentityStore().name(for: .text(row.id)), forKey: row.id) }
                if page.count < 500 { break }; offset += 500
            } while true
            return result
        }
    }
    func setAccount(_ value: String?) {
        let value = value?.lowercased()
        guard account != value else { return }
        generation += 1; account = value; snapshot = .init(); owned = []; deleting = []; legacy = [:]
        busy = false; rerun = false; accepted = false; failed = false; consentRevision = nil; consentChecked = false; lastRefresh = .distantPast; diskReady = false
        guard let value else { return }
        do { snapshot = try storage.load(PatientNameSyncSnapshot.self, key: value) ?? .init(); diskReady = true }
        catch { failed = true }
    }
    private func persist() throws {
        guard let account, diskReady else { throw NameSyncFailure(code: "local_storage") }
        try storage.save(snapshot, key: account)
    }
    func register(_ values: [String: String?]) {
        guard account != nil else { return }
        owned = Set(values.keys.map { $0.lowercased() }.filter { UUID(uuidString: $0) != nil }).subtracting(deleting)
        legacy = Dictionary(uniqueKeysWithValues: values.compactMap { key, value in
            guard owned.contains(key.lowercased()), let value, PatientNameRules.valid(value) else { return nil }
            return (key.lowercased(), value)
        })
    }
    func displayed(_ id: String, legacy fallback: String?) -> String? {
        guard account != nil else { return fallback }
        let entry = snapshot.entries[id.lowercased()]
        return entry?.pending?.name ?? entry?.confirmed ?? fallback
    }
    func edit(_ id: String, name: String) throws {
        guard PatientNameRules.valid(name), UUID(uuidString: id) != nil else { throw NameSyncFailure(code: "invalid_name") }
        let id = id.lowercased(); owned.insert(id)
        let previous = snapshot
        var entry = snapshot.entries[id] ?? .init(); entry.pending = .init(name: name, initial: false)
        snapshot.entries[id] = entry
        do { try persist() } catch { snapshot = previous; failed = true; throw error }
        changed?(); Task { await refresh(force: true) }
    }
    // A patient already exists at this point. Keep its name even if local persistence fails;
    // retry storage before any network work rather than reporting patient creation as failed.
    func rememberCreated(_ id: String, name: String) {
        guard account != nil, UUID(uuidString: id) != nil, PatientNameRules.valid(name) else { return }
        let id = id.lowercased(); owned.insert(id)
        var entry = snapshot.entries[id] ?? .init()
        entry.pending = .init(name: name, initial: true); snapshot.entries[id] = entry
        do { try persist() } catch { failed = true }
        changed?()
    }
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
        let data = try await call(method, JSONEncoder().encode(payload))
        try check(epoch)
        if method == "get_my_consent" || method == "record_my_consent" {
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let object, ["therapist_id", "consent_type", "required_version", "accepted_version", "accepted_at", "revoked_at", "status", "revision"].allSatisfy({ object.keys.contains($0) }) else { throw NameSyncFailure(code: "invalid_response") }
        }
        return try JSONDecoder().decode(R.self, from: data)
    }
    private func lookup(_ epoch: Int) async throws -> NameConsentReceipt {
        let receipt: NameConsentReceipt = try await request("get_my_consent", ["p_consent_type": PatientNameRules.type, "p_required_version": PatientNameRules.version], epoch)
        try receipt.validate(account: account!)
        guard consentRevision == nil || receipt.revision >= consentRevision! else { throw NameSyncFailure(code: "invalid_response") }
        consentRevision = receipt.revision; accepted = receipt.status == "accepted"; consentChecked = true
        return receipt
    }
    private func reopenStorage() {
        guard !diskReady, let account else { return }
        do { snapshot = try storage.load(PatientNameSyncSnapshot.self, key: account) ?? .init(); diskReady = true }
        catch { failed = true }
    }
    func decide(_ decision: String = "accepted") async {
        reopenStorage()
        guard !busy, account != nil, eligible(), diskReady else { return }
        let epoch = generation; busy = true; failed = false; accepted = false
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
            snapshot.consentDecision = nil; try persist(); decisionConfirmed = true; consentChecked = true
            if accepted { try await sync(epoch) }
        } catch {
            guard epoch == generation else { return }
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
        if snapshot.consentDecision != nil { await decide() } else { await refresh(force: true) }
    }
    func refresh(force: Bool = false) async {
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
            // An uncertain decision is retried only by the explicit approval/retry action.
            guard snapshot.consentDecision == nil else { failed = true; accepted = false; return }
            try persist()
            _ = try await lookup(epoch)
            guard accepted else { return }
            failed = false; try await sync(epoch)
        } catch {
            guard epoch == generation else { return }
            failed = true
            let code = NameSyncFailure.from(error).code
            if code == "consent_required" { accepted = false; _ = try? await lookup(epoch) }
            else if code == "http_401" || code == "unauthorized" { accepted = false }
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
            var entry = snapshot.entries[id] ?? .init()
            if let name = row.name {
                entry.confirmed = name; entry.revision = row.revision; entry.initialized = true
                if entry.pending?.initial == true { entry.pending = nil }
            } else if !entry.initialized, entry.pending == nil, let local = legacy[id] {
                entry.pending = .init(name: local, initial: true)
            }
            snapshot.entries[id] = entry
        }
        try persist(); changed?()
    }
    private func sync(_ epoch: Int) async throws {
        let migrating = !migrationComplete && loadOwned != nil
        if migrating, let loadOwned {
            let values = try await loadOwned(); try check(epoch); register(values)
        }
        // Re-read only confirmed owned IDs so late iCloud arrivals can fill missing names.
        // Server names still win in adopt; no shared-Keychain enumeration occurs.
        if let readLegacy {
            for id in owned {
                if let name = readLegacy(id), PatientNameRules.valid(name) { legacy[id] = name }
            }
        }
        var rows = try await fetch(epoch); try adopt(rows)
        for id in owned.sorted() {
            var attempts = 0
            while owned.contains(id), let intent = snapshot.entries[id]?.pending, attempts < 3 {
                guard let row = rows[id] else { break }
                // Existing server names finish initial reconciliation. Preserve explicit
                // offline renames for ordinary sync instead of blocking read-only therapists.
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
                    snapshot.entries[id]?.confirmed = intent.name; snapshot.entries[id]?.revision = result.revision; snapshot.entries[id]?.initialized = true
                    if snapshot.entries[id]?.pending?.id == intent.id { snapshot.entries[id]?.pending = nil }
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
                    if !blocking || (sync.consentChecked && !sync.accepted) { Text(PatientNameRules.notice) }
                    if blocking {
                        Text(sync.accepted ? "מסנכרנים את שמות המטופלים במכשיר זה. המרפאה תיפתח לאחר השלמת הסנכרון." : "בודקים את אישור שמירת השמות.")
                    }
                    if sync.failed { Text(blocking ? "לא ניתן להשלים את הבדיקה או הסנכרון כרגע. השמות המקומיים לא נמחקו. יש לבדוק את החיבור ולנסות שוב." : "לא ניתן להשלים את סנכרון השמות כרגע. אפשר לנסות שוב.").foregroundStyle(Theme.error) }
                    if sync.busy { ProgressView().accessibilityLabel("מסנכרנים שמות") }
                    if !sync.accepted && (!blocking || sync.consentChecked) {
                        Button("אישור והמשך") { Task { await sync.decide(); if !blocking && sync.accepted && !sync.failed { dismiss() } } }
                            .buttonStyle(.borderedProminent).disabled(sync.busy)
                    }
                    if blocking && !sync.busy {
                        Button("ניסיון נוסף") { Task { if let retry { await retry() } else { await sync.retryMigration() } } }
                            .buttonStyle(.bordered)
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
