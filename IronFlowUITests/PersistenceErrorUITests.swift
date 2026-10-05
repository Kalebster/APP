import XCTest

/// When the data store cannot be opened, the app shows a non-destructive error
/// screen instead of the main tabs, and "Tentar novamente" keeps it safe.
final class PersistenceErrorUITests: XCTestCase {
    @MainActor
    func testStoreFailureShowsErrorScreen() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = ["-simulate-persistence-failure"]
        app.launch()

        let title = app.staticTexts["persistence.error.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Error screen did not appear")
        XCTAssertFalse(app.tabBars.firstMatch.exists, "Main tabs must not be shown without a store")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "5-persistence-error"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Retrying opens the same store again; while it keeps failing, the error screen stays.
        let retry = app.buttons["persistence.error.retry"]
        XCTAssertTrue(retry.exists, "Retry button not found")
        retry.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Error screen disappeared after retrying")
        XCTAssertFalse(app.tabBars.firstMatch.exists, "Main tabs appeared although the store still fails")
    }
}
