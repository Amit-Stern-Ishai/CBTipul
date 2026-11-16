import Supabase
import XCTest
@testable import CBTipul

@MainActor final class PatientNameSyncTests: XCTestCase {
    let account = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    let patient = "11111111-1111-1111-1111-111111111111"
    let stamp = "2026-10-29T10:00:00Z"
    final class Memory: DraftPersistence {
        var values: [String: Data] = [:]; var fail = false
        func load<T: Decodable>(_ type: T.Type, key: String) throws -> T? { try values[key].map { try JSONDecoder().decode(type, from: $0) } }
        func save<T: Encodable>(_ value: T, key: String) throws { if fail { throw NameSyncFailure(code: "local_storage") }; values[key] = try JSONEncoder().encode(value) }
        func remove(key: String) throws { values[key] = nil }
    }
    @MainActor final class Harness {
        let owner = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        let id = "11111111-1111-1111-1111-111111111111"
        let date = "2026-10-29T10:00:00Z"
        let disk: Memory
        var allowed = true; var full = true; var consent = "accepted"; var consentRevision: Int64 = 0
        var nameFailure: Error?
        var emptyPage = false
        var nameError: String?
        var lookupFailure = false; var consentError: String?; var uncertainConsent = false
        var sets = 0; var lists = 0; var name: String?; var revision = "0"; var paginated = false
        var calls: [(String, [String: Any])] = []
        var onSet: (([String: Any]) throws -> Void)?
        lazy var sync = PatientNameSync(call: { [weak self] method, data in guard let self else { throw CancellationError() }; return try self.call(method, data) }, storage: disk, eligible: { [weak self] in self?.allowed == true }, fullAccess: { [weak self] in self?.full == true })
        init(_ disk: Memory? = nil) { self.disk = disk ?? Memory(); sync.setAccount(owner); sync.register([id: "שם בדיקה"]) }
        func data(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }
        func receipt() throws -> Data { try data([
            "therapist_id": owner, "consent_type": PatientNameRules.type, "required_version": PatientNameRules.version,
            "accepted_version": consent == "accepted" ? PatientNameRules.version as Any : NSNull(),
            "accepted_at": consent == "accepted" ? date as Any : NSNull(), "revoked_at": consent == "revoked" ? date as Any : NSNull(),
            "status": consent, "revision": consentRevision]) }
        func call(_ method: String, _ data: Data) throws -> Data {
            let p = try JSONSerialization.jsonObject(with: data) as! [String: Any]; calls.append((method, p))
            if method == "get_my_consent" { if lookupFailure { throw NameSyncFailure(code: "connection") }; return try receipt() }
            if method == "record_my_consent" {
                if let consentError { throw NameSyncFailure(code: consentError) }
                consent = p["p_decision"] as! String; consentRevision += 1
                if uncertainConsent { throw NameSyncFailure(code: "connection") }
                return try receipt()
            }
            if let nameFailure { throw nameFailure }
            if let nameError { throw NameSyncFailure(code: nameError) }
            if p["operation"] as? String == "list" {
                lists += 1; let last = paginated && p["after"] is String
                return try self.data(["names": last || emptyPage ? [] : [["patient_id": id, "name": name as Any? ?? NSNull(), "revision": revision, "updated_at": name == nil ? NSNull() : date as Any]], "next_after": paginated && !last ? id as Any : NSNull()])
            }
            sets += 1; try onSet?(p)
            let incoming = p["name"] as! String
            if incoming != name && p["expected_revision"] as? String != revision { throw NameSyncFailure(code: "revision_conflict") }
            let unchanged = incoming == name
            name = incoming; revision = String((Int64(revision) ?? 0) + (unchanged ? 0 : 1))
            return try self.data(["patient_id": id, "revision": revision, "updated_at": date, "unchanged": unchanged])
        }
    }
    func testInlineNamesAndNullAvoidListButMissingUsesCompatibility() async throws {
        let h = Harness(); h.sync.waitForPatientRows = true
        await h.sync.refresh(force: true); XCTAssertEqual(h.lists, 0)
        try h.sync.receivePatientRows([ClinicalLoadedRecord(values: ["id": .string(h.id.uppercased()), "decryptedName": .string("שם שרת")])])
        await h.sync.refresh(force: true)
        XCTAssertEqual(h.sync.displayed(h.id, legacy: nil), "שם שרת"); XCTAssertEqual(h.lists, 0)
        try h.sync.receivePatientRows([ClinicalLoadedRecord(values: ["id": .string(h.id), "decryptedName": .null])])
        await h.sync.refresh(force: true)
        XCTAssertNil(h.sync.displayed(h.id, legacy: nil)); XCTAssertEqual(h.lists, 0)
        try h.sync.receivePatientRows([ClinicalLoadedRecord(values: ["id": .string(h.id)])])
        await h.sync.refresh(force: true); XCTAssertEqual(h.lists, 1)
    }
    func testInlineNameDoesNotReplaceWriteRevisionLookupOrPersistName() async throws {
        let h = Harness()
        try h.sync.receivePatientRows([ClinicalLoadedRecord(values: ["id": .string(h.id), "decryptedName": .string("שם שרת")])])
        await h.sync.refresh(force: true)
        XCTAssertFalse(h.disk.values.values.contains { String(data: $0, encoding: .utf8)?.contains("שם שרת") == true })
        try await h.sync.edit(h.id, name: "שם חדש")
        XCTAssertEqual(h.lists, 1); XCTAssertEqual(h.sets, 1)
        XCTAssertEqual(h.sync.displayed(h.id, legacy: nil), "שם חדש")
        h.sync.setAccount(nil); XCTAssertNil(h.sync.displayed(h.id, legacy: nil))
    }
    func testPagedInlineNamesResolveTogetherWithoutDirectoryLookup() async throws {
        let h = Harness(); let second = "22222222-2222-4222-8222-222222222222"
        var calls = 0
        let records = try await ClinicalRecordLoad.pages(endpoint: "load-patients", checkpoint: {}, invoke: { _, body in
            calls += 1
            XCTAssertNil(body["include_names"])
            if calls == 1 { return ["records": .array([.object(["id": .string(h.id), "_version": .string("v"), "decryptedName": .string("inline")])]), "next_cursor": .string("next")] }
            XCTAssertEqual(body["cursor"], .string("next"))
            return ["records": .array([.object(["id": .string(second), "_version": .string("v"), "decryptedName": .null])]), "next_cursor": .null]
        })
        try h.sync.receivePatientRows(records)
        await h.sync.refresh(force: true)
        XCTAssertEqual(calls, 2); XCTAssertEqual(h.lists, 0)
        XCTAssertEqual(h.sync.displayed(h.id, legacy: nil), "inline")
        XCTAssertNil(h.sync.displayed(second, legacy: nil))
    }
    func testCompatibilityReadCannotReplaceExplicitNullFromAnotherRow() async throws {
        let h = Harness(); h.name = "directory name must not override null"
        let other = "22222222-2222-4222-8222-222222222222"
        try h.sync.receivePatientRows([
            ClinicalLoadedRecord(values: ["id": .string(h.id), "decryptedName": .null]),
            ClinicalLoadedRecord(values: ["id": .string(other)])])
        await h.sync.refresh(force: true)
        XCTAssertEqual(h.lists, 1)
        XCTAssertNil(h.sync.displayed(h.id, legacy: nil))
    }
    func testInlineNullKeepsLegacyWithoutReadingServer() async throws {
        let h = Harness(); h.consent = "required"
        h.sync.readLegacy = { _ in "שם מקומי" }
        try h.sync.receivePatientRows([ClinicalLoadedRecord(values: ["id": .string(h.id), "decryptedName": .null])])
        await h.sync.refresh(force: true)
        XCTAssertEqual(h.sync.displayed(h.id, legacy: nil), "שם מקומי")
        XCTAssertEqual(h.lists, 0); XCTAssertEqual(h.sets, 0)
        await h.sync.decide()
        await h.sync.refresh(force: true)
        XCTAssertEqual(h.sets, 1)
    }
    func testLegacyRequiresApprovalButDoesNotUpload() async {
        let h=Harness(); h.consent="required"; await h.sync.refresh(force:true)
        XCTAssertTrue(h.sync.shouldGate(therapist:true,demo:false)); XCTAssertEqual(h.lists,1); XCTAssertEqual(h.sets,0)
    }
    func testNoLegacyNeverShowsMigrationEvenWithoutConsent() async {
        let h=Harness(); h.sync.register([h.id:nil]); h.consent="required"
        await h.sync.refresh(force:true)
        XCTAssertFalse(h.sync.shouldGate(therapist:true,demo:false)); XCTAssertEqual(h.sets,0); XCTAssertEqual(h.lists,1)
        XCTAssertFalse(h.calls.contains { $0.0 != "patient-names" })
        XCTAssertFalse(h.sync.accepted)
    }
    func testConfirmedCacheIsNotLegacyAndIsNotPersisted() async throws {
        let disk=Memory(); var snapshot=PatientNameSyncSnapshot()
        snapshot.entries[patient]=PatientNameEntry(confirmed:"server cached",revision:"3",initialized:true)
        try disk.save(snapshot,key:account)
        let h=Harness(disk);h.consent="required";await h.sync.refresh(force:true)
        XCTAssertFalse(h.sync.shouldGate(therapist:true,demo:false))
        XCTAssertNil(h.sync.displayed(patient,legacy:nil))
        XCTAssertFalse(String(data:disk.values[account]!,encoding:.utf8)!.contains("server cached"))
    }
    func testServerWinnerNeverOverwrittenByLegacy() async {
        let h=Harness();h.name="newer server";h.revision="7";await h.sync.refresh(force:true)
        XCTAssertEqual(h.sets,0);XCTAssertEqual(h.sync.displayed(patient,legacy:nil),"newer server")
    }
    func testMigrationPersistsOnlyUnfinishedInputAndResumes() async {
        let h=Harness();h.onSet={_ in throw NameSyncFailure(code:"connection")};await h.sync.refresh(force:true)
        XCTAssertTrue(h.sync.hasPending)
        let next=Harness(h.disk);await next.sync.refresh(force:true)
        XCTAssertEqual(next.sets,1);XCTAssertFalse(next.sync.hasPending)
        XCTAssertFalse(String(data:h.disk.values[account]!,encoding:.utf8)!.contains("שם בדיקה"))
    }
    func testApprovedMigrationDoesNotAskAgainWhileOffline() async {
        let h=Harness();h.consent="required";h.onSet={_ in throw NameSyncFailure(code:"connection")}
        await h.sync.refresh(force:true);XCTAssertTrue(h.sync.shouldGate(therapist:true,demo:false))
        await h.sync.decide()
        for _ in 0..<100 {if h.sets>0 && !h.sync.busy {break};await Task.yield()}
        XCTAssertEqual(h.calls.filter {$0.0=="record_my_consent"}.count,1)
        XCTAssertTrue(h.sync.hasPending);XCTAssertFalse(h.sync.approvalFailed)
        let next=Harness(h.disk);next.consent="required";next.lookupFailure=true;next.nameError="connection"
        await next.sync.refresh(force:true)
        XCTAssertFalse(next.sync.shouldGate(therapist:true,demo:false));XCTAssertTrue(next.sync.hasPending);XCTAssertFalse(next.sync.approvalFailed)
        next.nameError=nil;await next.sync.refresh(force:true)
        XCTAssertFalse(next.sync.hasPending);XCTAssertEqual(next.sets,1)
        XCTAssertFalse(next.sync.shouldGate(therapist:true,demo:false))
        XCTAssertTrue(next.calls.allSatisfy {$0.0=="patient-names"})
    }
    func testCreateAndRenameAreAwaitedAndNotPersisted() async throws {
        let h=Harness();h.sync.register([h.id:nil]);await h.sync.refresh(force:true)
        try await h.sync.rememberCreated(patient,name:"created synthetic")
        try await h.sync.edit(patient,name:"renamed synthetic")
        XCTAssertEqual(h.sync.displayed(patient,legacy:nil),"renamed synthetic")
        XCTAssertFalse(String(data:h.disk.values[account]!,encoding:.utf8)!.contains("synthetic"))
    }
    func testFailedRenameLeavesExistingResultAndNoQueue() async {
        let h=Harness();h.name="existing";h.revision="1";await h.sync.refresh(force:true)
        h.onSet={_ in throw NameSyncFailure(code:"connection")}
        do {try await h.sync.edit(patient,name:"unsaved");XCTFail("must fail")}catch{}
        XCTAssertEqual(h.sync.displayed(patient,legacy:nil),"existing");XCTAssertFalse(h.sync.hasPending)
    }
    func testConflictAndAccountSwitchDoNotReportSaved() async {
        let h=Harness();await h.sync.refresh(force:true)
        h.onSet={_ in throw NameSyncFailure(code:"revision_conflict")}
        do {try await h.sync.edit(patient,name:"unsaved");XCTFail("must fail")}catch{}
        h.onSet={_ in h.sync.setAccount("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")}
        do {try await h.sync.edit(patient,name:"unsaved");XCTFail("must cancel")}catch{}
        XCTAssertNil(h.sync.displayed(patient,legacy:nil))
    }
    func testPatientAndDemoModesNeverUpload() async {
        let h=Harness();h.allowed=false;await h.sync.refresh(force:true);XCTAssertTrue(h.calls.isEmpty)
    }

