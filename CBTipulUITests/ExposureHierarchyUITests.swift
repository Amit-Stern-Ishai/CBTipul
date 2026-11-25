import XCTest
final class ExposureHierarchyUITests: XCTestCase {
 @MainActor func testMoveCancelAndSave() {
  let app=XCUIApplication();app.launchArguments=["-UITesting","-ExposureHierarchyReview","-ExposureEditingReview"];app.launch()
  XCTAssertTrue(app.buttons["הזזה למטה"].firstMatch.waitForExistence(timeout:20))
  let fields=app.textFields
  let original=fields.element(boundBy:0).value as? String
  app.buttons["הזזה למטה"].firstMatch.tap()
  XCTAssertNotEqual(fields.element(boundBy:0).value as? String,original)
  app.buttons["ביטול עריכה"].tap();app.alerts.buttons["ויתור על השינויים"].tap()
  XCTAssertTrue(app.buttons["עריכה"].exists);app.buttons["עריכה"].tap()
  XCTAssertEqual(fields.element(boundBy:0).value as? String,original)
  app.buttons["הזזה למטה"].firstMatch.tap();app.buttons["שמירה"].tap()
  XCTAssertTrue(app.staticTexts["המדרג נשמר"].waitForExistence(timeout:3));XCTAssertTrue(app.staticTexts["0%"].exists)
 }
}
