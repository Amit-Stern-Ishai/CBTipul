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

extension WebWorkspaceShortcutUITests {
    @MainActor func testSessionDesignDark() throws { try reviewSessionDesign("dark") }
    @MainActor func testSessionDesignLight() throws { try reviewSessionDesign("light") }
    @MainActor private func reviewSessionDesign(_ appearance: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-appAppearance", appearance, "-SessionDesignFixture"]
        app.launch()
        let search = app.searchFields["חיפוש מטופלים"]
        XCTAssertTrue(search.waitForExistence(timeout: 20))
        search.tap(); search.typeText("ישראלית\n")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ישראלה ישראלית")).firstMatch.tap()
        let sessions = app.buttons["patient.sessions"]
        XCTAssertTrue(sessions.waitForExistence(timeout: 5))
        for _ in 0..<4 { if sessions.isHittable { break }; app.swipeUp() }
        sessions.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "7,")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let edit = app.buttons["session.notes"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["סיכום הפגישה"].exists)
        XCTAssertFalse(app.staticTexts["הסיכום שלכם"].exists)
        XCTAssertTrue(app.buttons["הקלטת סיכום הפגישה"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "session-design-\(appearance)"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["session.readSummary"].tap()
        XCTAssertTrue(app.scrollViews["session.summaryReader"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let reader = XCTAttachment(screenshot: app.screenshot()); reader.name = "session-reader-\(appearance)"; reader.lifetime = .keepAlways; add(reader)
        app.buttons["session.editSummaryText"].tap()
        XCTAssertTrue(app.textFields["session.summaryText"].waitForExistence(timeout: 5))
        let writer = XCTAttachment(screenshot: app.screenshot()); writer.name = "session-writer-\(appearance)"; writer.lifetime = .keepAlways; add(writer)
        let notes = app.textFields["session.summaryText"]
        let original = notes.value as? String
        notes.tap(); notes.typeText(" UI test")
        let typing = XCTAttachment(screenshot: app.screenshot()); typing.name = "session-typing-\(appearance)"; typing.lifetime = .keepAlways; add(typing)
        XCTAssertFalse(app.buttons["session.toggleWriting"].exists)
        XCTAssertTrue(app.navigationBars.buttons["שמירת הסיכום"].exists)
        notes.typeText(String(repeating: "\nשורה נוספת לבדיקת סיכום ארוך", count: 18))
        XCTAssertTrue(app.buttons["session.summaryRecording"].isHittable)
        XCTAssertTrue(app.navigationBars.buttons["שמירת הסיכום"].isHittable)
        let longSummary = XCTAttachment(screenshot: app.screenshot()); longSummary.name = "session-long-\(appearance)"; longSummary.lifetime = .keepAlways; add(longSummary)
        app.navigationBars.buttons["חזרה"].firstMatch.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
        app.alerts.buttons["מחיקת השינויים"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertEqual(app.textFields["session.summaryText"].value as? String, original)
        app.navigationBars.buttons["סגירה"].firstMatch.tap()
    }
}

extension WebWorkspaceShortcutUITests {
    @MainActor func testSessionQuestionnaireCompletedDark() throws { try reviewSessionQuestionnaire("dark", number: "7") }
    @MainActor func testSessionQuestionnaireCompletedLight() throws { try reviewSessionQuestionnaire("light", number: "7") }
    @MainActor func testSessionQuestionnaireEmpty() throws { try reviewSessionQuestionnaire("dark", number: "1") }
    @MainActor private func reviewSessionQuestionnaire(_ appearance: String, number: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-appAppearance", appearance, "-SessionDesignFixture", "-SessionQuestionnaireFixture"]
        app.launch()
        let search = app.searchFields["חיפוש מטופלים"]
        XCTAssertTrue(search.waitForExistence(timeout: 20))
        search.tap(); search.typeText("ישראלית\n")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ישראלה ישראלית")).firstMatch.tap()
        let sessions = app.buttons["patient.sessions"]
        XCTAssertTrue(sessions.waitForExistence(timeout: 5))
        for _ in 0..<4 { if sessions.isHittable { break }; app.swipeUp() }
        sessions.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", number + ",")).firstMatch
        for _ in 0..<5 { if row.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let entry = app.buttons["session.questionnaireEntry"]
        for _ in 0..<6 { if entry.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertTrue(entry.isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "questionnaire-\(number)-\(appearance)"; shot.lifetime = .keepAlways; add(shot)
        entry.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "GAD-7")).firstMatch.waitForExistence(timeout: 5))
    }
}

extension WebWorkspaceShortcutUITests {
    @MainActor func testLatestSessionShortcutDark() throws { try checkLatestSessionShortcut("dark") }
    @MainActor func testLatestSessionShortcutLight() throws { try checkLatestSessionShortcut("light") }
    @MainActor private func checkLatestSessionShortcut(_ appearance: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-appAppearance", appearance]
        app.launch()
        let search = app.searchFields["חיפוש מטופלים"]
        XCTAssertTrue(search.waitForExistence(timeout: 20))
        search.tap(); search.typeText("ישראלית\n")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ישראלה ישראלית")).firstMatch.tap()
        let latest = app.buttons["patient.latestSession"]
        XCTAssertTrue(latest.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "patient-compact-\(appearance)"; screenshot.lifetime = .keepAlways; add(screenshot)
        for _ in 0..<5 { if latest.isHittable { break }; app.swipeUp() }
        latest.tap()
        XCTAssertTrue(app.navigationBars["פגישה 7"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["session.notes"].exists)
        app.navigationBars.buttons["חזרה"].firstMatch.tap()
        XCTAssertTrue(latest.waitForExistence(timeout: 5))
    }
}

extension WebWorkspaceShortcutUITests {
    @MainActor func testPatientDirectoryDark() throws { try reviewPatientDirectory("dark") }
    @MainActor func testPatientDirectoryLight() throws { try reviewPatientDirectory("light") }
    @MainActor func testPatientDirectoryAccessibleSearch() throws { try reviewPatientDirectory("dark", large: true) }
    @MainActor private func reviewPatientDirectory(_ appearance: String, large: Bool = false) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-appAppearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let search = app.searchFields["חיפוש מטופלים"]
        XCTAssertTrue(search.waitForExistence(timeout: 20))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "patient-list-\(appearance)-\(large ? "large" : "normal")"; shot.lifetime = .keepAlways; add(shot)
        search.tap(); search.typeText("zzzz")
        XCTAssertTrue(app.staticTexts["לא נמצאו מטופלים"].waitForExistence(timeout: 5))
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
        search.typeText("ישראלית\n")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ישראלה ישראלית")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["patient.treatmentGoal"].firstMatch.waitForExistence(timeout: 5))
    }
}

extension WebWorkspaceShortcutUITests {
    @MainActor func testSessionDirectoryDark() throws { try reviewSessionDirectory("dark") }
    @MainActor func testSessionDirectoryLight() throws { try reviewSessionDirectory("light") }
    @MainActor private func reviewSessionDirectory(_ appearance: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-appAppearance", appearance]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["פגישות"].waitForExistence(timeout: 20))
        app.tabBars.buttons["פגישות"].tap()
        let row = app.buttons["sessions.entry"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "session-list-\(appearance)"; shot.lifetime = .keepAlways; add(shot)
        row.tap()
        XCTAssertTrue(app.buttons["session.save"].waitForExistence(timeout: 5))
    }
}


extension WebWorkspaceShortcutUITests {
    @MainActor func testPatientSessionHistoryDesign() throws {
        let app = XCUIApplication(); app.launchArguments = ["-UITesting", "-appAppearance", "dark"]; app.launch()
        let search = app.searchFields["חיפוש מטופלים"]
        XCTAssertTrue(search.waitForExistence(timeout: 20)); search.tap(); search.typeText("ישראלית\n")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ישראלה ישראלית")).firstMatch.tap()
        let sessions = app.buttons["patient.sessions"]
        XCTAssertTrue(sessions.waitForExistence(timeout: 5))
        for _ in 0..<4 { if sessions.isHittable { break }; app.swipeUp() }
        sessions.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "פגישה 7")).firstMatch.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "session-list-patient"; shot.lifetime = .keepAlways; add(shot)
    }
}

extension WebWorkspaceShortcutUITests {
    @MainActor func testNotificationDesignDark() throws { try reviewNotificationDesign("dark") }
    @MainActor func testNotificationDesignLight() throws { try reviewNotificationDesign("light") }
    @MainActor func testNotificationDesignLarge() throws { try reviewNotificationDesign("dark", large: true) }
    @MainActor private func reviewNotificationDesign(_ appearance: String, large: Bool = false) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-UITestingNotifications", "-appAppearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let tab = app.tabBars.buttons["התראות"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20)); tab.tap()
        let row = app.buttons["notifications.entry.patient_connected"]
        XCTAssertTrue(app.buttons["notifications.entry.questionnaire_completed"].waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "notifications-\(appearance)-\(large ? "large" : "normal")"; shot.lifetime = .keepAlways; add(shot)
        for _ in 0..<6 { if row.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(row.isHittable); row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["patient.treatmentGoal"].firstMatch.waitForExistence(timeout: 5))
    }
}

extension WebWorkspaceShortcutUITests {
    @MainActor func testAIChatDesignDark() throws { try reviewAIChat("dark") }
    @MainActor func testAIChatDesignLight() throws { try reviewAIChat("light") }
    @MainActor private func reviewAIChat(_ appearance: String, transcript: Bool = false) throws {
        let app = XCUIApplication(); app.launchArguments = ["-UITesting", "-appAppearance", appearance]
        if transcript { app.launchArguments += ["-AIChatDesignFixture"] }
        app.launch()
        let tab = app.tabBars.buttons["AI"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20)); tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ישראלה ישראלית")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        let send = app.buttons["patient.ai.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5)); XCTAssertFalse(send.isEnabled)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "ai-chat-\(transcript ? "transcript" : appearance)"; shot.lifetime = .keepAlways; add(shot)
        if !transcript {
            app.buttons["patient.ai.suggestion.0"].tap()
            XCTAssertTrue(send.isEnabled)
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            let input = XCTAttachment(screenshot: app.screenshot()); input.name = "ai-chat-composer-\(appearance)"; input.lifetime = .keepAlways; add(input)
        }
    }
}

