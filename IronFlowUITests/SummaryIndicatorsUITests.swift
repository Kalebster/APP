import XCTest

/// The ten indicators of the "Resumo rápido": choosing up to three in Personalizar, in order, with the
/// value of each; and what a tap on each kind of card does. Runs on an in-memory store and empty
/// preferences, so the Início starts with Peso, Altura and Meta.
final class SummaryIndicatorsUITests: IronFlowUITestCase {
    /// Weights of 81,2, 80,6 and 80 kg in the last 14 days, a height and a goal, and a workout finished
    /// today.
    private static let seed = [
        "weights:81.2@14|80.6@7|80@2",
        "profile:180:2300",
        "workout:Push:Supino Reto com Barra",
        "finished-today:Push",
    ]

    /// The current month's name, as the app writes it: "outubro".
    private var monthName: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pt_BR")
        return calendar.standaloneMonthSymbols[calendar.component(.month, from: .now) - 1].lowercased()
    }

    @MainActor
    func testCustomizeThreeIndicatorsInOrder() throws {
        continueAfterFailure = false
        let app = launchOnHome(seed: Self.seed)
        XCTAssertEqual(card("bodyWeight", in: app).label, "Peso: 80 kg, editar")

        app.buttons["home.customize"].tap()
        let weight = app.buttons["customize.bodyWeight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 10), "Personalizar not shown")
        XCTAssertTrue(app.staticTexts["Personalizar resumo"].exists)

        // Each row says its value; the three chosen show their order and the others are unavailable.
        XCTAssertEqual(weight.label, "Peso, 80 kg · o último registro")
        XCTAssertEqual(weight.value as? String, "1º")
        XCTAssertEqual(app.buttons["customize.height"].value as? String, "2º")
        XCTAssertEqual(app.buttons["customize.dailyCalorieGoal"].label, "Meta de calorias, 2.300 kcal por dia")
        XCTAssertEqual(app.buttons["customize.dailyCalorieGoal"].value as? String, "3º")
        XCTAssertEqual(app.buttons["customize.lastWorkout"].label, "Último treino, Push · hoje")
        XCTAssertEqual(app.buttons["customize.streak"].label, "Sequência, Monte a Programação semanal para ter uma meta")
        XCTAssertEqual(app.buttons["customize.weightChange"].label, "Variação do peso, \u{2212}1,2 kg nos últimos 30 dias")
        XCTAssertEqual(app.buttons["customize.bmr"].label, "TMB, Escolha o sexo e a data de nascimento para ver o resultado.")
        XCTAssertTrue(app.buttons["customize.monthWorkouts"].label.hasSuffix(" em \(monthName)"), app.buttons["customize.monthWorkouts"].label)
        XCTAssertFalse(app.buttons["customize.streak"].isEnabled, "A fourth indicator can be chosen")

        // Unmarking renumbers the others and frees a place.
        toggle("height", in: app)
        XCTAssertTrue(app.buttons["customize.dailyCalorieGoal"].waitForValue("2º"), "Not renumbered")
        XCTAssertEqual(app.buttons["customize.height"].value as? String, "")
        XCTAssertTrue(app.buttons["customize.streak"].isEnabled, "No place freed")

        // The new one comes last.
        toggle("monthWorkouts", in: app)
        XCTAssertTrue(app.buttons["customize.monthWorkouts"].waitForValue("3º"), "Not chosen third")
        XCTAssertFalse(app.buttons["customize.height"].isEnabled)
        attachScreenshot(named: "86-customize", of: app)

        app.buttons["customize.done"].tap()
        XCTAssertTrue(weight.waitForNonExistence(timeout: 10), "Personalizar not closed")
        XCTAssertFalse(card("height", in: app).exists, "Removed indicator still shown")
        let goal = card("dailyCalorieGoal", in: app)
        let month = card("monthWorkouts", in: app)
        XCTAssertTrue(month.waitForExistence(timeout: 10), "New indicator not shown")
        XCTAssertLessThan(card("bodyWeight", in: app).frame.minX, goal.frame.minX)
        XCTAssertLessThan(goal.frame.minX, month.frame.minX)
        XCTAssertTrue(month.label.hasPrefix("Treinos no mês: "), month.label)

        // A computed indicator says what it is.
        month.tap()
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No notice")
        XCTAssertEqual(toast.label, "Treinos concluídos em \(monthName)")
    }

    /// The TMB card opens the calculator; the last workout's card says what it is.
    @MainActor
    func testCardsOpenWhatTheyShow() throws {
        continueAfterFailure = false
        let app = launchOnHome(seed: Self.seed)

        app.buttons["home.customize"].tap()
        XCTAssertTrue(app.buttons["customize.bodyWeight"].waitForExistence(timeout: 10), "Personalizar not shown")
        for option in ["bodyWeight", "height", "dailyCalorieGoal", "bmr", "lastWorkout", "weightChange"] {
            toggle(option, in: app)
        }
        app.buttons["customize.done"].tap()

        let bmr = card("bmr", in: app)
        XCTAssertTrue(bmr.waitForExistence(timeout: 10), "TMB not shown")
        XCTAssertEqual(bmr.label, "TMB: Escolha o sexo e a data de nascimento para ver o resultado., calcular")
        XCTAssertEqual(card("lastWorkout", in: app).label, "Último treino: Push, hoje")
        XCTAssertEqual(card("weightChange", in: app).label, "Variação do peso: \u{2212}1,2 kg nos últimos 30 dias")

        bmr.tap()
        let intro = app.descendants(matching: .any)["bmr.intro"]
        XCTAssertTrue(intro.waitForExistence(timeout: 10), "Calculator not shown")
        app.buttons["bmr.close"].tap()
        XCTAssertTrue(intro.waitForNonExistence(timeout: 10), "Calculator not closed")

        card("lastWorkout", in: app).tap()
        let toast = app.staticTexts["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No notice")
        XCTAssertEqual(toast.label, "O último treino concluído")
    }

    @MainActor
    private func card(_ metric: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["home.metric.\(metric)"]
    }

    /// Taps an indicator in Personalizar. A row behind the "Pronto" button, which stays at the bottom of
    /// the sheet, is first scrolled above it, so the tap reaches the row and not the button.
    @MainActor
    private func toggle(_ option: String, in app: XCUIApplication) {
        let row = app.buttons["customize.\(option)"]
        let done = app.buttons["customize.done"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No \(option) in Personalizar")
        for _ in 0..<4 where row.frame.maxY > done.frame.minY {
            app.swipeUp()
        }
        XCTAssertLessThanOrEqual(row.frame.maxY, done.frame.minY, "\(option) stays behind Pronto")
        row.tap()
    }
}
