import XCTest

final class LaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsTheFourTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        for tab in ["Scan", "Create", "History", "Settings"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 10), "Missing tab \(tab)")
        }
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.otherElements["screen-History"].waitForExistence(timeout: 5)
            || app.staticTexts["Scan history (M5)"].exists)
    }
}
