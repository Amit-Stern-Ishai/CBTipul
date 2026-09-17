import XCTest

/// Offline smoke: auth paints, then `-UITesting` enters demo shell.
final class SmokeTests: XCTestCase {

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

        let demoBanner = app.descendants(matching: .any)["demo.banner"]
        XCTAssertTrue(
            demoBanner.waitForExistence(timeout: 8),
            "Demo banner should be visible in demo mode"
        )
    }
}
