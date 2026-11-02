import XCTest
@testable import CBTipul

final class SummaryAllowanceTests: XCTestCase {
    func snapshot(tokens: Double = 500, seconds: Double = 60) -> SummaryAIAllowance {
        .init(checkedAt: "2026-10-22T10:00:00Z", usageMonth: "2026-10", resetsAt: "2026-11-01T00:00:00Z",
              chatTokens: .init(limit: 1000, used: 1000 - tokens, remaining: tokens, exhausted: tokens == 0, code: nil),
              transcriptionSeconds: .init(limit: 600, used: 600 - seconds, remaining: seconds, exhausted: seconds == 0, code: nil))
    }
    func testTypedSummaryDoesNotRequireTranscriptionAllowance() throws {
        XCTAssertFalse(try snapshot(seconds: 0).assess(needsTokens: true, recordingSeconds: nil))
    }
    func testVoiceRequiresBothBudgetsAndEnoughDuration() throws {
        XCTAssertThrowsError(try snapshot(tokens: 0).assess(needsTokens: true, recordingSeconds: 1))
        XCTAssertThrowsError(try snapshot(seconds: 0).assess(needsTokens: true, recordingSeconds: 1))
        XCTAssertThrowsError(try snapshot(seconds: 59).assess(needsTokens: true, recordingSeconds: 60)) {
            XCTAssertEqual($0 as? SummaryAllowanceError, .recordingTooLong)
        }
        XCTAssertTrue(try snapshot(seconds: 60).assess(needsTokens: true, recordingSeconds: 60))
    }
    func testCompletedTranscriptRetrySkipsTranscriptionBudget() throws {
        XCTAssertFalse(try snapshot(seconds: 0).assess(needsTokens: true, recordingSeconds: nil))
        XCTAssertFalse(try snapshot(tokens: 0, seconds: 0).assess(needsTokens: false, recordingSeconds: nil))
    }
    func testLowThresholdAndMalformedDuration() throws {
        XCTAssertTrue(try snapshot(tokens: 100).assess(needsTokens: true, recordingSeconds: nil))
        XCTAssertFalse(try snapshot(tokens: 101).assess(needsTokens: true, recordingSeconds: nil))
        XCTAssertThrowsError(try snapshot().assess(needsTokens: true, recordingSeconds: .nan))
    }
    func testLookupFailureIsNotExhaustion() async {
        do {
            _ = try await SummaryAIAllowance.fetch { throw URLError(.timedOut) }
            XCTFail("Lookup must fail")
        } catch { XCTAssertEqual(error as? SummaryAllowanceError, .couldNotCheck) }
    }
    func testEarlySuccessDoesNotOverrideLaterDenial() async throws {
        let early = try await SummaryAIAllowance.fetch { self.snapshot() }
        _ = try early.assess(needsTokens: true, recordingSeconds: nil)
        let later = try await SummaryAIAllowance.fetch { self.snapshot(tokens: 0) }
        XCTAssertThrowsError(try later.assess(needsTokens: true, recordingSeconds: nil)) {
            XCTAssertEqual($0 as? SummaryAllowanceError, .tokensExhausted)
        }
        // A processing-time error remains independent of an earlier successful check.
        XCTAssertEqual(ClientFailure.monthlyAllowance.userFacingMessage, ClientFailure.monthlyAllowance.localizedDescription)
    }
}
