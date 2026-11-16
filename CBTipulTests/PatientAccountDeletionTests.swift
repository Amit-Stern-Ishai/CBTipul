import XCTest
import Supabase
@testable import CBTipul

@MainActor final class PatientAccountDeletionTests: XCTestCase {
    func testStrictReceipt() throws {
        try validatePatientDeletionReceipt(status: 200, data: Data(#"{"deleted":true}"#.utf8))
        for body in [#"{"deleted":false}"#, #"{"deleted":"true"}"#, "{}"] {
            XCTAssertThrowsError(try validatePatientDeletionReceipt(status: 200, data: Data(body.utf8)))
        }
        XCTAssertThrowsError(try validatePatientDeletionReceipt(status: 202, data: Data(#"{"deleted":true}"#.utf8)))
    }
    func testRejectedAndUnauthorizedDoNotResetSession() async {
        for status in [401, 403, 422] {
            var resets = 0
            let model = PatientAccountDeletion(identity: { "patient" }, request: { throw FunctionsError.httpError(code: status, data: Data()) }, checkSession: {}, cleanup: { resets += 1 })
            model.ask(); await model.confirm()
            XCTAssertEqual(resets, 0)
            XCTAssertEqual(model.state, status == 401 ? .sessionUnverified : .rejected)
        }
    }
    func testCancelAndSuccess() async {
        var calls = 0; var resets = 0
        let model = PatientAccountDeletion(identity: { "patient" }, request: { calls += 1 }, checkSession: {}, cleanup: { resets += 1 })
        model.ask(); model.cancel(); await model.confirm()
        XCTAssertEqual(calls, 0)
        model.ask(); await model.confirm(); await model.confirm()
        XCTAssertEqual(calls, 1); XCTAssertEqual(resets, 1); XCTAssertEqual(model.state, .deleted)
    }
    func testUncertainRequiresSessionCheck() async {
        var calls = 0; var resets = 0
        let model = PatientAccountDeletion(identity: { "patient" }, request: { calls += 1; throw URLError(.timedOut) }, checkSession: {}, cleanup: { resets += 1 })
        model.ask(); await model.confirm(); model.ask(); await model.confirm()
        XCTAssertEqual(calls, 1); XCTAssertEqual(resets, 0); XCTAssertEqual(model.state, .uncertain)
        await model.recheck(); XCTAssertEqual(model.state, .retryable)
        model.ask(); await model.confirm(); XCTAssertEqual(calls, 2)
    }
    func testFailedCheckAndAccountSwitch() async {
        var owner = "first"; var resets = 0
        let model = PatientAccountDeletion(identity: { owner }, request: { owner = "second" }, checkSession: {}, cleanup: { resets += 1 })
        model.ask(); await model.confirm(); XCTAssertEqual(resets, 0)
        let failed = PatientAccountDeletion(identity: { owner }, request: { throw URLError(.timedOut) }, checkSession: { throw URLError(.notConnectedToInternet) }, cleanup: { resets += 1 })
        failed.ask(); await failed.confirm(); await failed.recheck(); failed.ask()
        XCTAssertEqual(failed.state, .sessionUnverified); XCTAssertEqual(resets, 0)
    }
}
