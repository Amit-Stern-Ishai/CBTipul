import XCTest
final class FeatureDiscoveryUITests: XCTestCase {
    @MainActor func testDiscoveryCardsAndCopyKeepsExplanationOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-FeatureDiscoveryReview", "-appAppearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["הזמנת המטופל/ת"].waitForExistence(timeout: 15))
        capture(app, "invite-light")
        app.buttons["הבנתי"].tap()
        XCTAssertTrue(app.staticTexts["ההסבר נסגר"].waitForExistence(timeout: 3))
        app.buttons["הקלטה"].tap()
        let editor = app.descendants(matching: .any)["discovery.review.notes"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts[DiscoveryTestCopy.voice].exists)
        editor.tap(); editor.typeText("Synthetic notes")
        XCTAssertTrue(app.staticTexts[DiscoveryTestCopy.voice].waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        editor.typeText(" continue")
        XCTAssertEqual(editor.value as? String, "Synthetic notes continue")
        capture(app, "voice-inline-keyboard")
        app.buttons["הבנתי"].tap()
        XCTAssertEqual(editor.value as? String, "Synthetic notes continue")
        app.buttons["מחשב"].tap()
        XCTAssertTrue(app.staticTexts["cbtipul.com/app"].waitForExistence(timeout: 3))
        app.buttons["העתקת כתובת"].tap()
        XCTAssertTrue(app.staticTexts["הכתובת הועתקה"].exists)
        XCTAssertTrue(app.buttons["הבנתי"].exists)
        XCTAssertTrue(app.staticTexts["cbtipul.com/app"].exists)
        capture(app, "web-copy-light")
        XCTAssertTrue(app.buttons["הבנתי, אל תציגו שוב"].exists)
        app.buttons["הבנתי, אל תציגו שוב"].tap()
        XCTAssertTrue(app.staticTexts["ההסבר נסגר"].waitForExistence(timeout: 3))
    }
    @MainActor func testLargeTextDarkCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-FeatureDiscoveryReview", "-appAppearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["מחשב"].waitForExistence(timeout: 15)); app.buttons["הבנתי"].tap()
        XCTAssertTrue(app.staticTexts["ההסבר נסגר"].waitForExistence(timeout: 3))
        app.buttons["מחשב"].tap()
        for _ in 0..<5 { if app.buttons["הבנתי"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.buttons["הבנתי"].isHittable)
        capture(app, "web-large-dark")
        app.buttons["הבנתי"].tap()
        XCTAssertTrue(app.staticTexts["ההסבר נסגר"].waitForExistence(timeout: 3))
    }
    @MainActor func testMilestoneActionAndDismissInLightAndLargeDark() {
        for dark in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["-UITesting", "-FeatureDiscoveryReview", "-MilestoneDiscoveryReview", "-appAppearance", dark ? "dark" : "light"]
            if dark { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
            app.launch()
            let action = app.buttons["פתיחת הגדרות הפעילות"]
            XCTAssertTrue(action.waitForExistence(timeout: 15))
            for _ in 0..<6 { if action.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(action.isHittable)
            capture(app, dark ? "milestone-large-dark" : "milestone-light")
            if dark { action.tap() } else { app.buttons["הבנתי"].tap() }
            XCTAssertTrue(app.staticTexts["ההסבר נסגר"].waitForExistence(timeout: 3))
            app.terminate()
        }
    }
    @MainActor func testActivityActionsLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-ActivityActionsReview", "-appAppearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["activity.stop.questionnaire"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["שליחת הודעה"].exists)
        XCTAssertTrue(app.staticTexts["שאלונים"].exists)
        capture(app, "activities-top")
        let enable = app.buttons["activity.enable.diary_one"]
        for _ in 0..<6 { if enable.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(enable.isHittable)
        capture(app, "activities-disabled")
        if !ProcessInfo.processInfo.environment.keys.contains("ACTIVITIES_CAPTURE_ONLY") {
            enable.tap()
            let stop = app.buttons["activity.stop.diary_one"]
            XCTAssertTrue(stop.waitForExistence(timeout: 3))
            stop.tap()
            // Native confirmation can be an action sheet or an anchored popover.
            // Popovers cancel by tapping outside and do not render a Cancel row.
            if app.buttons["ביטול"].exists { app.buttons["ביטול"].tap() }
            else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.85)).tap() }
            XCTAssertTrue(app.sheets.firstMatch.waitForNonExistence(timeout: 3))
            XCTAssertTrue(stop.exists)
        }
    }
    @MainActor func testActivityActionsLargeDarkLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-ActivityActionsReview", "-appAppearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let enable = app.buttons["activity.enable.diary_one"]
        XCTAssertTrue(enable.waitForExistence(timeout: 15))
        for _ in 0..<6 { if enable.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(enable.isHittable)
        capture(app, "activities-large-dark")
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}

private enum DiscoveryTestCopy {
    static let voice = "אפשר גם להקליט את רשימות הפגישה. הדיבור מתומלל אוטומטית לטקסט, ואפשר לערוך אותו לאחר מכן."
}
