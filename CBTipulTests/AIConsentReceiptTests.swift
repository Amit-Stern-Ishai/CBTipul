import XCTest
import Supabase
@testable import CBTipul

final class AIConsentReceiptTests: XCTestCase {
    func receipt(_ changes: [String: Any] = [:]) throws -> Data {
        var value: [String: Any] = ["therapist_id":"a","consent_type":"ai_data_sharing","required_version":"2026-11-22","accepted_version":"2026-11-22","accepted_at":"2026-11-22T10:00:00Z","revoked_at":NSNull(),"status":"accepted","revision":1]
        value.merge(changes) { _,new in new }
        return try JSONSerialization.data(withJSONObject:value)
    }
    func testAcceptedReceiptAndAccountIsolation() throws {
        let data = try receipt()
        XCTAssertEqual(try AIConsentReceipt.decode(data,account:"a").status,"accepted")
        XCTAssertThrowsError(try AIConsentReceipt.decode(data,account:"b"))
    }
    func testRejectsOldVersionMalformedDatesAndUnsafeRevisions() throws {
        for changes: [String: Any] in [["required_version":"2026-08-29"],["accepted_version":"2026-08-29"],["accepted_at":"bad"],["revoked_at":"2026-11-22T11:00:00Z"],["revision":-1],["revision":9_007_199_254_740_992],["revision":1.5]] {
            XCTAssertThrowsError(try AIConsentReceipt.decode(receipt(changes),account:"a"))
        }
    }
    func testNullsAndMissingKeysAreDifferent() throws {
        let data = try receipt(["status":"required","accepted_at":NSNull(),"accepted_version":NSNull(),"revision":0])
        XCTAssertEqual(try AIConsentReceipt.decode(data,account:"a").status,"required")
        var value = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any]);value.removeValue(forKey:"revoked_at")
        XCTAssertThrowsError(try AIConsentReceipt.decode(JSONSerialization.data(withJSONObject:value),account:"a"))
    }
    func testRetryArgumentsAreFrozen() {
        let decision = AIConsentDecision(revision:42)
        XCTAssertEqual(decision.params,decision.params)
        XCTAssertEqual(decision.params.count,5)
        XCTAssertNotEqual(decision.request,AIConsentDecision(revision:42).request)
    }
}

@MainActor final class AIConsentFlowTests: XCTestCase {
    final class Server {
        var accepted = false
        var failedRead = false
        var loseWrite = false
        var writes: [[String: Supabase.AnyJSON]] = []
        func call(_ method: String, _ args: [String: Supabase.AnyJSON]) async throws -> Data {
            if method == "get_my_consent", failedRead { throw URLError(.notConnectedToInternet) }
            if method == "record_my_consent" {
                writes.append(args); accepted = true
                if loseWrite { loseWrite = false; throw URLError(.timedOut) }
            }
            return try JSONSerialization.data(withJSONObject:["therapist_id":"a","consent_type":"ai_data_sharing","required_version":"2026-11-22","accepted_version":accepted ? "2026-11-22" as Any : NSNull(),"accepted_at":accepted ? "2026-11-22T10:00:00Z" as Any : NSNull(),"revoked_at":NSNull(),"status":accepted ? "accepted":"required","revision":accepted ? 1:0])
        }
    }
    func testReceiptSharedAcrossClients() async {
        let server = Server(), shown = expectation(description:"prompt")
        let first = AIDataSharingConsentStore(call:server.call,eligible:{true},present:{shown.fulfill()});first.configure(account:"a")
        let action = Task { await first.requireConsent() }
        await fulfillment(of:[shown], timeout: 2);await first.accept()
        let result = await action.value; XCTAssertTrue(result)
        let second = AIDataSharingConsentStore(call:server.call,eligible:{true},present:{XCTFail("Receipt should avoid prompt")});second.configure(account:"a")
        let other = await second.requireConsent();XCTAssertTrue(other);XCTAssertEqual(server.writes.count,1)
    }
    func testDeclineAndAccountSwitchCancelWithoutWrites() async {
        for switchAccount in [false,true] {
            let server = Server(), shown = expectation(description:"prompt")
            let store = AIDataSharingConsentStore(call:server.call,eligible:{true},present:{shown.fulfill()});store.configure(account:"a")
            let action = Task { await store.requireConsent() };await fulfillment(of:[shown], timeout: 2)
            if switchAccount { store.configure(account:"b") } else { store.decline() }
            let result = await action.value;XCTAssertFalse(result);XCTAssertTrue(server.writes.isEmpty)
        }
    }
    func testFailedLookupCannotAccept() async {
        let server = Server();server.failedRead = true
        let shown = expectation(description:"prompt")
        let store = AIDataSharingConsentStore(call:server.call,eligible:{true},present:{shown.fulfill()});store.configure(account:"a")
        let action = Task { await store.requireConsent() };await fulfillment(of:[shown], timeout: 2);await store.accept()
        XCTAssertTrue(store.failed);XCTAssertFalse(store.hasAccepted);XCTAssertTrue(server.writes.isEmpty)
        store.decline();let result = await action.value;XCTAssertFalse(result)
    }
    func testLostWriteUsesIdenticalRetry() async {
        let server = Server();server.loseWrite = true
        let shown = expectation(description:"prompt")
        let store = AIDataSharingConsentStore(call:server.call,eligible:{true},present:{shown.fulfill()});store.configure(account:"a")
        let action = Task { await store.requireConsent() };await fulfillment(of:[shown], timeout: 2);await store.accept()
        XCTAssertTrue(store.failed);XCTAssertFalse(store.hasAccepted)
        await store.accept();let result = await action.value;XCTAssertTrue(result);XCTAssertEqual(server.writes[0],server.writes[1])
    }
}
