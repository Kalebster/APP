import XCTest

/// The Exercises tab lists the built-in library, with search and a muscle group filter.
/// Runs on an in-memory store where the 71 built-in exercises are installed at launch.
final class ExerciseListUITests: XCTestCase {
    @MainActor
    private func launchOnExercisesTab() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let tab = app.tabBars.buttons["Exercícios"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Exercises tab not found")
        tab.tap()
        return app
    }

    /// Any element whose accessibility label is exactly `label` (rows combine their texts).
    @MainActor
    private func element(labeled label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    @MainActor
    private func attachScreenshot(named name: String, of app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testListShowsLibraryInSections() throws {
        continueAfterFailure = false
        let app = launchOnExercisesTab()

        XCTAssertTrue(element(labeled: "Supino Reto com Barra", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["exercises.section.chest"].exists, "Chest section not shown")

        attachScreenshot(named: "6-exercises-list", of: app)
    }

    @MainActor
    func testSearchFindsMatchesAndShowsNoResults() throws {
        continueAfterFailure = false
        let app = launchOnExercisesTab()
        XCTAssertTrue(element(labeled: "Supino Reto com Barra", in: app).waitForExistence(timeout: 10))

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10), "Search field not found")
        searchField.tap()
        searchField.typeText("agachamento")

        XCTAssertTrue(element(labeled: "Agachamento Livre com Barra", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(element(labeled: "Supino Reto com Barra", in: app).exists)
        attachScreenshot(named: "7-exercises-search", of: app)

        searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "agachamento".count))
        searchField.typeText("xyz")
        XCTAssertTrue(app.descendants(matching: .any)["exercises.empty.search"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testGroupFilter() throws {
        continueAfterFailure = false
        let app = launchOnExercisesTab()
        XCTAssertTrue(element(labeled: "Supino Reto com Barra", in: app).waitForExistence(timeout: 10))

        let filter = app.buttons["exercises.filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10), "Filter button not found")
        filter.tap()
        let backOption = app.buttons["Costas"]
        XCTAssertTrue(backOption.waitForExistence(timeout: 10), "Back filter option not found")
        backOption.tap()

        XCTAssertTrue(element(labeled: "Barra Fixa", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(element(labeled: "Supino Reto com Barra", in: app).exists)
        attachScreenshot(named: "8-exercises-filter", of: app)

        filter.tap()
        let allOption = app.buttons["Todos"]
        XCTAssertTrue(allOption.waitForExistence(timeout: 10), "All filter option not found")
        allOption.tap()
        XCTAssertTrue(element(labeled: "Supino Reto com Barra", in: app).waitForExistence(timeout: 10))
    }
}
