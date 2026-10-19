import XCTest
@testable import CBTipul

@MainActor final class PatientJourneyTests: XCTestCase {
    func testGroupsConsecutiveTypesWithoutMergingAcrossOtherTypes() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [SessionType.intake, .intake, .diaryOne, .diaryOne, .intake].enumerated().map {
            Session(date: now.addingTimeInterval(Double($0.offset - 10) * 86400), type: $0.element)
        }
        let result = PatientJourneyGroup.groups(from: sessions.reversed(), now: now)
        XCTAssertEqual(result.map { $0.sessions.count }, [2, 2, 1])
        XCTAssertEqual(result.map(\.type), [.intake, .diaryOne, .intake])
        XCTAssertEqual(result.flatMap(\.sessions).map(\.id), sessions.map(\.id))
    }
    func testMissingTypesRemainVisibleAndFutureSessionsAreExcluded() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let past = Session(date: now.addingTimeInterval(-86400), type: nil)
        let today = Session(date: now, type: .diaryThree)
        let future = Session(date: now.addingTimeInterval(86400 * 2), type: .intake)
        let groups = PatientJourneyGroup.groups(from: [future, today, past], now: now)
        XCTAssertEqual(groups.count, 2)
        XCTAssertNil(groups.first?.type)
        XCTAssertEqual(groups.flatMap(\.sessions).map(\.id), [past.id, today.id])
        XCTAssertTrue(PatientJourneyGroup.groups(from: [], now: now).isEmpty)
    }
}
