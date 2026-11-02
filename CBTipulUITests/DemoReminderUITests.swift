import XCTest

final class DemoReminderUITests: XCTestCase {
    func testBannerAndRealThreeMinuteReminder() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["demo.banner"].firstMatch.waitForExistence(timeout: 25))
        let start = Date()
        let reminder = app.alerts["אתם במצב הדגמה"]
        XCTAssertTrue(reminder.waitForExistence(timeout: 190))
        XCTAssertGreaterThan(Date().timeIntervalSince(start), 150, "Reminder must not be immediate")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Demo banner and real three-minute reminder"
        shot.lifetime = .keepAlways
        add(shot)
        reminder.buttons["המשך התנסות"].tap()
        XCTAssertTrue(reminder.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["demo.banner"].firstMatch.exists)
    }
}
