import XCTest
import Supabase
@testable import CBTipul

@MainActor
final class SummaryRecoveryTests: XCTestCase {
    final class MemoryStorage: DraftPersistence {
        var data: [String: Data] = [:]
        var fails = false
        func load<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
            if fails { throw ClientFailure.localDraft }
            return try data[key].map { try JSONDecoder().decode(type, from: $0) }
        }
        func save<T: Encodable>(_ value: T, key: String) throws {
            if fails { throw ClientFailure.localDraft }
            data[key] = try JSONEncoder().encode(value)
        }
        func remove(key: String) throws {
            if fails { throw ClientFailure.localDraft }
            data[key] = nil
        }
    }
    func testRealProtectedStorageRoundTripAndCleanup() throws {
        // Unique synthetic test namespace: never touches application drafts.
        let storage = DeviceDraftStorage(service: "CBTipul.recovery-tests." + UUID().uuidString)
        let key = try DeviceDraftStorage.key(userID: "synthetic-a", kind: "therapist-session", target: "test")
        defer { try? storage.remove(key: key) }
        let draft = DeviceFormDraft<String>(storage: storage)
        XCTAssertNil(draft.restore(userID: "synthetic-a", kind: "therapist-session", target: "test"))
        XCTAssertTrue(draft.save("סיכום בדיקה בלבד", isEmpty: false), "Real Keychain write must succeed")
        let restored = DeviceFormDraft<String>(storage: storage)
        XCTAssertEqual(restored.restore(userID: "synthetic-a", kind: "therapist-session", target: "test"), "סיכום בדיקה בלבד")
        let other = DeviceFormDraft<String>(storage: storage)
        XCTAssertNil(other.restore(userID: "synthetic-b", kind: "therapist-session", target: "test"))
        XCTAssertTrue(restored.discard())
        XCTAssertNil(try storage.load(String.self, key: key))
    }

    func testAudioFileProtectionAndBackupExclusion() throws {
        let file = try SessionAudioRecovery.create(account: "synthetic-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        #if !targetEnvironment(simulator)
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .completeUnlessOpen)
        #else
        // Simulator filesystems do not implement device data-protection classes.
        XCTAssertNotNil(attributes[.size])
        #endif
        XCTAssertEqual(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    func testRelaunchAndAccountIsolation() {
        let storage = MemoryStorage()
        let first = DeviceFormDraft<String>(storage: storage)
        XCTAssertNil(first.restore(userID: "a", kind: "therapist-session", target: "1"))
        XCTAssertTrue(first.save("סיכום מקורי", isEmpty: false))
        let other = DeviceFormDraft<String>(storage: storage)
        XCTAssertNil(other.restore(userID: "b", kind: "therapist-session", target: "1"))
        let relaunched = DeviceFormDraft<String>(storage: storage)
        XCTAssertEqual(relaunched.restore(userID: "a", kind: "therapist-session", target: "1"), "סיכום מקורי")
    }
    func testFailedInitialReadCannotOverwriteUnseenDraft() throws {
        let storage = MemoryStorage()
        let key = try DeviceDraftStorage.key(userID: "a", kind: "therapist-session", target: "1")
        try storage.save("previous protected draft", key: key)
        storage.fails = true
        let draft = DeviceFormDraft<String>(storage: storage)
        XCTAssertNil(draft.restore(userID: "a", kind: "therapist-session", target: "1"))
        storage.fails = false
        XCTAssertFalse(draft.save("new text", isEmpty: false))
        XCTAssertEqual(try storage.load(String.self, key: key), "previous protected draft")
        let reopened = DeviceFormDraft<String>(storage: storage)
        XCTAssertEqual(reopened.restore(userID: "a", kind: "therapist-session", target: "1"), "previous protected draft")
    }

    func testPersistenceFailureDoesNotClaimSuccessOrEraseDraft() {
        let storage = MemoryStorage()
        let draft = DeviceFormDraft<String>(storage: storage)
        _ = draft.restore(userID: "a", kind: "therapist-session", target: "1")
        XCTAssertTrue(draft.save("previous", isEmpty: false))
        storage.fails = true
        XCTAssertFalse(draft.save("changed", isEmpty: false))
        XCTAssertTrue(draft.hasError)
        XCTAssertFalse(draft.discard())
        storage.fails = false
        let reloaded = DeviceFormDraft<String>(storage: storage)
        XCTAssertEqual(reloaded.restore(userID: "a", kind: "therapist-session", target: "1"), "previous")
        XCTAssertTrue(reloaded.discard())
        XCTAssertTrue(storage.data.isEmpty)
    }
    func testTranscriptAndUncertainInsertSurviveRelaunch() throws {
        let value = SessionRecovery(date: .now, notes: "תמלול מקורי", type: nil,
            structuredNotes: nil, selectedPatientID: nil, audioFileName: UUID().uuidString + ".m4a",
            transcriptReady: true, pendingCreation: true)
        let restored = try JSONDecoder().decode(SessionRecovery.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored.notes, "תמלול מקורי")
        XCTAssertEqual(restored.transcriptReady, true)
        XCTAssertEqual(restored.pendingCreation, true)
        XCTAssertEqual(restored.audioFileName, value.audioFileName)
    }
    func testAudioPathCannotEscapeOrCrossAccounts() throws {
        let name = UUID().uuidString + ".m4a"
        XCTAssertNotEqual(try SessionAudioRecovery.resolve(name: name, account: "a"),
                          try SessionAudioRecovery.resolve(name: name, account: "b"))
        XCTAssertThrowsError(try SessionAudioRecovery.resolve(name: "../" + name, account: "a"))
    }
    func testAccountChangeClearsPreparedText() {
        let gate = ClinicalTextGate { _ in "safe" }
        gate.restorePrepared(original: "synthetic original", anonymized: "safe")
        XCTAssertFalse(gate.requiresProcessing("synthetic original"))
        gate.resetForAccountChange()
        XCTAssertTrue(gate.requiresProcessing("synthetic original"))
        XCTAssertTrue(gate.requiresProcessing("safe"))
    }

    func testStructuredFailureClassification() {
        XCTAssertEqual(ClientFailure.classify(status: 429, code: nil), .rateLimited)
        XCTAssertEqual(ClientFailure.classify(status: 429, code: "monthly_quota_exceeded"), .monthlyAllowance)
        XCTAssertEqual(ClientFailure.classify(status: 401, code: nil), .expiredLogin)
        XCTAssertEqual(ClientFailure.classify(status: 403, code: nil), .restricted)
        XCTAssertEqual(ClientFailure.classify(status: 409, code: nil), .conflict)
        XCTAssertEqual(ClientFailure.classify(status: 503, code: nil), .service)
        XCTAssertEqual(ClientFailure.from(URLError(.timedOut)), .connection)
        let raw = FunctionsError.httpError(code: 429, data: Data("{\"error\":\"monthly quota exceeded\"}".utf8))
        XCTAssertEqual(ClientFailure.from(raw), .rateLimited)
    }
    func testAnonymizationFailureNeverReturnsOriginalAndRetryUsesPreparedResult() async throws {
        let failing = ClinicalTextGate { _ in throw ClientFailure.monthlyAllowance }
        do { _ = try await failing.prepare("original"); XCTFail("Must fail closed") }
        catch { XCTAssertEqual(error as? ClientFailure, .monthlyAllowance) }
        let recovered = ClinicalTextGate { _ in XCTFail("Must reuse protected receipt"); return "unexpected" }
        recovered.restorePrepared(original: "original", anonymized: "safe")
        let result = try await recovered.prepare("original")
        XCTAssertEqual(result, "safe")
    }
}
