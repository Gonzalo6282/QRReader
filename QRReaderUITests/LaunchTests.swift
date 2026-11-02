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
        XCTAssertTrue(app.staticTexts["No scans yet"].waitForExistence(timeout: 5))
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

    @MainActor
    func testCreateShowsALivePreview() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.tabBars.buttons["Create"].tap()
        let link = app.buttons["create-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.staticTexts["Fill in the details to see your code"].waitForExistence(timeout: 5))
        let field = app.textFields["field-url"]
        field.tap()
        field.typeText("slice-of-life.uk")
        XCTAssertTrue(app.images["QR code preview"].waitForExistence(timeout: 5))
    }
}
