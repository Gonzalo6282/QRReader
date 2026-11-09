import XCTest

/// First run, every paywall's close button, and the camera-denied state (SPEC tests 4–6).
/// UI tests run without SDK keys, so the app's own paywall is shown for every placement.
@MainActor
final class FlowTests: XCTestCase {
    override nonisolated func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extra
        app.launch()
        return app
    }

    /// Soft paywalls hide the close button for 2.5 s, then it appears and closes the paywall.
    private func closeSoftPaywall(_ app: XCUIApplication, openedAt start: Date) {
        XCTAssertTrue(app.staticTexts["Do everything with your scans"].waitForExistence(timeout: 10))
        let close = app.buttons["paywallClose"]
        // Only meaningful if the paywall showed up well inside its 2.5 s delay (CI can be slow).
        if Date().timeIntervalSince(start) < 1.5 {
            XCTAssertFalse(close.exists, "Soft paywall must not offer Close straight away")
        }
        XCTAssertTrue(close.waitForExistence(timeout: 6), "Close never appeared")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
    }

    /// Hard paywalls can be closed at once.
    private func closeHardPaywall(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Do everything with your scans"].waitForExistence(timeout: 10))
        let close = app.buttons["paywallClose"]
        XCTAssertTrue(close.waitForExistence(timeout: 2), "Hard paywall must show Close")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
    }

    private func assertLegalLinks(_ app: XCUIApplication) {
        for title in ["Restore", "Terms", "Privacy"] {
            XCTAssertTrue(app.buttons[title].exists, "Paywall is missing \(title)")
        }
    }

    @MainActor func testFirstRunEndsOnASoftPaywallThenTheScanner() {
        let app = launch(["-showOnboarding"])
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        // Camera step: skip the system prompt.
        let photos = app.buttons["Scan from photos instead"]
        XCTAssertTrue(photos.waitForExistence(timeout: 5))
        photos.tap()
        let cont = app.buttons["Continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 5))
        cont.tap()
        // Analytics question appears only in the UK, EEA and Switzerland.
        let dontAllow = app.buttons["Don’t allow"]
        var start = Date()
        if dontAllow.waitForExistence(timeout: 3) { start = Date(); dontAllow.tap() }
        closeSoftPaywall(app, openedAt: start)
        XCTAssertTrue(app.buttons["batchChip"].waitForExistence(timeout: 5), "Scanner not shown after the paywall")
    }

    @MainActor func testBatchPaywallClosesAtOnce() {
        let app = launch()
        let chip = app.buttons["batchChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()
        assertLegalLinks(app)
        closeHardPaywall(app)
    }

    @MainActor func testCreateSavePaywallClosesAtOnce() {
        let app = launch()
        app.tabBars.buttons["Create"].tap()
        let link = app.buttons["create-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        let field = app.textFields["field-url"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("slice-of-life.uk\n")
        let save = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Save")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        closeHardPaywall(app)
    }

    @MainActor func testSettingsUpgradeIsASoftPaywall() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Try Pro free")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let start = Date()
        card.tap()
        closeSoftPaywall(app, openedAt: start)
    }

    @MainActor func testCameraDeniedOffersSettingsAndPhotos() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Camera access is off"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        XCTAssertTrue(app.staticTexts["Turn on the camera in Settings to scan live. You can still scan codes in photos and screenshots."].exists)
    }
}
