import XCTest

/// The BMR calculator ("Calcular TMB"), opened from the calorie goal's editor: each choice saved at
/// once, the result following it, "Fechar" back to the editor and the suggested goal used as the goal.
/// Runs on an in-memory store and empty preferences.
final class BMRCalculatorUITests: IronFlowUITestCase {
    @MainActor
    func testChoicesUpToUsingTheGoal() throws {
        continueAfterFailure = false
        let app = launchOnHome(seed: ["weights:80@1", "profile:180:2300"])
        openCalculator(in: app)

        let intro = element("bmr.intro", in: app)
        XCTAssertEqual(intro.label, "A taxa metabólica basal é o quanto o seu corpo gasta parado. Usamos o seu peso (80 kg) e a sua altura (180 cm).")
        let message = element("bmr.message", in: app)
        XCTAssertEqual(message.label, "Escolha o sexo e a data de nascimento para ver o resultado.")
        XCTAssertFalse(app.buttons["bmr.use"].exists, "A goal to use without a result")
        XCTAssertTrue(app.buttons["bmr.activity.moderate"].isSelected, "Moderado is not the default")
        XCTAssertTrue(app.buttons["bmr.goal.maintain"].isSelected, "Manter is not the default")

        let male = app.buttons["bmr.sex.male"]
        male.tap()
        XCTAssertTrue(waitForLabel(of: message, toBe: "Falta escolher a data de nascimento completa."), "Message: \(message.label)")
        XCTAssertTrue(male.isSelected)

        // 1 de janeiro of the most recent year of the menu: 15 years old today.
        let year = Calendar(identifier: .gregorian).component(.year, from: .now) - 15
        choose("1", in: "bmr.birth.day", app: app)
        choose("janeiro", in: "bmr.birth.month", app: app)
        choose("\(year)", in: "bmr.birth.year", app: app)

        // 10 × 80 + 6,25 × 180 − 5 × 15 + 5 = 1.855; spent 1.855 × 1,55 = 2.875,25, kept as the goal.
        let goal = element("bmr.result.goal", in: app)
        XCTAssertTrue(waitForLabel(of: goal, toBe: "meta sugerida: 2.880 kcal"), "Goal: \(goal.label)")
        XCTAssertEqual(element("bmr.result.bmr", in: app).label, "TMB: 1.860 kcal")
        XCTAssertEqual(element("bmr.result.expenditure", in: app).label, "gasto do dia: 2.880 kcal")
        XCTAssertEqual(element("bmr.note", in: app).label, "Valores em kcal por dia · meta para manter o peso")
        XCTAssertFalse(message.exists, "Message shown with the result")

        // Lightly active and losing weight: 1.855 × 1,375 = 2.550,63, minus 400.
        app.buttons["bmr.activity.light"].tap()
        app.buttons["bmr.goal.lose"].tap()
        XCTAssertTrue(waitForLabel(of: goal, toBe: "meta sugerida: 2.150 kcal"), "Goal: \(goal.label)")
        XCTAssertEqual(element("bmr.result.expenditure", in: app).label, "gasto do dia: 2.550 kcal")
        XCTAssertEqual(element("bmr.note", in: app).label, "Valores em kcal por dia · meta para perder peso (\u{2212}400 kcal por dia)")
        XCTAssertTrue(app.buttons["bmr.activity.light"].isSelected)
        XCTAssertFalse(app.buttons["bmr.activity.moderate"].isSelected)

        // "Fechar" goes back to the editor, and the choices were saved.
        app.buttons["bmr.close"].tap()
        XCTAssertTrue(intro.waitForNonExistence(timeout: 10), "Calculator not closed")
        let field = app.textFields["metric.editor.field"]
        XCTAssertTrue(field.exists, "The editor closed with the calculator")
        app.buttons["metric.editor.bmr"].tap()
        XCTAssertTrue(waitForLabel(of: goal, toBe: "meta sugerida: 2.150 kcal"), "Choices lost: \(goal.label)")

        // Using the goal closes both sheets and says so on the Início.
        let use = app.buttons["bmr.use"]
        XCTAssertEqual(use.label, "Usar 2.150 kcal como meta")
        use.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "Editor not closed")
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No notice after using the goal")
        XCTAssertEqual(toast.label, "Meta de 2.150 kcal salva")
        let card = app.buttons["home.metric.dailyCalorieGoal"]
        XCTAssertTrue(card.label.contains("2.150 kcal"), "Goal: \(card.label)")
    }

    /// The choices saved before open the calculator with its result: screenshots 87 and 88.
    @MainActor
    func testCalculatorWithSavedChoices() throws {
        continueAfterFailure = false
        let app = launchOnHome(seed: ["weights:80@1", "profile:180:2300", "bmr:male:30:lose"])
        openCalculator(in: app)

        XCTAssertTrue(app.buttons["bmr.sex.male"].isSelected)
        XCTAssertEqual(app.buttons["bmr.birth.day"].value as? String, "1")
        XCTAssertEqual(app.buttons["bmr.birth.month"].value as? String, "janeiro")
        XCTAssertTrue(app.buttons["bmr.activity.moderate"].isSelected)
        XCTAssertTrue(app.buttons["bmr.goal.lose"].isSelected)
        attachScreenshot(named: "87-bmr-calculator", of: app)

        // 10 × 80 + 6,25 × 180 − 5 × 30 + 5 = 1.780; spent 1.780 × 1,55 = 2.759; goal 2.759 − 400.
        XCTAssertEqual(element("bmr.result.bmr", in: app).label, "TMB: 1.780 kcal")
        XCTAssertEqual(element("bmr.result.expenditure", in: app).label, "gasto do dia: 2.760 kcal")
        XCTAssertEqual(element("bmr.result.goal", in: app).label, "meta sugerida: 2.360 kcal")
        let close = app.buttons["bmr.close"]
        for _ in 0..<4 where !close.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(close.isHittable, "The end of the calculator was not reached")
        XCTAssertEqual(app.buttons["bmr.use"].label, "Usar 2.360 kcal como meta")
        attachScreenshot(named: "88-bmr-result", of: app)
    }

    // MARK: - Support

    /// Opens the calorie goal's editor and, from it, the calculator.
    @MainActor
    private func openCalculator(in app: XCUIApplication) {
        app.buttons["home.metric.dailyCalorieGoal"].tap()
        let link = app.buttons["metric.editor.bmr"]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "No link to the calculator")
        XCTAssertEqual(link.label, "Calcular pela minha TMB")
        link.tap()
        XCTAssertTrue(element("bmr.intro", in: app).waitForExistence(timeout: 10), "Calculator not shown")
    }

    /// Opens a menu of the date of birth, picks `option` and waits until its box shows it.
    @MainActor
    private func choose(_ option: String, in menu: String, app: XCUIApplication) {
        let box = app.buttons[menu]
        box.tap()
        let items = app.buttons.matching(NSPredicate(format: "label == %@", option))
        XCTAssertTrue(items.firstMatch.waitForExistence(timeout: 5), "No '\(option)' in \(menu)")
        let item = items.allElementsBoundByIndex.first { $0.isHittable } ?? items.firstMatch
        item.tap()
        XCTAssertTrue(box.waitForValue(option), "\(menu) shows \(String(describing: box.value))")
    }
}
