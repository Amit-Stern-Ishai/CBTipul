import XCTest

final class WebWorkspaceShortcutUITests: XCTestCase {
    @MainActor func testPatientShortcutOpensNormalPatientBoundSessionEditor() throws {
        let app = XCUIApplication(); app.launchArguments = ["-UITesting"]; app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["patients.root"].waitForExistence(timeout: 20))
        let name = "Workspace" + UUID().uuidString.prefix(5)
        app.navigationBars.buttons["הוספת מטופל/ת"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        app.textFields.firstMatch.tap(); app.textFields.firstMatch.typeText(name)
        app.buttons.matching(identifier: "שמירת מטופל/ת").firstMatch.tap()
        let search = app.searchFields["חיפוש מטופלים"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText(name + "\n")
        let patient = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(patient.waitForExistence(timeout: 5)); patient.tap()
        let shortcut = app.buttons["patient.newSession"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
        for _ in 0..<3 { if shortcut.isHittable { break }; app.swipeUp() }
        shortcut.tap()
        XCTAssertTrue(app.buttons["session.save"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["session.patient"].exists)
        XCTAssertTrue(app.datePickers["session.date"].exists)
        XCTAssertTrue(app.buttons["session.save"].isEnabled)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "patient-shortcut-session"; shot.lifetime = .keepAlways; add(shot)
    }
}
