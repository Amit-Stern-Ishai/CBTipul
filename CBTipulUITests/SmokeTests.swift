import XCTest

/// Offline smoke: auth paints, then `-UITesting` enters demo shell.
final class SmokeTests: XCTestCase {

    @MainActor
    func testPatientWorkspacePreservesUnfinishedNotes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["patients.root"].waitForExistence(timeout: 20))

        // Demo starts with an empty clinic; create a local patient for this run.
        let name = "UX" + UUID().uuidString.prefix(6)
        app.navigationBars.buttons["הוספת מטופל/ת"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        app.textFields.firstMatch.tap()
        app.textFields.firstMatch.typeText(name)
        app.buttons.matching(identifier: "הוספת מטופל/ת").firstMatch.tap()
        let patient = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(patient.waitForExistence(timeout: 5))
        patient.tap()
        XCTAssertTrue(app.buttons["patient.documentSession"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["patient.connection"].exists)
        // A local demo must explain connection without sending a real invitation.
        XCTAssertFalse(app.buttons["patient.shareInvitation"].exists)
        let overview = XCTAttachment(screenshot: app.screenshot())
        overview.name = "Patient workspace"
        overview.lifetime = .keepAlways
        add(overview)

        let notes = app.buttons["patient.notes"]
        for _ in 0..<5 where !notes.isHittable { app.swipeUp() }
        XCTAssertTrue(notes.isHittable)
        notes.tap()
        let field = app.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let original = field.value as? String ?? ""
        field.tap()
        field.typeText(" UX draft")
        app.navigationBars["הערות על המטופל/ת"].buttons["חזרה"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
        app.alerts.buttons["המשך עריכה"].tap()
        XCTAssertTrue((field.value as? String ?? "").contains("UX draft"))
        app.navigationBars["הערות על המטופל/ת"].buttons["חזרה"].tap()
        app.alerts.buttons["מחיקת השינויים"].tap()
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        notes.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, original)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchAuthThenDemoShell() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()

        let authEmail = app.descendants(matching: .any)["auth.email"]
        XCTAssertTrue(
            authEmail.waitForExistence(timeout: 10),
            "Auth screen should appear before UITesting bypass"
        )

        let patientsRoot = app.descendants(matching: .any)["patients.root"]
        XCTAssertTrue(
            patientsRoot.waitForExistence(timeout: 12),
            "Patient list should appear after UITesting demo bypass"
        )

        let therapistRoot = app.descendants(matching: .any)["therapist.root"]
        XCTAssertTrue(
            therapistRoot.waitForExistence(timeout: 4),
            "Therapist tab shell should wrap the patient list"
        )
        XCTAssertTrue(
            app.tabBars.firstMatch.exists,
            "Therapist tab bar should be visible in demo shell"
        )

        let demoBanner = app.descendants(matching: .any)["demo.banner"]
        XCTAssertTrue(
            demoBanner.waitForExistence(timeout: 8),
            "Demo banner should be visible in demo mode"
        )
    }
}