extension WebWorkspaceShortcutUITests {
    @MainActor func testAIPickerDark() throws { try reviewAIPicker("dark") }
    @MainActor func testAIPickerLight() throws { try reviewAIPicker("light") }
    @MainActor func testAIPickerLarge() throws { try reviewAIPicker("dark", large: true) }
    @MainActor private func reviewAIPicker(_ appearance: String, large: Bool = false) throws {
        let app = XCUIApplication(); app.launchArguments = ["-UITesting", "-appAppearance", appearance]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let tab = app.tabBars.buttons["AI"]; XCTAssertTrue(tab.waitForExistence(timeout: 20)); tab.tap()
        let search = app.searchFields["חיפוש מטופלים"]; XCTAssertTrue(search.waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "ai-picker-\(appearance)-\(large ? "large" : "normal")"; shot.lifetime = .keepAlways; add(shot)
        search.tap(); search.typeText("zzzz")
        XCTAssertTrue(app.staticTexts["לא נמצאו מטופלים"].waitForExistence(timeout: 5))
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4)); search.typeText("ישראלית\n")
        let row = app.buttons["ai.picker.patient"].firstMatch
        for _ in 0..<5 { if row.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(row.isHittable); row.tap()
        XCTAssertTrue(app.buttons["patient.ai.send"].waitForExistence(timeout: 5))
    }
}
