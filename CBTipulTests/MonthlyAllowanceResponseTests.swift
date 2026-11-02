import XCTest
import Supabase
@testable import CBTipul

final class MonthlyAllowanceResponseTests: XCTestCase {
    func failure(_ json: String, status: Int = 429) -> ClientFailure {
        ClientFailure.from(FunctionsError.httpError(code: status, data: Data(json.utf8)))
    }
    func testSuppliedResponseAndExactLimit() {
        XCTAssertEqual(failure(#"{"error":"Monthly chat token limit exceeded","monthlyLimit":1000000,"usedTokens":1004700,"remainingTokens":0}"#), .monthlyAllowance)
        XCTAssertEqual(failure(#"{"monthlyLimit":1000000,"usedTokens":1000000,"remainingTokens":0}"#), .monthlyAllowance)
    }
    func testMessageIsNotPartOfTheContract() {
        XCTAssertEqual(failure(#"{"error":"טקסט שונה","monthlyLimit":100,"usedTokens":101,"remainingTokens":0}"#), .monthlyAllowance)
        XCTAssertEqual(failure(#"{"error":"Monthly chat token limit exceeded"}"#), .rateLimited)
    }
    func testMalformedOrInconsistentAllowancesRemainErrors() {
        for body in [
            #"{"monthlyLimit":100,"usedTokens":99,"remainingTokens":0}"#,
            #"{"monthlyLimit":100,"usedTokens":101,"remainingTokens":1}"#,
            #"{"monthlyLimit":-1,"usedTokens":101,"remainingTokens":0}"#,
            #"{"monthlyLimit":"100","usedTokens":101,"remainingTokens":0}"#,
            #"{"monthlyLimit":true,"usedTokens":101,"remainingTokens":0}"#,
            #"{"monthlyLimit":100,"remainingTokens":0}"#,
            #"{"monthlyLimit":100,"usedTokens":101.5,"remainingTokens":0}"#,
            #"{"monthlyLimit":100,"usedTokens":9007199254740992,"remainingTokens":0}"#
        ] { XCTAssertEqual(failure(body), .rateLimited) }
    }
    func testAuthenticationFailureKeepsLoginRecovery() {
        XCTAssertEqual(failure(#"{"monthlyLimit":100,"usedTokens":101,"remainingTokens":0}"#, status: 401), .expiredLogin)
    }
}
