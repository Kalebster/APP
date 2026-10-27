import XCTest

/// The Início tab: header, today's workout and the quick summary (edit values and choose indicators).
/// Runs on an in-memory store and empty preferences.
final class HomeUITests: IronFlowUITestCase {
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
        focusEditorField(field)
        field.typeText(text)
        let save = app.buttons["metric.editor.save"]
        XCTAssertTrue(save.isEnabled, "Save disabled with a valid value")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10), "Editor not closed")
    }

    /// Taps the editor's field at its right edge and waits until it has keyboard focus: typing never
    /// counts on the field opening active (on a busy simulator it was not yet, and the keys were
    /// refused). The value is aligned right and ends at that edge, so the cursor lands after it.
    @MainActor
    private func focusEditorField(_ field: XCUIElement) {
        field.tapAndWaitForKeyboardFocus(at: CGVector(dx: 0.99, dy: 0.5))
    }

    @MainActor
    func testEmptyHome() throws {
        continueAfterFailure = false
        let app = launchOnHome()

        let today = app.descendants(matching: .any)["home.today"]
        XCTAssertTrue(today.exists, "Today card not shown")
        XCTAssertTrue(today.label.contains("Nenhum treino criado"), "Today card: \(today.label)")

        let weight = card("bodyWeight", in: app)
        let height = card("height", in: app)
        let goal = card("dailyCalorieGoal", in: app)
        for element in [weight, height, goal] {
            XCTAssertTrue(element.exists, "Summary card missing")
            XCTAssertTrue(element.label.contains("Adicionar"), "Card with a value: \(element.label)")
        }
        XCTAssertLessThan(weight.frame.minX, height.frame.minX)
        XCTAssertLessThan(height.frame.minX, goal.frame.minX)
        attachScreenshot(named: "53-home-no-workouts", of: app)

        // With a workout, nothing is planned for today yet.
        openTab("Treinos", in: app)
        createWorkout(named: "Push", in: app)
        openTab("Início", in: app)
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        XCTAssertTrue(today.label.contains("Nenhum treino planejado para hoje."), "Today card: \(today.label)")
    }

    @MainActor
    func testEditSummaryValues() throws {
        continueAfterFailure = false
        let app = launchOnHome()

        enterValue("80", on: "bodyWeight", in: app)
        XCTAssertTrue(card("bodyWeight", in: app).label.contains("80 kg"), "Weight: \(card("bodyWeight", in: app).label)")

        // An out-of-range value is not saved: the error shows when Salvar is tapped, not while typing.
        card("height", in: app).tap()
        let field = app.textFields["metric.editor.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Editor not shown")
        focusEditorField(field)
        field.typeText("99")
        let error = app.descendants(matching: .any)["metric.editor.error"]
        XCTAssertFalse(error.exists, "Error shown while typing")
        app.buttons["metric.editor.save"].tap()
        XCTAssertTrue(error.waitForExistence(timeout: 5), "Error not shown")
        XCTAssertTrue(field.exists, "Editor closed with an invalid height")
        focusEditorField(field)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "180")
        XCTAssertTrue(field.waitForValue("180"), "Height field holds \(String(describing: field.value))")
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
        focusEditorField(weightField)
        weightField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "81")
        XCTAssertTrue(weightField.waitForValue("81"), "Weight field holds \(String(describing: weightField.value))")
        app.buttons["metric.editor.save"].tap()
        XCTAssertTrue(app.buttons["metric.editor.save"].waitForNonExistence(timeout: 10), "Editor not closed")
        XCTAssertTrue(card("bodyWeight", in: app).label.contains("81 kg"), "Weight: \(card("bodyWeight", in: app).label)")
    }

    @MainActor
    func testCustomizeSummary() throws {
        continueAfterFailure = false
        let app = launchOnHome()

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

    /// Scrolled up, the content never shows behind the clock and the status icons: the screenshot is
    /// the proof, so the test first checks that the screen did scroll. At the default text size the
    /// Início scrolls only about 15 points on the iPhone 17 (the content almost fits), so this one runs
    /// with the largest non-accessibility text size, where it scrolls well past the status bar.
    @MainActor
    func testScrolledContentStaysBelowTheStatusBar() throws {
        continueAfterFailure = false
        let app = launchOnHome(extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"])
        let header = app.descendants(matching: .any)["home.header"]
        let before = header.frame.minY

        app.swipeUp()
        app.swipeUp()

        XCTAssertLessThan(header.frame.minY, before - 40, "The Home did not scroll")
        attachScreenshot(named: "47-home-scrolled", of: app)
    }
}
