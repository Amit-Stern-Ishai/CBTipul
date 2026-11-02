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
            if p["operation"] as? String == "list" {
                lists += 1; let last = paginated && p["after"] is String
                return try self.data(["names": last ? [] : [["patient_id": id, "name": name as Any? ?? NSNull(), "revision": revision, "updated_at": name == nil ? NSNull() : date as Any]], "next_after": paginated && !last ? id as Any : NSNull()])
            }
            sets += 1; try onSet?(p)
            let incoming = p["name"] as! String
            if incoming != name && p["expected_revision"] as? String != revision { throw NameSyncFailure(code: "revision_conflict") }
            let unchanged = incoming == name
            name = incoming; revision = String((Int64(revision) ?? 0) + (unchanged ? 0 : 1))
            return try self.data(["patient_id": id, "revision": revision, "updated_at": date, "unchanged": unchanged])
        }
    }
    func testNoApprovalOrFailedLookupNeverRequestsNames() async {
        let h = Harness(); h.consent = "required"; await h.sync.refresh(force: true)
        XCTAssertEqual(h.lists, 0); XCTAssertEqual(h.sets, 0)
        h.lookupFailure = true; await h.sync.refresh(force: true); XCTAssertEqual(h.lists, 0)
        XCTAssertEqual(h.sync.displayed(patient, legacy: "ישן"), "ישן")
    }
    func testExistingAcceptanceAndPaginationMigrate() async {
        let h = Harness(); h.paginated = true; await h.sync.refresh(force: true)
        XCTAssertEqual(h.lists, 2); XCTAssertEqual(h.name, "שם בדיקה"); XCTAssertFalse(h.sync.hasPending)
    }
    func testServerWinsOverLegacyIncludingLaterCloudArrival() async {
        let h = Harness(); h.name = "שרת"; h.revision = "9007199254740993"; await h.sync.refresh(force: true)
        h.sync.register([patient: "iCloud מאוחר"]); await h.sync.refresh(force: true)
        XCTAssertEqual(h.sets, 0); XCTAssertEqual(h.sync.displayed(patient, legacy: "ישן"), "שרת")
    }
    func testConsentRequiredAfterApprovalStopsAndReloadsConsent() async {
        let h = Harness(); h.consent = "required"
        h.onSet = { _ in h.consent = "revoked"; h.consentRevision = 2; throw NameSyncFailure(code: "consent_required") }
        await h.sync.decide(); XCTAssertFalse(h.sync.accepted); XCTAssertEqual(h.sets, 1)
        XCTAssertEqual(h.calls.filter { $0.0 == "get_my_consent" }.count, 2)
    }
    func testLateCloudArrivalFillsOnlyMissingOwnedName() async {
        let h = Harness(); h.sync.register([patient: nil]); var local: String?
        h.sync.readLegacy = { id in XCTAssertEqual(id, self.patient); return local }
        await h.sync.refresh(force: true); XCTAssertEqual(h.sets, 0)
        local = "ערך מאוחר"; await h.sync.refresh(force: true); XCTAssertEqual(h.sets, 1)
        local = "ערך מיושן"; await h.sync.refresh(force: true)
        XCTAssertEqual(h.sets, 1); XCTAssertEqual(h.sync.displayed(patient, legacy: nil), "ערך מאוחר")
    }
    func testInitialRaceAdoptsServerWinner() async {
        let h = Harness(); h.onSet = { _ in h.name = "אחר"; h.revision = "1"; h.onSet = nil }
        await h.sync.refresh(force: true); XCTAssertEqual(h.sets, 1); XCTAssertEqual(h.sync.displayed(patient, legacy: nil), "אחר")
    }
    func testExplicitConflictRetriesLatestRevisionAndCoalesces() async throws {
        let h = Harness(); h.name = "קיים"; h.revision = "1"; await h.sync.refresh(force: true)
        h.onSet = { _ in h.onSet = nil; try h.sync.edit(h.id, name: "חדש"); h.name = "מכשיר אחר"; h.revision = "2" }
        try h.sync.edit(patient, name: "ישן"); await h.sync.refresh(force: true)
        XCTAssertEqual(h.name, "חדש")
        XCTAssertEqual(h.calls.filter { $0.1["operation"] as? String == "set" }.compactMap { $0.1["name"] as? String }, ["ישן", "חדש"])
    }
    func testBoundedRetryAndRelaunchRecovery() async throws {
        let h = Harness(); h.name = "קיים"; h.revision = "1"; await h.sync.refresh(force: true)
        h.onSet = { _ in throw NameSyncFailure(code: "revision_conflict") }
        try h.sync.edit(patient, name: "ממתין"); await h.sync.refresh(force: true)
        XCTAssertEqual(h.sets, 3); XCTAssertTrue(h.sync.hasPending)
        h.allowed = false // no further background work from this simulated process
        let next = Harness(h.disk); next.name = "קיים"; next.revision = "1"
        XCTAssertEqual(next.sync.displayed(patient, legacy: nil), "ממתין")
        await next.sync.refresh(force: true); XCTAssertEqual(next.name, "ממתין")
    }
    func testUncertainNameWriteAdoptsExistingWithoutRepeating() async {
        let h = Harness(); h.onSet = { p in h.name = p["name"] as? String; h.revision = "1"; throw NameSyncFailure(code: "connection") }
        await h.sync.refresh(force: true); h.onSet = nil; await h.sync.refresh(force: true)
        XCTAssertEqual(h.sets, 1); XCTAssertFalse(h.sync.hasPending)
    }
    func testPendingEditSurvivesReadonlyRefresh() async throws {
        let h = Harness(); h.name = "שרת"; h.revision = "1"; h.full = false
        try h.sync.edit(patient, name: "מקומי"); await h.sync.refresh(force: true)
        XCTAssertEqual(h.sets, 0); XCTAssertEqual(h.sync.displayed(patient, legacy: nil), "מקומי")
        h.name = "מקומי"; h.revision = "2"; await h.sync.refresh(force: true)
        XCTAssertFalse(h.sync.hasPending); XCTAssertEqual(h.sets, 0)
    }
    func testReadonlyInitialUploadAndMissingLocal() async {
        let h = Harness(); h.full = false; await h.sync.refresh(force: true); XCTAssertEqual(h.sets, 1)
        let empty = Harness(); empty.sync.register([patient: nil]); await empty.sync.refresh(force: true); XCTAssertEqual(empty.sets, 0)
    }
    func testDeletionAndAccountSwitchIgnoreInFlightResult() async {
        let h = Harness(); h.onSet = { _ in h.sync.beginDeletion(h.id); h.sync.remove(h.id) }
        await h.sync.refresh(force: true); XCTAssertNil(h.sync.displayed(patient, legacy: nil))
        let other = Harness(); other.onSet = { _ in other.sync.setAccount("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb") }
        await other.sync.refresh(force: true); XCTAssertNil(other.sync.displayed(patient, legacy: nil))
    }
    func testPatientAndDemoModesDoNothing() async {
        let h = Harness(); h.allowed = false; await h.sync.refresh(force: true); await h.sync.decide()
        XCTAssertEqual(h.calls.count, 0)
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
    func testRevocationStopsRequestsAndNotificationResolverTracksDisplay() async throws {
        let h = Harness(); var mirrored: String?
        h.sync.changed = { mirrored = h.sync.displayed(h.id, legacy: nil) }
        await h.sync.refresh(force: true); XCTAssertEqual(mirrored, "שם בדיקה")
        h.consent = "revoked"; h.consentRevision = 1
        let before = h.lists; try h.sync.edit(patient, name: "עריכה ממתינה")
        await h.sync.refresh(force: true)
        XCTAssertEqual(h.lists, before); XCTAssertEqual(mirrored, "עריכה ממתינה")
    }
    func testCreatedNameSurvivesTemporaryPersistenceFailure() async {
        let h = Harness(); h.disk.fail = true; h.sync.rememberCreated(patient, name: "שם חדש")
        XCTAssertEqual(h.sync.displayed(patient, legacy: nil), "שם חדש")
        await h.sync.refresh(force: true); XCTAssertEqual(h.sets, 0)
        h.disk.fail = false; await h.sync.refresh(force: true); XCTAssertEqual(h.name, "שם חדש")
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
    func testPersistenceFailureAndUnicodeValidation() throws {
        let h = Harness(); h.disk.fail = true
        XCTAssertThrowsError(try h.sync.edit(patient, name: "בדיקה")); XCTAssertFalse(h.sync.hasPending)
        XCTAssertTrue(PatientNameRules.valid("  שם  בדיקה  "))
        XCTAssertTrue(PatientNameRules.valid(String(repeating: "😀", count: 200)))
        XCTAssertFalse(PatientNameRules.valid(String(repeating: "😀", count: 201)))
        for bad in ["", "  ", "שם\n", "\u{0}", "\u{7f}"] { XCTAssertFalse(PatientNameRules.valid(bad)) }
    }
    func testMigrationMissingConsentBlocksAndLogoutDoesNotUpload() async {
        let h = Harness(); h.consent = "required"
        h.sync.loadOwned = { XCTFail("ownership must wait for consent"); return [:] }
        await h.sync.refresh(force: true)
        XCTAssertTrue(h.sync.shouldGate(therapist: true, demo: false)); XCTAssertEqual(h.lists, 0)
        h.sync.setAccount(nil); XCTAssertEqual(h.sets, 0)
    }
    func testMigrationAcceptanceAndServerAcknowledgementRequired() async {
        let h = Harness(); h.consent = "required"
        h.sync.loadOwned = { [h.id: "שם בדיקה"] }
        h.onSet = { _ in XCTAssertFalse(h.sync.migrationComplete) }
        await h.sync.decide()
        XCTAssertTrue(h.sync.migrationComplete); XCTAssertEqual(h.sets, 1)
    }
    func testMigrationExistingAcceptanceSkipsDecisionAndMissingNamesDoNotBlock() async {
        let h = Harness(); h.sync.loadOwned = { [h.id: nil] }
        await h.sync.refresh(force: true)
        XCTAssertTrue(h.sync.migrationComplete); XCTAssertEqual(h.sets, 0)
        XCTAssertFalse(h.calls.contains { $0.0 == "record_my_consent" })
    }
    func testMigrationFailureRelaunchRetryThenOfflineCompletionAndAccountIsolation() async {
        let h = Harness(); h.sync.loadOwned = { [h.id: "מקומי"] }
        h.onSet = { _ in throw NameSyncFailure(code: "connection") }
        await h.sync.refresh(force: true); XCTAssertFalse(h.sync.migrationComplete)
        XCTAssertEqual(h.sync.displayed(patient, legacy: nil), "מקומי")
        let next = Harness(h.disk); next.sync.loadOwned = { [next.id: "מקומי"] }
        await next.sync.refresh(force: true); XCTAssertTrue(next.sync.migrationComplete)
        let offline = Harness(h.disk); offline.lookupFailure = true
        XCTAssertFalse(offline.sync.shouldGate(therapist: true, demo: false))
        await offline.sync.refresh(force: true); XCTAssertTrue(offline.sync.migrationComplete)
        offline.sync.setAccount("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
        XCTAssertTrue(offline.sync.shouldGate(therapist: true, demo: false))
        XCTAssertFalse(offline.sync.shouldGate(therapist: false, demo: false))
        XCTAssertFalse(offline.sync.shouldGate(therapist: true, demo: true))
    }
    func testMigrationLookupOwnershipAndLocalCheckpointFailuresRemainBlocked() async {
        let h = Harness(); h.lookupFailure = true; await h.sync.refresh(force: true)
        XCTAssertFalse(h.sync.migrationComplete)
        h.lookupFailure = false; h.sync.loadOwned = { throw NameSyncFailure(code: "connection") }
        await h.sync.refresh(force: true); XCTAssertFalse(h.sync.migrationComplete); XCTAssertEqual(h.lists, 0)
        h.sync.loadOwned = { [h.id: "בדיקה"] }
        h.onSet = { _ in h.disk.fail = true }
        await h.sync.refresh(force: true); XCTAssertFalse(h.sync.migrationComplete)
    }
    func testMigrationInitialRaceAdoptsWinnerAndIgnoresUnownedLegacy() async {
        let h = Harness(); h.sync.register(["22222222-2222-2222-2222-222222222222": "לא שייך"])
        h.sync.loadOwned = { [h.id: "מקומי"] }
        h.onSet = { _ in h.name = "שרת"; h.revision = "1"; h.onSet = nil }
        await h.sync.refresh(force: true)
        XCTAssertTrue(h.sync.migrationComplete); XCTAssertEqual(h.sets, 1)
        XCTAssertEqual(h.sync.displayed(patient, legacy: nil), "שרת")
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
    func testMigrationRetryResumesUncertainConsentAfterRelaunch() async {
        let h = Harness(); h.consent = "required"; h.uncertainConsent = true
        await h.sync.decide()
        let next = Harness(h.disk); next.sync.loadOwned = { [next.id: "בדיקה"] }
        await next.sync.retryMigration()
        XCTAssertTrue(next.sync.migrationComplete)
        let original = h.calls.first { $0.0 == "record_my_consent" }!.1
        let retry = next.calls.first { $0.0 == "record_my_consent" }!.1
        XCTAssertEqual(original["p_request_id"] as? String, retry["p_request_id"] as? String)
    }

}
