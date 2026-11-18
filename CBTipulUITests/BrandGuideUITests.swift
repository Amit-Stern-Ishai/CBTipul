import XCTest

/// Offline native captures use existing synthetic fixtures only.
final class BrandGuideUITests: XCTestCase {
    @MainActor func testExistingPatientRemainsResponsive() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-appAppearance", "light"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["patients.root"].waitForExistence(timeout: 20))
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "אדם אדמוני")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let sessions = app.buttons["patient.sessions"]
        XCTAssertTrue(sessions.waitForExistence(timeout: 10))
        for _ in 0..<4 { if sessions.isHittable { break }; app.swipeUp() }
        sessions.tap()
        XCTAssertTrue(app.navigationBars.buttons["הוספת פגישה"].waitForExistence(timeout: 5))
    }

    @MainActor func testGuideAcrossNativeScreens() {
        for mode in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-UITesting", "-UITestingAuthRole", "-appAppearance", mode]
            app.launch()
            XCTAssertTrue(app.buttons["auth.chooseEmail"].waitForExistence(timeout: 15))
            capture(app, "auth-" + mode)
            app.buttons["auth.chooseEmail"].tap()
            XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 5))
            capture(app, "email-" + mode)
            app.terminate()

            app.launchArguments = ["-UITesting", "-ActivityActionsReview", "-appAppearance", mode]
            app.launch()
            XCTAssertTrue(app.buttons["activity.stop.questionnaire"].waitForExistence(timeout: 15))
            capture(app, "patient-" + mode)
            app.terminate()

            app.launchArguments = ["-UITesting", "-PatientHomeDesignReview", "-appAppearance", mode]
            app.launch()
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 15))
            capture(app, "patient-mode-" + mode)
            app.terminate()
        }
    }
    @MainActor func testClinicAndClinicalForms() {
        continueAfterFailure = false
        for mode in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-UITesting", "-appAppearance", mode]
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["patients.root"].waitForExistence(timeout: 20))
            XCTAssertTrue(app.navigationBars.staticTexts["מטופלים"].waitForExistence(timeout: 5))
            capture(app, "clinic-" + mode)
            app.navigationBars.buttons["הוספת מטופל/ת"].tap()
            XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
            XCTAssertTrue(app.navigationBars.staticTexts["מטופל/ת חדש/ה"].waitForExistence(timeout: 5))
            capture(app, "create-patient-" + mode)
            let name = "Brand" + UUID().uuidString.prefix(6)
            app.textFields.firstMatch.tap()
            app.textFields.firstMatch.typeText(name)
            app.buttons["שמירת מטופל/ת"].tap()
            let search = app.searchFields["חיפוש מטופלים"]
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap(); search.typeText(name + "\n")
            let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
            let sessions = app.buttons["patient.sessions"]
            XCTAssertTrue(sessions.waitForExistence(timeout: 5))
            capture(app, "profile-" + mode)
            for _ in 0..<4 { if sessions.isHittable { break }; app.swipeUp() }
            sessions.tap()
            let create = app.navigationBars.buttons["הוספת פגישה"]
            XCTAssertTrue(create.waitForExistence(timeout: 5))
            capture(app, "sessions-" + mode)
            create.tap()
            XCTAssertTrue(app.buttons["session.save"].waitForExistence(timeout: 5))
            capture(app, "session-editor-" + mode)
            app.terminate()
        }
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "brand-" + name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
