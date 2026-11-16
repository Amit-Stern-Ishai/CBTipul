import XCTest
@testable import CBTipul
final class DeletionPhraseTests: XCTestCase {
    func testExactPhrasesAndWhitespace() {
        XCTAssertEqual(DeletionPhrase.patient.rawValue, "מחיקת מטופל")
        XCTAssertEqual(DeletionPhrase.account.rawValue, "מחיקת חשבון")
        for phrase in DeletionPhrase.allCases {
            XCTAssertTrue(phrase.matches(phrase.rawValue))
            XCTAssertTrue(phrase.matches(" \n" + phrase.rawValue + "\t "))
            XCTAssertFalse(phrase.matches(""))
            XCTAssertFalse(phrase.matches("מחיקת"))
            XCTAssertFalse(phrase.matches(phrase.rawValue + "x"))
            XCTAssertFalse(phrase.matches("ABCDEFGH"))
        }
    }
}
