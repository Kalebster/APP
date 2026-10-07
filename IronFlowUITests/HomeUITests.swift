import XCTest

/// The Início tab: header, today's workout and the quick summary (edit values and choose indicators).
/// Runs on an in-memory store and empty preferences.
final class HomeUITests: XCTestCase {
    @MainActor
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extraArguments
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["home.header"].waitForExistence(timeout: 10), "Home not shown")
        return app
    }

    @MainActor
    private func card(_ metric: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["home.metric.\(metric)"]
    }

    /// Opens a card's editor, types the value and saves.
    @MainActor
    private func enterValue(_ text: String, on metric: String, in app: XCUIApplication) {
        card(metric, in: app).tap()
        let field = app.textFields["metric.editor.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Editor not shown")
        field.tap()
        field.typeText(text)
        let save = app.buttons["metric.editor.save"]
        XCTAssertTrue(save.isEnabled, "Save disabled with a valid value")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10), "Editor not closed")
    }

    @MainActor
    private func attachScreenshot(named name: String, of app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testEmptyHome() throws {
        continueAfterFailure = false
        let app = launch()

        let today = app.descendants(matching: .any)["home.today"]
        XCTAssertTrue(today.exists, "Today card not shown")
        XCTAssertTrue(today.label.contains("Você ainda não tem treinos."), "Today card: \(today.label)")

        let weight = card("bodyWeight", in: app)
        let height = card("height", in: app)
        let goal = card("dailyCalorieGoal", in: app)
        for element in [weight, height, goal] {
            XCTAssertTrue(element.exists, "Summary card missing")
            XCTAssertTrue(element.label.contains("Adicionar"), "Card with a value: \(element.label)")
        }
        XCTAssertLessThan(weight.frame.minX, height.frame.minX)
        XCTAssertLessThan(height.frame.minX, goal.frame.minX)
        attachScreenshot(named: "21-home-empty", of: app)

        // With a workout, nothing is planned for today yet.
        app.tabBars.buttons["Treinos"].tap()
        let add = app.buttons["workouts.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Add workout button not found")
        add.tap()
        let name = app.textFields["workout.name.field"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "Name field not found")
        name.tap()
        name.typeText("Push")
        app.buttons["workout.name.save"].tap()
        XCTAssertTrue(app.navigationBars["Push"].waitForExistence(timeout: 10), "Workout not created")
        app.tabBars.buttons["Início"].tap()
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        XCTAssertTrue(today.label.contains("Nenhum treino planejado para hoje."), "Today card: \(today.label)")
    }

    @MainActor
    func testEditSummaryValues() throws {
        continueAfterFailure = false
        let app = launch()

        enterValue("80", on: "bodyWeight", in: app)
        XCTAssertTrue(card("bodyWeight", in: app).label.contains("80 kg"), "Weight: \(card("bodyWeight", in: app).label)")

        // An out-of-range value cannot be saved.
        card("height", in: app).tap()
        let field = app.textFields["metric.editor.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Editor not shown")
        field.tap()
        field.typeText("99")
        XCTAssertFalse(app.buttons["metric.editor.save"].isEnabled, "Save enabled with an invalid height")
        XCTAssertTrue(app.descendants(matching: .any)["metric.editor.error"].exists, "Error not shown")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "180")
        app.buttons["metric.editor.save"].tap()
        XCTAssertTrue(app.buttons["metric.editor.save"].waitForNonExistence(timeout: 10), "Editor not closed")
        XCTAssertTrue(card("height", in: app).label.contains("180 cm"), "Height: \(card("height", in: app).label)")

        enterValue("2300", on: "dailyCalorieGoal", in: app)
        XCTAssertTrue(card("dailyCalorieGoal", in: app).label.contains("2.300 kcal"), "Goal: \(card("dailyCalorieGoal", in: app).label)")
        attachScreenshot(named: "22-home", of: app)

        // A new weight replaces the one shown.
        card("bodyWeight", in: app).tap()
        let weightField = app.textFields["metric.editor.field"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 10), "Editor not shown")
        XCTAssertEqual(weightField.value as? String, "80")
        weightField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "81")
        app.buttons["metric.editor.save"].tap()
        XCTAssertTrue(app.buttons["metric.editor.save"].waitForNonExistence(timeout: 10), "Editor not closed")
        XCTAssertTrue(card("bodyWeight", in: app).label.contains("81 kg"), "Weight: \(card("bodyWeight", in: app).label)")
    }

    @MainActor
    func testCustomizeSummary() throws {
        continueAfterFailure = false
        let app = launch()

        app.buttons["home.customize"].tap()
        let heightOption = app.buttons["customize.height"]
        XCTAssertTrue(heightOption.waitForExistence(timeout: 10), "Customize sheet not shown")
        heightOption.tap()
        attachScreenshot(named: "23-home-customize", of: app)
        app.buttons["customize.done"].tap()
        XCTAssertTrue(app.buttons["customize.done"].waitForNonExistence(timeout: 10), "Customize sheet not closed")

        XCTAssertFalse(card("height", in: app).exists, "Removed indicator still shown")
        XCTAssertLessThan(card("bodyWeight", in: app).frame.minX, card("dailyCalorieGoal", in: app).frame.minX)

        // Chosen again, it comes last.
        app.buttons["home.customize"].tap()
        XCTAssertTrue(heightOption.waitForExistence(timeout: 10))
        heightOption.tap()
        app.buttons["customize.done"].tap()
        XCTAssertTrue(card("height", in: app).waitForExistence(timeout: 10), "Indicator not shown again")
        XCTAssertLessThan(card("dailyCalorieGoal", in: app).frame.minX, card("height", in: app).frame.minX)

        // With no indicator, the section explains how to choose them.
        app.buttons["home.customize"].tap()
        for option in ["bodyWeight", "dailyCalorieGoal", "height"] {
            let button = app.buttons["customize.\(option)"]
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            button.tap()
        }
        app.buttons["customize.done"].tap()
        let hint = app.staticTexts["Escolha até 3 indicadores em Personalizar."]
        XCTAssertTrue(hint.waitForExistence(timeout: 10), "Empty summary hint not shown")
    }

    @MainActor
    func testDarkAppearance() throws {
        continueAfterFailure = false
        let app = launch(extraArguments: ["-ui-dark-appearance"])
        enterValue("80", on: "bodyWeight", in: app)
        enterValue("180", on: "height", in: app)
        enterValue("2300", on: "dailyCalorieGoal", in: app)
        attachScreenshot(named: "24-home-dark", of: app)
    }
}