    func testApprovalReleasesWorkspaceBeforeSlowUploadCompletes() async {
        let h=Harness();h.consent="required"
        var release: CheckedContinuation<Void,Never>?
        let sync=PatientNameSync(call:{ method,data in
            if method=="patient-names", h.consent=="accepted", release == nil { await withCheckedContinuation { release=$0 } }
            return try h.call(method,data)
        },storage:h.disk,eligible:{true},fullAccess:{true})
        sync.setAccount(account);sync.register([patient:"synthetic legacy"])
        await sync.refresh(force:true);XCTAssertTrue(sync.shouldGate(therapist:true,demo:false))
        await sync.decide()
        for _ in 0..<100 { if release != nil {break};await Task.yield() }
        XCTAssertTrue(sync.accepted);XCTAssertFalse(sync.shouldGate(therapist:true,demo:false));XCTAssertTrue(sync.hasPending)
        release?.resume()
        for _ in 0..<100 { if !sync.busy {break};await Task.yield() }
        XCTAssertFalse(sync.hasPending);XCTAssertEqual(h.sets,1)
    }
    func testConfirmedMigrationNeverReadsLegacyAgainAfterRelaunch() async {
        let h=Harness();var reads=0
        h.sync.readLegacy={_ in reads += 1;return "synthetic legacy"}
        await h.sync.refresh(force:true);XCTAssertEqual(reads,1)
        await h.sync.refresh(force:true);XCTAssertEqual(reads,1)
        let next=Harness(h.disk);next.sync.readLegacy={_ in XCTFail("legacy must not be read");return nil}
        await next.sync.refresh(force:true);XCTAssertFalse(next.sync.hasPending)
    }
    func testInaccessibleLegacyIsNotTreatedAsMissing() async {
        let h=Harness();h.sync.readLegacy={_ in throw NameSyncFailure(code:"local_storage")}
        await h.sync.refresh(force:true)
        XCTAssertFalse(h.sync.migrationComplete);XCTAssertTrue(h.sync.failed);XCTAssertEqual(h.sets,0)
    }

