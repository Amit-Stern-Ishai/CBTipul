import XCTest

final class SummaryRecoveryUITests: XCTestCase {
    private let app = XCUIApplication()
    private func launch(_ options: [String] = []) {
        app.launchArguments = ["-UITesting", "-SummaryRecoveryFixture"] + options
        app.launch()
        XCTAssertTrue(app.staticTexts["fixture.counts"].firstMatch.waitForExistence(timeout: 15))
    }
    private func openEditor() {
        let empty = app.buttons["session.emptySummary"]
        if empty.waitForExistence(timeout: 3) { empty.tap() }
        else { app.buttons["session.readSummary"].tap() }
    }
    private func typeSummary() {
        openEditor()
        let field = app.textFields["session.summaryText"]
        let view = app.textViews["session.summaryText"]
        let editor = field.waitForExistence(timeout: 3) ? field : view
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Synthetic recovery note")
    }
    private func save() { app.buttons["שמירת הסיכום"].tap() }
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testAllowanceDenialAppearsBeforeOpeningSummaryAndBlocksWriting() {
        continueAfterFailure = false
        launch(["-ResetSummaryFixture", "-SummaryAllowanceDenied"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "מכסת ה־AI החודשית נוצלה")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["fixture.counts"].firstMatch.label.contains("transcribe=0"))
        openEditor()
        XCTAssertFalse(app.buttons["session.editSummaryText"].isEnabled)
        XCTAssertFalse(app.textFields["session.summaryText"].exists)
        attach("Token exhaustion blocks writing before recording")
    }

