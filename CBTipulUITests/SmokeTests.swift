import XCTest

/// Offline smoke: auth paints, then `-UITesting` enters demo shell.
final class SmokeTests: XCTestCase {

    @MainActor
    func testPatientStatusCanBeChangedFromHeader() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["patients.root"].waitForExistence(timeout: 20))
        let name = "Status" + UUID().uuidString.prefix(6)
        app.navigationBars.buttons["הוספת מטופל/ת"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        app.textFields.firstMatch.tap()
        app.textFields.firstMatch.typeText(name)
        app.buttons["שמירת מטופל/ת"].tap()
        let search = app.searchFields["חיפוש מטופלים"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name + "\n")
        let patient = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(patient.waitForExistence(timeout: 5))
        patient.tap()
        let status = app.buttons["סטטוס"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.tap()
        let inactive = app.buttons["לא פעיל/ה"]
        XCTAssertTrue(inactive.waitForExistence(timeout: 5))
        inactive.tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@ AND enabled == true", "לא פעיל/ה"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed)
        status.tap()
        let active = app.buttons["פעיל/ה"]
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        active.tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@ AND enabled == true", "פעיל/ה"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
    }

    @MainActor
    func testTherapistAIPatientSelectionAndBack() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["patients.root"].waitForExistence(timeout: 20))
        let name = "AI" + UUID().uuidString.prefix(6)
        app.navigationBars.buttons["הוספת מטופל/ת"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        app.textFields.firstMatch.tap()
        app.textFields.firstMatch.typeText(name)
        app.buttons.matching(identifier: "שמירת מטופל/ת").firstMatch.tap()
        let aiTab = app.tabBars.buttons["AI"]
        XCTAssertTrue(aiTab.waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.buttons.count, 5)
        aiTab.tap()
        XCTAssertTrue(app.navigationBars["שיחת AI"].waitForExistence(timeout: 5))
        let search = app.searchFields["חיפוש מטופלים"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name + "\n")
        let patient = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(patient.waitForExistence(timeout: 5))
        patient.tap()
        XCTAssertTrue(app.navigationBars["שיחת AI על " + name].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["שיחת AI"].waitForExistence(timeout: 5))
    }

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
        app.buttons.matching(identifier: "שמירת מטופל/ת").firstMatch.tap()
        // Filter the bundled samples before locating the newly added row.
        let search = app.searchFields["חיפוש מטופלים"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name + "\n")
        let patient = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(patient.waitForExistence(timeout: 5))
        reveal(patient, in: app)
        patient.tap()
        XCTAssertTrue(app.buttons["עריכת פרטים"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["patient.documentSession"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["patient.connection"].exists)
        // A local demo must explain connection without sending a real invitation.
        XCTAssertFalse(app.buttons["patient.shareInvitation"].exists)
        let overview = XCTAttachment(screenshot: app.screenshot())
        overview.name = "Patient workspace"
        overview.lifetime = .keepAlways
        add(overview)

        // Connection guidance stays behind one compact invitation action.
        XCTAssertFalse(app.buttons["patient.sending"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["patient.sendingUnavailable"].exists)
        let connectionInfo = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "הזמנה לאפליקציה")).firstMatch
        reveal(connectionInfo, in: app)
        XCTAssertTrue(connectionInfo.exists)
        let explanation = app.staticTexts["שליחת קישור הזמנה אישי מאפשרת למטופל/ת לקבל ממך הודעות ושאלונים ולמלא יומנים שהפעלת."]
        XCTAssertFalse(explanation.exists)
        let compactConnection = XCTAttachment(screenshot: app.screenshot())
        compactConnection.name = "Compact invitation action"
        compactConnection.lifetime = .keepAlways
        add(compactConnection)
        connectionInfo.tap()
        XCTAssertTrue(explanation.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["patient.shareInvitation"].exists, "Demo must not create real invitations")
        app.buttons["patient.connectionInfo.done"].tap()
        XCTAssertTrue(explanation.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["patient.sendMessage"].exists)
        XCTAssertFalse(app.buttons["patient.sendQuestionnaire"].exists)

        let diaries = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "יומנים")).firstMatch
        reveal(diaries, in: app)
        XCTAssertTrue(diaries.isHittable)
        diaries.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "יומן 1")).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "יומן 2")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "יומן 3")).firstMatch.exists)
        let diaryChoices = XCTAttachment(screenshot: app.screenshot())
        diaryChoices.name = "Expanded diaries"
        diaryChoices.lifetime = .keepAlways
        add(diaryChoices)
        diaries.tap()

        let questionnaireHistory = app.buttons["patient.questionnaireHistory"]
        reveal(questionnaireHistory, in: app)
        questionnaireHistory.tap()
        XCTAssertTrue(app.buttons["מילוי שאלון כאן"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls.firstMatch.exists)
        app.navigationBars.buttons.firstMatch.tap()

        let graphs = app.buttons["patient.questionnaireGraphs"]
        reveal(graphs, in: app)
        graphs.tap()
        XCTAssertTrue(app.staticTexts["עדיין אין נתונים לגרפים"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["מילוי שאלון כאן"].exists)
        XCTAssertFalse(app.segmentedControls.firstMatch.exists)
        app.navigationBars.buttons.firstMatch.tap()

        let messages = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "הודעות")).firstMatch
        reveal(messages, in: app)
        XCTAssertTrue(messages.isHittable)
        messages.tap()
        XCTAssertTrue(app.descendants(matching: .any)["messages.history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[name].exists)
        XCTAssertTrue(app.staticTexts["עדיין לא נשלחו הודעות"].exists)
        XCTAssertTrue(app.staticTexts["במצב הדגמה לא נשלחות הודעות למטופלים."].exists)
        XCTAssertFalse(app.buttons["messages.compose"].exists)
        let history = XCTAttachment(screenshot: app.screenshot())
        history.name = "Messages history in demo"
        history.lifetime = .keepAlways
        add(history)
        app.navigationBars["הודעות שנשלחו"].buttons.firstMatch.tap()

        let notes = app.buttons["patient.notes"]
        reveal(notes, in: app)
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

    @MainActor
    func testGlobalSessionChoosesPatientInForm() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["patients.root"].waitForExistence(timeout: 20))

        let name = "000Session" + UUID().uuidString.prefix(6)
        app.navigationBars.buttons["הוספת מטופל/ת"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        app.textFields.firstMatch.tap()
        app.textFields.firstMatch.typeText(name)
        app.buttons.matching(identifier: "שמירת מטופל/ת").firstMatch.tap()
        XCTAssertTrue(app.searchFields["חיפוש מטופלים"].waitForExistence(timeout: 5))
        app.tabBars.buttons["פגישות"].tap()
        app.navigationBars.buttons["פגישה חדשה"].tap()

        let save = app.buttons["session.save"]
        let picker = app.buttons["session.patient"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.exists)
        XCTAssertFalse(save.isEnabled, "A session must have an explicitly selected patient")
        let date = app.datePickers["session.date"]
        let type = app.buttons["session.type"]
        XCTAssertTrue(date.exists)
        XCTAssertTrue(type.exists)
        XCTAssertLessThan(date.frame.midY, type.frame.midY)
        XCTAssertLessThan(type.frame.midY, app.textViews.firstMatch.frame.minY)
        picker.tap()
        let choice = app.buttons[name]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        XCTAssertTrue(save.isEnabled)
        let selected = XCTAttachment(screenshot: app.screenshot())
        selected.name = "New session with patient dropdown"
        selected.lifetime = .keepAlways
        add(selected)
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))

        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText(name + "\n")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[name].exists)
        XCTAssertFalse(picker.exists, "Saved sessions keep their original patient")
    }

    @MainActor
    func testSessionEditorSaveAndDiscard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["patients.root"].waitForExistence(timeout: 20))

        let name = "SessionUX" + UUID().uuidString.prefix(6)
        app.navigationBars.buttons["הוספת מטופל/ת"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        app.textFields.firstMatch.tap()
        app.textFields.firstMatch.typeText(name)
        app.buttons.matching(identifier: "שמירת מטופל/ת").firstMatch.tap()
        // Filter the bundled samples before locating the newly added row.
        let search = app.searchFields["חיפוש מטופלים"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name + "\n")
        let patient = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(patient.waitForExistence(timeout: 5))
        reveal(patient, in: app)
        patient.tap()
        let sessions = app.buttons["patient.sessions"]
        XCTAssertTrue(sessions.waitForExistence(timeout: 5))
        reveal(sessions, in: app)
        sessions.tap()
        let addSession = app.navigationBars.buttons["הוספת פגישה"]
        XCTAssertTrue(addSession.waitForExistence(timeout: 5))
        addSession.tap()

        let save = app.buttons["session.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["session.patient"].exists, "Patient detail already supplies the patient")
        XCTAssertTrue(app.buttons["הקלטת סיכום הפגישה"].exists)
        XCTAssertTrue(save.isEnabled, "A date-only session should not require optional details or AI")
        let initial = XCTAttachment(screenshot: app.screenshot())
        initial.name = "Clear session editor"
        initial.lifetime = .keepAlways
        add(initial)
        // Start with an empty local session to avoid the live anonymization service.
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))
        let row = app.cells.containing(.staticText, identifier: "1").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        XCTAssertFalse(app.staticTexts["כל השינויים נשמרו"].exists)

        let notes = app.textViews.firstMatch
        notes.tap()
        notes.typeText("Session notes for UX verification")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed)
        XCTAssertFalse(app.staticTexts["כל השינויים נשמרו"].exists)
        XCTAssertFalse(save.isEnabled)
        app.navigationBars.buttons["חזרה"].firstMatch.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        XCTAssertEqual(notes.value as? String, "Session notes for UX verification")
        notes.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        notes.typeText(" discarded edit")
        app.navigationBars.buttons["חזרה"].firstMatch.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
        app.alerts.buttons["מחיקת השינויים"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        XCTAssertEqual(notes.value as? String, "Session notes for UX verification")
        XCTAssertFalse(save.isEnabled)
    }

    /// Fixed tutorial docks can overlap cells that XCTest still calls hittable.
    /// Scroll in small steps to keep each target between the header and dock.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let height = app.frame.height
        for _ in 0..<15 {
            let y = element.exists ? element.frame.midY : height
            if element.exists && element.isHittable && y > height * 0.25 && y < height * 0.55 { return }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y < height * 0.25 && element.exists ? 0.68 : 0.32))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
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
        XCTAssertFalse(app.buttons["welcome.continueDemo"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "שלב ")).firstMatch.exists)
        let search = app.searchFields["חיפוש מטופלים"]
        search.tap()
        search.typeText("ישראלה\n")
        let sample = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ישראלה ישראלית")).firstMatch
        XCTAssertTrue(sample.waitForExistence(timeout: 5), "Sample patients should be available immediately")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Sample data without onboarding"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["חזרה למטופלים שלי"].firstMatch.tap()
        XCTAssertTrue(demoBanner.waitForNonExistence(timeout: 10))
        XCTAssertFalse(sample.exists, "Sample patients must not remain in the real clinic")
        app.tabBars.buttons["הגדרות"].tap()
        let sampleEntry = app.buttons["settings.sampleData"]
        XCTAssertTrue(sampleEntry.waitForExistence(timeout: 5))
        sampleEntry.tap()
        let startSample = app.buttons["sampleData.start"]
        XCTAssertTrue(startSample.waitForExistence(timeout: 5))
        XCTAssertFalse(demoBanner.exists, "Opening the explanation must not start sample mode")
        let gate = XCTAttachment(screenshot: app.screenshot())
        gate.name = "Sample mode introduction"
        gate.lifetime = .keepAlways
        add(gate)
        app.buttons["sampleData.cancel"].tap()
        XCTAssertTrue(startSample.waitForNonExistence(timeout: 5))
        XCTAssertFalse(demoBanner.exists)
        sampleEntry.tap()
        XCTAssertTrue(startSample.waitForExistence(timeout: 5))
        startSample.tap()
        XCTAssertTrue(demoBanner.waitForExistence(timeout: 10))
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["welcome.continueDemo"].exists)
    }
}
