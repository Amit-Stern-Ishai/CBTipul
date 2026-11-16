import Foundation
import Testing
import Supabase
@testable import CBTipul

@MainActor
struct AIActionRegressionTests {
    @Test func duplicateSubmissionsAreRejectedUntilCompletion() throws {
        var state = AIActionLifecycle()
        let firstValue = state.begin(owner: "synthetic-owner")
        let first = try #require(firstValue)
        let duplicate = state.begin(owner: "synthetic-owner")
        #expect(duplicate == nil)
        try state.advance(.server, request: first, owner: "synthetic-owner")
        #expect(state.isRunning)
        state.finish(first)
        #expect(!state.isRunning)
        let retry = state.begin(owner: "synthetic-owner")
        #expect(retry != nil)
    }
    @Test func slowResponseKeepsTheActionRunning() async throws {
        var state = AIActionLifecycle()
        let requestValue = state.begin(owner: "synthetic-owner")
        let request = try #require(requestValue)
        try state.advance(.server, request: request, owner: "synthetic-owner")
        try await Task.sleep(for: .milliseconds(30)) // Mocked latency, not a real endpoint measurement.
        #expect(state.isRunning)
        #expect(state.stage == .server)
        try state.advance(.presentation, request: request, owner: "synthetic-owner")
        state.finish(request)
        #expect(!state.isRunning)
    }
    @Test func accountSwitchRejectsOldResponseEvenAfterANewRequestStarts() throws {
        var state = AIActionLifecycle()
        let oldValue = state.begin(owner: "synthetic-a")
        let old = try #require(oldValue)
        #expect(!state.accepts(old, owner: "synthetic-b"))
        #expect(throws: CancellationError.self) {
            try state.advance(.presentation, request: old, owner: "synthetic-b")
        }
        state.invalidate()
        let newValue = state.begin(owner: "synthetic-b")
        let new = try #require(newValue)
        state.finish(old)
        #expect(state.accepts(new, owner: "synthetic-b"))
        #expect(!state.accepts(old, owner: "synthetic-a"))
    }
    @Test func cancelledTaskCannotAdvanceToPresentation() async throws {
        let action = Task { @MainActor in
            var state = AIActionLifecycle()
            let requestValue = state.begin(owner: "synthetic-owner")
        let request = try #require(requestValue)
            withUnsafeCurrentTask { $0?.cancel() }
            #expect(throws: CancellationError.self) {
                try state.advance(.presentation, request: request, owner: "synthetic-owner")
            }
            state.finish(request)
            #expect(!state.isRunning)
        }
        try await action.value
    }
    @Test func signedOutCannotBeginAndInvalidationRejectsLateResults() throws {
        var state = AIActionLifecycle()
        let signedOut = state.begin(owner: nil)
        #expect(signedOut == nil)
        let requestValue = state.begin(owner: "synthetic-owner")
        let request = try #require(requestValue)
        state.invalidate()
        #expect(!state.accepts(request, owner: "synthetic-owner"))
    }
    @Test func timeoutCancellationBackendAndInvalidResponseStayDistinct() {
        #expect(AIActionFailure.from(URLError(.timedOut)) == .timeout)
        #expect(AIActionFailure.from(URLError(.cancelled)) == .cancelled)
        #expect(AIActionFailure.from(CancellationError()) == .cancelled)
        #expect(AIActionFailure.from(FunctionsError.httpError(code: 504, data: Data())) == .timeout)
        #expect(AIActionFailure.from(FunctionsError.httpError(code: 500, data: Data())) == .backend)
        #expect(AIActionFailure.from(AIActionFailure.invalidResponse) == .invalidResponse)
    }
    @Test func malformedResponsesAreNotReportedAsSuccess() {
        let trace = AIActionDiagnostics()
        #expect(throws: DecodingError.self) {
            try trace.decode(WhisperService.PrepareSessionResponse.self, data: Data("{}".utf8), status: 200)
        }
        #expect(throws: DecodingError.self) {
            try trace.decode(WhisperService.SessionReviewResponse.self, data: Data("not-json".utf8), status: 200)
        }
    }
    @Test func successfulResponseDecodesWithoutLosingPreparation() throws {
        let json = #"{"preparation":{"executive_summary":"Synthetic preparation","priority_follow_ups":[],"recurring_nats":[],"cbt_cycles":[],"questionnaire_insights":[],"suggested_questions":[],"assignments_to_check":[]},"usage":{"totalTokens":1}}"#
        let result = try AIActionDiagnostics().decode(WhisperService.PrepareSessionResponse.self, data: Data(json.utf8), status: 200)
        #expect(result.preparation.executiveSummary == "Synthetic preparation")
    }
    @Test func allowanceReceiptsRetainTheirExistingClassification() {
        let error = FunctionsError.httpError(code: 500, data: Data(#"{"monthlyLimit":1,"usedTokens":1,"remainingTokens":0}"#.utf8))
        #expect(AIActionFailure.from(error) == nil)
        #expect(AIActionFailure.message(error) == ClientFailure.monthlyAllowance.localizedDescription)
    }
    @Test func safeErrorsNeverEchoBackendBodiesAndConsentRemainsRequired() {
        let error = FunctionsError.httpError(code: 500, data: Data(#"{"error":"CLINICAL_SENTINEL"}"#.utf8))
        #expect(!AIActionFailure.message(error).contains("CLINICAL_SENTINEL"))
        #expect(!AIActionFailure.message(error).isEmpty)
        #expect(!AIActionFailure.message(AIDataSharingConsentDeclinedError()).isEmpty)
    }
}
