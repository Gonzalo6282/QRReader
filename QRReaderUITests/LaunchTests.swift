import XCTest

final class LaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsScannerAndTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        for tab in ["Scan", "Create", "History", "Settings"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 10), "Missing tab \(tab)")
        }
        // UI tests can't answer the camera prompt, so the scanner shows its "camera off" state.
        XCTAssertTrue(app.staticTexts["Camera access is off"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["batchChip"].exists)
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Scan history (M5)"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBatchChipShowsThePaywallForFreeUsers() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let chip = app.buttons["batchChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()
        XCTAssertTrue(app.staticTexts["Do everything with your scans"].waitForExistence(timeout: 10))
    }
}
