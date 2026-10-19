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
        let goal = app.descendants(matching: .any)["patient.treatmentGoal"].firstMatch
        XCTAssertTrue(goal.exists)
        XCTAssertLessThan(goal.frame.minY, shortcut.frame.minY)
        let patientShot = XCTAttachment(screenshot: app.screenshot())
        patientShot.name = "patient-screen-treatment-goal-and-actions"
        patientShot.lifetime = .keepAlways
        add(patientShot)
        for _ in 0..<3 { if shortcut.isHittable { break }; app.swipeUp() }
        shortcut.tap()
        XCTAssertTrue(app.buttons["session.save"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["session.patient"].exists)
        XCTAssertTrue(app.datePickers["session.date"].exists)
        XCTAssertTrue(app.buttons["session.save"].isEnabled)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "patient-shortcut-session"; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testPopulatedPatientDigestDark() throws { try reviewPatient(appearance: "dark") }
    @MainActor func testPopulatedPatientDigestLight() throws { try reviewPatient(appearance: "light") }
    @MainActor func testPopulatedPatientDigestLargeText() throws { try reviewPatient(appearance: "dark", largeText: true) }

    @MainActor private func reviewPatient(appearance: String, largeText: Bool = false) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-appAppearance", appearance]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["patients.root"].waitForExistence(timeout: 20))
        let search = app.searchFields["חיפוש מטופלים"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("ישראלית\n")
        let patient = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ישראלה ישראלית")).firstMatch
        XCTAssertTrue(patient.waitForExistence(timeout: 5)); patient.tap()
        XCTAssertTrue(app.descendants(matching: .any)["patient.treatmentGoal"].firstMatch.waitForExistence(timeout: 5))
        if !largeText {
            let expand = app.buttons["patient.goal.expand"]
            XCTAssertTrue(expand.waitForExistence(timeout: 5))
            expand.tap(); XCTAssertEqual(expand.label, "צמצום")
            expand.tap(); XCTAssertEqual(expand.label, "הרחבה")
            let stages = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "patient.journey.stage."))
            XCTAssertEqual(stages.count, 4)
            XCTAssertGreaterThan(stages.element(boundBy: 0).frame.minX, stages.element(boundBy: 3).frame.minX)
            XCTAssertTrue(stages.element(boundBy: 0).label.contains("אינטייק"))
            XCTAssertTrue(stages.element(boundBy: 3).label.contains("יומן מחשבות 2"))
        }
        if !largeText {
            XCTAssertTrue(app.buttons["patient.aiChat"].isHittable)
            XCTAssertTrue(app.buttons["patient.notes"].isHittable)
            XCTAssertTrue(app.buttons["patient.messages"].isHittable)
            XCTAssertLessThan(app.buttons["patient.notes"].frame.maxY, app.tabBars.firstMatch.frame.minY)
        }
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "patient-digest-\(appearance)-\(largeText ? "large" : "normal")-top"
        top.lifetime = .keepAlways; add(top)
        let full = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "patient.journey.stage.")).firstMatch
        for _ in 0..<6 { if full.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(full.exists)
        if !largeText {
            full.tap()
            XCTAssertTrue(app.navigationBars["רצף הטיפול"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.scrollViews["patient.journey.timeline"].exists)
            XCTAssertFalse(app.buttons["session.save"].exists)
            let history = XCTAttachment(screenshot: app.screenshot()); history.name = "patient-journey-\(appearance)"; history.lifetime = .keepAlways; add(history)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        let ai = app.descendants(matching: .any)["patient.aiChat"].firstMatch
        for step in 0..<10 {
            if ai.isHittable { break }
            app.swipeUp()
            if largeText {
                let scrolling = XCTAttachment(screenshot: app.screenshot())
                scrolling.name = "patient-large-scroll-\(step)"
                scrolling.lifetime = .keepAlways; add(scrolling)
            }
        }
        XCTAssertTrue(ai.isHittable)
        let records = XCTAttachment(screenshot: app.screenshot())
        records.name = "patient-records-\(appearance)-\(largeText ? "large" : "normal")"
        records.lifetime = .keepAlways; add(records)
        if appearance == "dark" && !largeText {
            ai.tap()
            XCTAssertTrue(app.buttons["patient.ai.send"].waitForExistence(timeout: 5))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            let diaries = app.buttons["patient.diaries"]
            XCTAssertTrue(diaries.waitForExistence(timeout: 5)); diaries.tap()
            XCTAssertTrue(app.descendants(matching: .any)["patient.diaryOne"].firstMatch.waitForExistence(timeout: 5))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["patient.diaries"].waitForExistence(timeout: 5))
        }
    }

}
