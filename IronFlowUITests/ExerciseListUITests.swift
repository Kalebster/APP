import XCTest

/// The Exercises tab shows one card per muscle group; a card opens that group's exercises.
/// Searching from the groups screen finds exercises in every group.
/// Runs on an in-memory store where the 71 built-in exercises are installed at launch.
final class ExerciseListUITests: XCTestCase {
    /// Any element whose accessibility label is exactly `label` (rows combine their texts).
    @MainActor
    private func element(labeled label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    @MainActor
    private func groupCard(_ rawValue: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["exercises.group.\(rawValue)"]
    }

    @MainActor
    private func searchField(in app: XCUIApplication) -> XCUIElement {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Search field not found")
        return field
    }

    @MainActor
    func testGroupsAreShownFirst() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")

        let chest = groupCard("chest", in: app)
        XCTAssertTrue(chest.waitForExistence(timeout: 10), "Chest card not found")
        XCTAssertTrue(chest.label.contains("9 exercícios"), "Unexpected chest card label: \(chest.label)")
        let back = groupCard("back", in: app)
        XCTAssertTrue(back.exists, "Back card not found")
        XCTAssertTrue(back.label.contains("7 exercícios"), "Unexpected back card label: \(back.label)")
        XCTAssertFalse(element(labeled: "Supino Reto com Barra", in: app).exists)

        attachScreenshot(named: "6-exercises-groups", of: app)
    }

    @MainActor
    func testGroupCardOpensItsExercises() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")

        let back = groupCard("back", in: app)
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Back card not found")
        back.tap()

        XCTAssertTrue(element(labeled: "Barra Fixa", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(element(labeled: "Supino Reto com Barra", in: app).exists)
        assertScreenIsDark(app, "group screen")
        attachScreenshot(named: "7-exercises-group", of: app)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(groupCard("chest", in: app).waitForExistence(timeout: 10), "Groups not shown after going back")
    }

    /// Few keys are typed and the field's own clear button empties it, so the test does not depend on
    /// dozens of key presses on a busy simulator. What was typed is checked before the results, so a
    /// lost key shows as a wrong text and not as a missing screen, and the group cards must be back
    /// before anything is typed again.
    @MainActor
    func testGlobalSearchFindsMatchesAndShowsNoResults() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")
        XCTAssertTrue(groupCard("chest", in: app).waitForExistence(timeout: 10), "Chest card not found")

        let field = searchField(in: app)
        field.tapAndWaitForKeyboardFocus()
        field.typeText("agach")
        XCTAssertEqual(field.value as? String, "agach", "The search field does not hold what was typed")

        XCTAssertTrue(element(labeled: "Agachamento Livre com Barra", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(element(labeled: "Supino Reto com Barra", in: app).exists)
        XCTAssertTrue(app.descendants(matching: .any)["exercises.section.quadriceps"].exists, "Quadriceps section not shown")
        XCTAssertFalse(groupCard("chest", in: app).exists, "Group cards shown during search")
        attachScreenshot(named: "8-exercises-search", of: app)

        let clear = field.buttons.firstMatch
        XCTAssertTrue(clear.waitForExistence(timeout: 10), "The clear button of the search field is not shown")
        clear.tap()
        XCTAssertTrue(groupCard("chest", in: app).waitForExistence(timeout: 10), "Group cards not back after clearing the search")

        field.tapAndWaitForKeyboardFocus()
        field.typeText("xyz")
        XCTAssertEqual(field.value as? String, "xyz", "The search field does not hold what was typed")
        XCTAssertTrue(app.descendants(matching: .any)["exercises.empty.search"].waitForExistence(timeout: 10), "No results message not shown")
    }

    @MainActor
    func testSearchInsideGroup() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")

        let chest = groupCard("chest", in: app)
        XCTAssertTrue(chest.waitForExistence(timeout: 10), "Chest card not found")
        chest.tap()
        XCTAssertTrue(element(labeled: "Supino Reto com Barra", in: app).waitForExistence(timeout: 10))

        let field = searchField(in: app)
        field.tapAndWaitForKeyboardFocus()
        field.typeText("inclinado")

        XCTAssertTrue(element(labeled: "Supino Inclinado com Barra", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(element(labeled: "Supino Inclinado com Halteres", in: app).exists)
        XCTAssertFalse(element(labeled: "Supino Reto com Barra", in: app).exists)
    }
}