    func testOlderRefreshCannotUndoRenameAndConfirmedMissingClearsName() async throws {
        let h=Harness();h.name="original";h.revision="7";await h.sync.refresh(force:true)
        try await h.sync.edit(patient,name:"renamed")
        h.name="stale response";h.revision="7";await h.sync.refresh(force:true)
        XCTAssertEqual(h.sync.displayed(patient,legacy:nil),"renamed")
        h.name=nil;h.revision="9";await h.sync.refresh(force:true)
        XCTAssertNil(h.sync.displayed(patient,legacy:nil))
    }
    func testMalformedResponseIsNotAConfirmedWrite() async {
        let h=Harness()
        let sync=PatientNameSync(call:{method,data in
            let p=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any]
            if p?["operation"] as? String == "set" { return Data("{}".utf8) }
            return try h.call(method,data)
        },storage:h.disk,eligible:{true},fullAccess:{true})
        sync.setAccount(account);sync.register([patient:nil]);await sync.refresh(force:true)
        do {try await sync.edit(patient,name:"unsaved");XCTFail("invalid response must fail")}catch{}
        XCTAssertNil(sync.displayed(patient,legacy:nil));XCTAssertFalse(sync.hasPending)
    }
    func testWrongAccountTypeVersionAndMalformedReceiptRejected() {
        for (owner, type, version, revision) in [("wrong", PatientNameRules.type, PatientNameRules.version, Int64(0)),
            (account, "other_type", PatientNameRules.version, 0), (account, PatientNameRules.type, "old", 0),
            (account, PatientNameRules.type, PatientNameRules.version, -1)] {
            let receipt = NameConsentReceipt(therapist_id: owner, consent_type: type, required_version: version,
                accepted_version: version, accepted_at: stamp, revoked_at: nil, status: "accepted", revision: revision)
            XCTAssertThrowsError(try receipt.validate(account: account))
        }
    }
    func testDeletionAndAccountSwitchIgnoreInFlightResult() async {
        let h = Harness(); h.onSet = { _ in h.sync.beginDeletion(h.id); h.sync.remove(h.id) }
        await h.sync.refresh(force: true); XCTAssertNil(h.sync.displayed(patient, legacy: nil))
        let other = Harness(); other.onSet = { _ in other.sync.setAccount("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb") }
        await other.sync.refresh(force: true); XCTAssertNil(other.sync.displayed(patient, legacy: nil))
    }
    func testExactConsentRetryAcrossRelaunchAndSupersession() async {
        let h = Harness(); h.consent = "required"; h.uncertainConsent = true; await h.sync.decide()
        XCTAssertEqual(h.lists, 0)
        let original = h.calls.first { $0.0 == "record_my_consent" }!.1
        let next = Harness(h.disk); next.consentError = "consent_request_superseded"; next.consent = "revoked"
        await next.sync.decide(); XCTAssertFalse(next.sync.accepted); XCTAssertEqual(next.lists, 0)
        let retried = next.calls.first { $0.0 == "record_my_consent" }!.1
        XCTAssertEqual(original as NSDictionary, retried as NSDictionary)
    }
    func testMigrationPartialUploadResumesOnlyRemainingPatient() async throws {
        let h = Harness(); let second = "22222222-2222-2222-2222-222222222222"
        var names: [String: String] = [:]; var failSecond = true; var writes = 0
        let call: PatientNameSync.Call = { method, data in
            if method != "patient-names" { return try h.call(method, data) }
            let p = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            if p["operation"] as? String == "list" {
                return try h.data(["names": [h.id, second].map { id -> [String: Any] in
                    ["patient_id": id, "name": names[id] as Any? ?? NSNull(), "revision": names[id] == nil ? "0" : "1", "updated_at": NSNull()]
                }, "next_after": NSNull()])
            }
            let id = p["patient_id"] as! String
            if id == second && failSecond { throw NameSyncFailure(code: "connection") }
            names[id] = p["name"] as? String; writes += 1
            return try h.data(["patient_id": id, "revision": "1", "updated_at": h.date, "unchanged": false])
        }
        func make() -> PatientNameSync {
            let sync = PatientNameSync(call: call, storage: h.disk, eligible: { true }, fullAccess: { true })
            sync.setAccount(h.owner); sync.loadOwned = { [h.id: "ראשון", second: "שני"] }; return sync
        }
        let first = make(); await first.refresh(force: true)
        XCTAssertFalse(first.migrationComplete); XCTAssertEqual(writes, 1)
        XCTAssertEqual(first.displayed(second, legacy: nil), "שני")
        failSecond = false
        let relaunched = make(); await relaunched.retryMigration()
        XCTAssertTrue(relaunched.migrationComplete); XCTAssertEqual(writes, 2)
    }
    func testUnicodeValidation() {
        XCTAssertTrue(PatientNameRules.valid("  שם  בדיקה  "))
        XCTAssertTrue(PatientNameRules.valid(String(repeating: "😀", count: 200)))
        XCTAssertFalse(PatientNameRules.valid(String(repeating: "😀", count: 201)))
        for bad in ["", "  ", "שם\n", "\u{0}", "\u{7f}"] { XCTAssertFalse(PatientNameRules.valid(bad)) }
    }
    func testInaccessibleFormerPatientDoesNotTriggerApproval() async throws {
        let disk=Memory();var snapshot=PatientNameSyncSnapshot()
        snapshot.entries[patient]=PatientNameEntry(pending:PatientNameEdit(name:"legacy unavailable patient",initial:true))
        try disk.save(snapshot,key:account)
        let h=Harness(disk);h.consent="required";h.sync.loadOwned={[:]}
        await h.sync.refresh(force:true)
        XCTAssertFalse(h.sync.shouldGate(therapist:true,demo:false));XCTAssertEqual(h.sets,0)
        // Unconfirmed legacy recovery input is retained, never deleted or uploaded to an unowned patient.
        XCTAssertTrue(String(data:disk.values[account]!,encoding:.utf8)!.contains("legacy unavailable patient"))
    }
    func testCleanAccountReadsCreatesAndRenamesWithoutAnyNameConsentRPC() async throws {
        let h=Harness();h.consent="required";h.lookupFailure=true
        h.sync.register([patient:nil]);h.name="fetched synthetic";h.revision="1"
        await h.sync.refresh(force:true)
        XCTAssertEqual(h.sync.displayed(patient,legacy:nil),"fetched synthetic")
        XCTAssertFalse(h.sync.shouldGate(therapist:true,demo:false));XCTAssertFalse(h.sync.failed)
        try await h.sync.rememberCreated(patient,name:"created synthetic")
        try await h.sync.edit(patient,name:"renamed synthetic")
        XCTAssertEqual(h.sync.displayed(patient,legacy:nil),"renamed synthetic")
        XCTAssertTrue(h.calls.allSatisfy { $0.0 == "patient-names" })
        XCTAssertFalse(h.sync.hasPending)
        let stored=String(data:h.disk.values[account]!,encoding:.utf8)!
        for name in ["fetched synthetic","created synthetic","renamed synthetic"] {XCTAssertFalse(stored.contains(name))}
        h.sync.setAccount(nil);XCTAssertNil(h.sync.displayed(patient,legacy:nil))
    }
    func testBackendConsentRejectionOnCleanAccountFailsWithoutPromptOrRecordingReceipt() async {
        let h=Harness();h.sync.register([patient:nil]);h.consent="required";h.nameError="consent_required"
        await h.sync.refresh(force:true)
        XCTAssertTrue(h.sync.failed);XCTAssertFalse(h.sync.shouldGate(therapist:true,demo:false))
        do {try await h.sync.rememberCreated(patient,name:"unsaved synthetic");XCTFail("backend rejection must fail")}
        catch {XCTAssertEqual((error as? NameSyncFailure)?.code,"consent_required")}
        XCTAssertNil(h.sync.displayed(patient,legacy:nil));XCTAssertFalse(h.sync.hasPending)
        XCTAssertTrue(h.calls.allSatisfy { $0.0 == "patient-names" })
    }
    func testBackendSetRejectionKeepsExistingNameAndNoOfflineQueue() async {
        let h=Harness();h.sync.register([patient:nil]);h.name="existing synthetic";h.revision="3"
        await h.sync.refresh(force:true);h.onSet={_ in throw NameSyncFailure(code:"consent_required")}
        do {try await h.sync.edit(patient,name:"unsaved synthetic");XCTFail("must fail")}
        catch {XCTAssertEqual((error as? NameSyncFailure)?.code,"consent_required")}
        XCTAssertEqual(h.sync.displayed(patient,legacy:nil),"existing synthetic");XCTAssertFalse(h.sync.hasPending)
        XCTAssertTrue(h.calls.allSatisfy { $0.0 == "patient-names" })
    }
    func testCleanAccountDoesNotReplayAnOldApprovalDecisionWithoutLegacyInput() async throws {
        let h=Harness();var snapshot=PatientNameSyncSnapshot()
        snapshot.consentDecision=NameConsentDecision(p_decision:"accepted",p_request_id:"old-request",p_expected_revision:0)
        try h.disk.save(snapshot,key:account)
        let next=Harness(h.disk);next.sync.register([patient:nil]);next.consent="required"
        await next.sync.refresh(force:true)
        XCTAssertFalse(next.sync.shouldGate(therapist:true,demo:false));XCTAssertEqual(next.lists,1)
        XCTAssertTrue(next.calls.allSatisfy { $0.0 == "patient-names" })
    }
    func testBackgroundFailureOnLegacyGateDoesNotBecomeApprovalError() async {
        let h=Harness();h.consent="required";await h.sync.refresh(force:true)
        XCTAssertTrue(h.sync.shouldGate(therapist:true,demo:false))
        h.nameError="connection";await h.sync.refresh(force:true)
        // Previously this shared failure directly rendered the sync-error/retry UI.
        XCTAssertTrue(h.sync.failed);XCTAssertFalse(h.sync.approvalFailed)
        XCTAssertTrue(h.sync.hasPending)
    }
    func testFailedBackgroundRefreshRetainsMemoryAndCleanAccountHasNoUI() async {
        let h=Harness();h.sync.register([patient:nil]);h.name="synthetic loaded";h.revision="1"
        await h.sync.refresh(force:true);h.nameError="connection";await h.sync.refresh(force:true)
        XCTAssertEqual(h.sync.displayed(patient,legacy:nil),"synthetic loaded")
        XCTAssertFalse(h.sync.approvalFailed);XCTAssertFalse(h.sync.shouldGate(therapist:true,demo:false))
        h.nameError=nil;h.emptyPage=true;await h.sync.refresh(force:true)
        XCTAssertFalse(h.sync.failed);XCTAssertFalse(h.sync.approvalFailed)
    }
    func testCancelledBackgroundRequestIsNotFailure() async {
        let h=Harness();h.sync.register([patient:nil]);h.nameFailure=URLError(.cancelled)
        await h.sync.refresh(force:true)
        XCTAssertFalse(h.sync.failed);XCTAssertFalse(h.sync.approvalFailed)
        h.nameFailure=CancellationError();await h.sync.refresh(force:true)
        XCTAssertFalse(h.sync.failed);XCTAssertFalse(h.sync.approvalFailed)
    }
    func testExplicitApprovalErrorIsSeparateFromAutomaticDecisionResume() async {
        let h=Harness();h.consent="required";await h.sync.refresh(force:true)
        h.consentError="connection";await h.sync.decide()
        XCTAssertTrue(h.sync.approvalFailed)
        let next=Harness(h.disk);next.consent="required";next.consentError="connection"
        await next.sync.refresh(force:true)
        XCTAssertTrue(next.sync.failed);XCTAssertFalse(next.sync.approvalFailed)
        XCTAssertTrue(next.sync.hasPending)
    }

    func testCancelledApprovedUploadResumesSilentlyAfterRelaunch() async {
        let h=Harness();h.onSet={_ in throw CancellationError()}
        await h.sync.refresh(force:true)
        XCTAssertTrue(h.sync.hasPending);XCTAssertFalse(h.sync.failed);XCTAssertFalse(h.sync.approvalFailed)
        XCTAssertFalse(h.sync.shouldGate(therapist:true,demo:false))
        let next=Harness(h.disk);next.consent="required";next.lookupFailure=true
        await next.sync.refresh(force:true)
        XCTAssertEqual(next.sets,1);XCTAssertFalse(next.sync.hasPending)
        XCTAssertFalse(next.sync.approvalFailed);XCTAssertFalse(next.sync.shouldGate(therapist:true,demo:false))
        XCTAssertTrue(next.calls.allSatisfy {$0.0=="patient-names"})
    }
    func testEmptyPageRetainsUnconfirmedLegacyWithoutSyncFeedback() async {
        let h=Harness();h.emptyPage=true;await h.sync.refresh(force:true)
        XCTAssertTrue(h.sync.hasPending);XCTAssertTrue(h.sync.failed)
        XCTAssertFalse(h.sync.approvalFailed);XCTAssertFalse(h.sync.shouldGate(therapist:true,demo:false))
        XCTAssertEqual(h.sets,0)
    }

}
