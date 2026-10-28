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
    /// refused). Past the end of the centered value, the cursor lands after it.
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
        XCTAssertTrue(today.label.contains("Nada programado para hoje."), "Today card: \(today.label)")
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

    /// The editor opens without the keyboard; − and + step from the reference value (nothing saved),
    /// never pass the limits, bring a number beyond them back, and "Salvar" shows its notice.
    @MainActor
    func testEditorStepsWithinTheLimits() throws {
        continueAfterFailure = false
        let app = launchOnHome()

        card("height", in: app).tap()
        let field = app.textFields["metric.editor.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Editor not shown")
        XCTAssertTrue(app.staticTexts["Altura"].exists, "No title")
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2), "The keyboard opened by itself")
        let minus = app.buttons["metric.editor.minus"]
        let plus = app.buttons["metric.editor.plus"]
        XCTAssertEqual(plus.label, "Aumentar 1 cm")

        // Nothing saved and the field empty: 170 cm is the start.
        plus.tap()
        XCTAssertTrue(field.waitForValue("171"), "Field holds \(String(describing: field.value))")
        minus.tap()
        minus.tap()
        XCTAssertTrue(field.waitForValue("169"), "Field holds \(String(describing: field.value))")

        // At the upper limit + is unavailable; past it, − brings the value back to the limit.
        focusEditorField(field)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "250")
        XCTAssertTrue(field.waitForValue("250"))
        XCTAssertFalse(plus.isEnabled, "+ available at the limit")
        XCTAssertTrue(minus.isEnabled)
        field.typeText(XCUIKeyboardKey.delete.rawValue + "9")
        XCTAssertTrue(field.waitForValue("259"))
        minus.tap()
        XCTAssertTrue(field.waitForValue("250"), "Field holds \(String(describing: field.value))")

        app.buttons["metric.editor.save"].tap()
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No notice after saving")
        XCTAssertEqual(toast.label, "Altura salva")
        XCTAssertTrue(card("height", in: app).label.contains("250 cm"), "Height: \(card("height", in: app).label)")

        // The weight steps 0,1 kg from 70,0 kg, and the goal 50 kcal from 2.000 kcal.
        card("bodyWeight", in: app).tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Weight editor not shown")
        XCTAssertTrue(app.staticTexts["Cada novo peso fica registrado com a data de hoje."].exists, "No weight help")
        app.buttons["metric.editor.plus"].tap()
        XCTAssertTrue(field.waitForValue("70,1"), "Field holds \(String(describing: field.value))")
        app.buttons["metric.editor.cancel"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "Weight editor not closed")

        card("dailyCalorieGoal", in: app).tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Goal editor not shown")
        XCTAssertTrue(app.staticTexts["Meta diária de calorias"].exists, "No goal title")
        XCTAssertTrue(app.staticTexts["Quantas calorias você quer comer por dia."].exists, "No goal help")
        app.buttons["metric.editor.minus"].tap()
        XCTAssertTrue(field.waitForValue("1.950"), "Field holds \(String(describing: field.value))")
        app.buttons["metric.editor.save"].tap()
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No notice after saving the goal")
        XCTAssertEqual(toast.label, "Meta salva")
        XCTAssertTrue(card("dailyCalorieGoal", in: app).label.contains("1.950 kcal"), "Goal: \(card("dailyCalorieGoal", in: app).label)")
    }

    /// The weight editor lists the latest records with their changes, and a weight with three decimals
    /// is refused with its message.
    @MainActor
    func testWeightEditorShowsTheLatestRecords() throws {
        continueAfterFailure = false
        let app = launchOnHome(seed: ["weights:81.2@14|80.6@7|80@2"])

        card("bodyWeight", in: app).tap()
        let field = app.textFields["metric.editor.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Editor not shown")
        XCTAssertEqual(field.value as? String, "80")
        XCTAssertTrue(app.staticTexts["Peso corporal"].exists, "No title")
        let records = app.descendants(matching: .any).matching(identifier: "metric.editor.record")
        XCTAssertEqual(records.count, 3)
        XCTAssertTrue(records.element(boundBy: 0).label.hasSuffix(", 80 kg, \u{2212}0,6 kg"), "Newest: \(records.element(boundBy: 0).label)")
        XCTAssertTrue(records.element(boundBy: 2).label.hasSuffix(", 81,2 kg"), "Oldest: \(records.element(boundBy: 2).label)")
        attachScreenshot(named: "85-weight-editor", of: app)

        focusEditorField(field)
        // The decimal key of the simulator's region: both are read as decimals.
        let separator = app.keys[","].exists ? "," : "."
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "80\(separator)500")
        app.buttons["metric.editor.save"].tap()
        let error = app.descendants(matching: .any)["metric.editor.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), "No error for three decimals")
        XCTAssertEqual(error.label, "Use no máximo 2 casas decimais.")

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "\(separator)4")
        XCTAssertTrue(field.waitForValue("80\(separator)4"), "Field holds \(String(describing: field.value))")
        app.buttons["metric.editor.save"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "Editor not closed")
        XCTAssertTrue(card("bodyWeight", in: app).label.contains("80,4 kg"), "Weight: \(card("bodyWeight", in: app).label)")

        // Today's weight is a new record; saved again today, it is updated, not added.
        card("bodyWeight", in: app).tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Editor not shown again")
        XCTAssertEqual(records.count, 4)
        app.buttons["metric.editor.plus"].tap()
        app.buttons["metric.editor.save"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "Editor not closed")
        card("bodyWeight", in: app).tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Editor not shown a third time")
        XCTAssertEqual(records.count, 4)
        XCTAssertTrue(records.element(boundBy: 0).label.contains("80,5 kg"), "Newest: \(records.element(boundBy: 0).label)")
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
