import Foundation
import Testing
@testable import CBTipul

@MainActor
struct AccountActionsTests {
    struct Failure: Error {}

    @Test func registrationFailureThenFreshCodeRetryDoesNotDeleteOrChangeAccount() async {
        var codes: [String] = []
        var deletes = 0
        let actions = AccountActions(register: { code, token in
            #expect(token == "mock-session-a")
            codes.append(code)
            if codes.count == 1 { throw Failure() }
            return .init(success: true)
        }, delete: { _ in deletes += 1; throw Failure() })
        actions.setIdentity("a")
        await actions.register(code: "mock-code-1", userID: "a", accessToken: "mock-session-a")
        #expect(actions.registrationWarningUserID == "a")
        #expect(!actions.isRegistering)
        await actions.register(code: "mock-code-2", userID: "a", accessToken: "mock-session-a")
        #expect(actions.registrationWarningUserID == nil)
        #expect(codes == ["mock-code-1", "mock-code-2"])
        actions.invalidatePending() // logout does not delete
        actions.setIdentity(nil)
        #expect(deletes == 0)
    }

    @Test func falseRegistrationResponseAndMissingCodeAreNotSuccess() async {
        var calls = 0
        let actions = AccountActions(register: { _, _ in calls += 1; return .init(success: false) },
            delete: { _ in throw Failure() })
        actions.setIdentity("a")
        await actions.register(code: nil, userID: "a", accessToken: "mock")
        #expect(calls == 0)
        #expect(actions.registrationWarningUserID == "a")
        await actions.register(code: "mock-code", userID: "a", accessToken: "mock")
        #expect(calls == 1)
        #expect(actions.registrationWarningUserID == "a")
    }

    @Test func accountSwitchDuringRegistrationDiscardsResult() async {
        var continuation: CheckedContinuation<AppleTokenRegistrationResponse, Error>?
        let actions = AccountActions(register: { _, _ in
            try await withCheckedThrowingContinuation { continuation = $0 }
        }, delete: { _ in throw Failure() })
        actions.setIdentity("a")
        let task = Task { await actions.register(code: "mock", userID: "a", accessToken: "mock") }
        while continuation == nil { await Task.yield() }
        actions.setIdentity(nil)
        actions.setIdentity("b")
        continuation?.resume(throwing: Failure())
        await task.value
        #expect(actions.registrationWarningUserID == nil)
        #expect(!actions.isRegistering)
    }

    @Test func deletionDecodesBothGuidanceValuesAndCleansOnlyOnConfirmedSuccess() async throws {
        for manual in [false, true] {
            var cleaned = false
            let response = try JSONDecoder().decode(AccountDeletionResponse.self,
                from: Data("{\"success\":true,\"deletedImageCount\":0,\"appleManualRevocationRequired\":\(manual)}".utf8))
            let actions = AccountActions(register: { _, _ in throw Failure() }, delete: { _ in
                #expect(!cleaned)
                return response
            })
            actions.setIdentity("a")
            _ = try await actions.delete(userID: "a", accessToken: "mock") { cleaned = true }
            #expect(cleaned)
            #expect(actions.deletionNotice == (manual ? L10n.accountDeletedAppleRevocation : L10n.accountDeletedMessage))
            actions.setIdentity(nil)
            #expect(actions.deletionNotice != nil) // survives routing to login
            #expect(!actions.isDeleting)
        }
    }

    @Test func deletionFailureNeverCleansOrReportsSuccessAndAllowsRetry() async throws {
        var calls = 0
        var cleaned = false
        let actions = AccountActions(register: { _, _ in throw Failure() }, delete: { _ in
            calls += 1
            if calls == 1 { throw Failure() }
            return .init(success: false, appleManualRevocationRequired: false)
        })
        actions.setIdentity("a")
        for _ in 0..<2 {
            do {
                _ = try await actions.delete(userID: "a", accessToken: "mock") { cleaned = true }
                Issue.record("Expected failure")
            } catch { }
            #expect(!cleaned)
            #expect(actions.deletionNotice == nil)
            #expect(!actions.isDeleting)
        }
        #expect(calls == 2)
    }

    @Test func deletionResponseCannotClearAnotherAccountsData() async {
        var continuation: CheckedContinuation<AccountDeletionResponse, Error>?
        var cleaned = false
        let actions = AccountActions(register: { _, _ in throw Failure() }, delete: { _ in
            try await withCheckedThrowingContinuation { continuation = $0 }
        })
        actions.setIdentity("a")
        let task = Task {
            try await actions.delete(userID: "a", accessToken: "mock") { cleaned = true }
        }
        while continuation == nil { await Task.yield() }
        actions.setIdentity("b")
        continuation?.resume(returning: .init(success: true, appleManualRevocationRequired: true))
        _ = await task.result
        #expect(!cleaned)
        #expect(actions.deletionNotice == nil)
    }
    @Test func registrationRequestMatchesContractAndDeletionRequiresConfirmationFields() throws {
        let data = try JSONEncoder().encode(AppleTokenRegistrationRequest(authorizationCode: "mock-code"))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(object == ["authorizationCode": "mock-code"])
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(AccountDeletionResponse.self, from: Data("{\"success\":true}".utf8))
        }
    }

    @Test func logoutAndSameAccountReturnStillInvalidateOldRegistration() async {
        var continuation: CheckedContinuation<AppleTokenRegistrationResponse, Error>?
        let actions = AccountActions(register: { _, _ in
            try await withCheckedThrowingContinuation { continuation = $0 }
        }, delete: { _ in throw Failure() })
        actions.setIdentity("a")
        let task = Task { await actions.register(code: "mock", userID: "a", accessToken: "mock") }
        while continuation == nil { await Task.yield() }
        actions.invalidatePending()
        actions.setIdentity(nil)
        actions.setIdentity("a")
        continuation?.resume(throwing: Failure())
        await task.value
        #expect(actions.registrationWarningUserID == nil)
    }

}
