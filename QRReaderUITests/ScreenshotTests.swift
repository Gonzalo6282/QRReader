import XCTest

/// Store screenshots. Skipped in normal CI; the Screenshots workflow sets SCREENSHOTS=1
/// (passed as TEST_RUNNER_SCREENSHOTS) and collects the attachments.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENSHOTS"] == "1", "Screenshots run only in their own workflow")
    }

    private func launch(_ shot: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-premium", "-screenshots", "-shot", shot]
        app.launch()
        return app
    }

    private func capture(_ name: String) {
        sleep(2)  // let sheets and animations settle
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func test1Scan() {
        let app = launch("scan")
        XCTAssertTrue(app.tabBars.buttons["Scan"].waitForExistence(timeout: 15))
        capture("1-scan")
    }

    @MainActor func test2SafeLink() {
        let app = launch("link")
        XCTAssertTrue(app.otherElements["safety"].waitForExistence(timeout: 15) || app.staticTexts["resultTitle"].waitForExistence(timeout: 5))
        capture("2-safe-link")
    }

    @MainActor func test3WiFi() {
        let app = launch("wifi")
        XCTAssertTrue(app.staticTexts["resultTitle"].waitForExistence(timeout: 15))
        capture("3-wifi")
    }

    @MainActor func test4Create() {
        let app = launch("create")
        let link = app.buttons["create-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        link.tap()
        let field = app.textFields["field-url"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("lacantine-paris.fr\n")
        if app.keyboards.count > 0 { app.swipeDown() }
        let forest = app.buttons["Forest"]
        if forest.waitForExistence(timeout: 3) { forest.tap() }
        let logo = app.switches["Add logo in the middle"]
        if logo.waitForExistence(timeout: 3) { logo.switches.firstMatch.exists ? logo.switches.firstMatch.tap() : logo.tap() }
        XCTAssertTrue(app.images["QR code preview"].waitForExistence(timeout: 5))
        app.swipeDown()
        capture("4-create")
    }

    @MainActor func test5History() {
        let app = launch("history")
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 15))
        capture("5-history")
    }
}