    func testExistingDraftRemainsViewableAndDeletableWhenTokensExhausted() {
        continueAfterFailure = false
        launch(["-ResetSummaryFixture"])
        typeSummary()
        app.buttons["חזרה"].firstMatch.tap()
        app.buttons["שמירת טיוטה וחזרה"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["שמירת הסיכום"])
        waitForExpectations(timeout: 5)
        app.buttons["חזרה"].firstMatch.tap()
        XCTAssertTrue(app.buttons["שמירת טיוטה ויציאה"].waitForExistence(timeout: 5))
        app.buttons["שמירת טיוטה ויציאה"].tap()
        app.terminate()
        launch(["-SummaryAllowanceDenied"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "מכסת ה־AI החודשית נוצלה")).firstMatch.waitForExistence(timeout: 10))
        openEditor()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Synthetic recovery note")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["session.editSummaryText"].isEnabled)
        app.buttons["session.editSummaryText"].tap()
        let editor = app.textFields["session.summaryText"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap(); editor.typeText(" edited")
        app.terminate()
        launch(["-SummaryAllowanceDenied"])
        openEditor()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "edited")).firstMatch.waitForExistence(timeout: 5))
        attach("Recovered draft stays editable despite exhausted allowance")
        app.buttons["summary.copyDraft"].tap()
        XCTAssertTrue(app.buttons["הטיוטה הועתקה"].exists)
        app.buttons["summary.discardDraft"].tap()
        XCTAssertTrue(app.buttons["מחיקת הטיוטה"].waitForExistence(timeout: 5))
        app.buttons["מחיקת הטיוטה"].tap()
        app.terminate()
        launch()
        XCTAssertTrue(app.buttons["session.emptySummary"].waitForExistence(timeout: 5))
    }

    func testAllowanceLookupFailureIsShownOnEntryWithoutClaimingExhaustion() {
        launch(["-ResetSummaryFixture", "-SummaryAllowanceUnavailable"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "לא ניתן לבדוק כרגע את מכסת")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "מכסת ה־AI החודשית נוצלה")).firstMatch.exists)
        typeSummary()
        XCTAssertTrue(app.staticTexts["fixture.counts"].firstMatch.label.contains("anonymize=0"))
        attach("Allowance unavailable — local writing remains available")
    }

    func testLowAllowanceWarnsWithoutBlockingWriting() {
        launch(["-ResetSummaryFixture", "-SummaryAllowanceLow"])
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "10%")).firstMatch.waitForExistence(timeout: 10))
        typeSummary()
        attach("Low allowance permits writing with warning")
    }

    func testUncertainSaveRequiresManualCheckAndDuplicateConfirmation() {
        continueAfterFailure = false
        launch(["-ResetSummaryFixture", "-SummaryUncertainSave"])
        typeSummary(); save()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "לא ניתן לוודא אם הסיכום נשמר")).firstMatch.waitForExistence(timeout: 10))
        app.buttons["summary.checkSessions"].tap()
        XCTAssertTrue(app.buttons["חזרה לטיוטה"].waitForExistence(timeout: 10))
        app.buttons["חזרה לטיוטה"].tap()
        app.buttons["summary.manualRetry"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "עלול ליצור מפגש כפול")).firstMatch.waitForExistence(timeout: 5))
        attach("Manual retry requires explicit duplicate-risk confirmation")
        app.buttons["ביטול"].tap()
        XCTAssertTrue(app.staticTexts["fixture.counts"].firstMatch.label.contains("insert=1"))
        app.buttons["summary.manualRetry"].tap()
        app.buttons["בדקתי — לשמור שוב"].tap()
        XCTAssertTrue(app.buttons["fixture.open"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["fixture.counts"].firstMatch.label.contains("insert=2"))
        attach("Explicit manual retry only — duplicate risk accepted")
    }

    func testTypedFailureRelaunchAndSuccessfulRetry() {
        continueAfterFailure = false
        launch(["-ResetSummaryFixture", "-SummaryProcessingFailure"])
        typeSummary(); save()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "מכסת ה־AI החודשית נוצלה")).firstMatch.waitForExistence(timeout: 10))
        attach("Hebrew processing failure — draft retained")
        app.terminate()
        launch()
        openEditor()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Synthetic recovery note")).firstMatch.waitForExistence(timeout: 5))
        save()
        XCTAssertTrue(app.buttons["fixture.open"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["fixture.counts"].firstMatch.label.contains("insert=1"))
        app.terminate()
        launch()
        XCTAssertTrue(app.buttons["session.emptySummary"].waitForExistence(timeout: 5))
        attach("Confirmed save cleaned recovery material")
    }
    func testVoiceTranscriptSurvivesRelaunchWithoutRetranscription() {
        continueAfterFailure = false
        launch(["-ResetSummaryFixture", "-SummaryVoiceFixture", "-SummaryProcessingFailure"])
        let transcribe = app.buttons["תמלול"]
        XCTAssertTrue(transcribe.waitForExistence(timeout: 5))
        transcribe.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "מכסת ה־AI החודשית נוצלה")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["fixture.counts"].firstMatch.label.contains("transcribe=1"))
        attach("Transcript retained after anonymization failure")
        app.terminate()
        launch()
        XCTAssertTrue(app.buttons["ניסיון עיבוד נוסף"].waitForExistence(timeout: 5))
        app.swipeUp()
        app.buttons["ניסיון עיבוד נוסף"].tap()
        let processed = NSPredicate(format: "label CONTAINS %@", "anonymize=2")
        expectation(for: processed, evaluatedWith: app.staticTexts["fixture.counts"].firstMatch)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.staticTexts["fixture.counts"].firstMatch.label.contains("transcribe=1"))
        app.buttons["session.save"].tap()
        XCTAssertTrue(app.buttons["fixture.open"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["fixture.counts"].firstMatch.label.contains("insert=1"))
        attach("Voice retry reused transcript and saved once")
    }

    func testCommittedInsertWithLostResponseKeepsDraftAndBlocksDuplicate() {
        verifyUncertainSave(option: "-SummaryUncertainSave", committed: 1)
    }

    func testRequestNeverReachedServerKeepsDraftAndBlocksUnsafeRetry() {
        verifyUncertainSave(option: "-SummaryNeverReached", committed: 0)
    }

    private func verifyUncertainSave(option: String, committed: Int) {
        continueAfterFailure = false
        launch(["-ResetSummaryFixture", option])
        typeSummary(); save()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "לא ניתן לוודא אם הסיכום נשמר")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["שמירת הסיכום"].isEnabled)
        // Leaving the full summary must not force the user to discard it.
        app.buttons["חזרה"].firstMatch.tap()
        XCTAssertTrue(app.buttons["שמירת טיוטה וחזרה"].waitForExistence(timeout: 5))
        app.buttons["שמירת טיוטה וחזרה"].tap()
        XCTAssertFalse(app.buttons["session.save"].isEnabled)
        app.buttons["חזרה"].firstMatch.tap()
        XCTAssertTrue(app.buttons["שמירת טיוטה ויציאה"].waitForExistence(timeout: 5))
        app.buttons["שמירת טיוטה ויציאה"].tap()
        app.terminate()
        launch()
        let counts = app.staticTexts["fixture.counts"].firstMatch.label
        XCTAssertTrue(counts.contains("insert=1"))
        XCTAssertTrue(counts.contains("committed=\(committed)"))
        openEditor()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Synthetic recovery note")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["שמירת הסיכום"].isEnabled)
        attach("Uncertain save preserved — simulated committed rows \(committed)")
    }
}
