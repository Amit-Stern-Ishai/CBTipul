import Testing
@testable import CBTipul

struct TherapistAITabTests {
    @Test func aiIsBetweenSessionsAndNotifications() {
        #expect(TherapistRootTab.allCases == [.patients, .sessions, .ai, .notifications, .settings])
    }
}
