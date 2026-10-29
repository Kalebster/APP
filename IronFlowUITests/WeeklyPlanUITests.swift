import XCTest

/// The weekly plan: planning a workout for today, the Home card that follows the plan, a rest day and a
/// planned workout that is deleted. Works on any day of the week: the tests only use today's row.
/// Runs on an in-memory store with the built-in library; the workouts the tests plan come ready
/// (`-ui-seed`).
final class WeeklyPlanUITests: IronFlowUITestCase {
    /// Opens "Programação semanal" from the Treinos tab.
    @MainActor
    private func openPlan(in app: XCUIApplication) {
        let row = app.buttons["workouts.plan"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Programação semanal row not found")
        row.tap()
        XCTAssertTrue(element("plan.screen", in: app).waitForExistence(timeout: 10), "Plan screen not shown")
        XCTAssertTrue(waitForHiddenTabBar(in: app), "Tab bar shown on the plan")
    }

    /// Goes back from the plan to the Treinos list with "‹ Treinos".
    @MainActor
    private func closePlan(in app: XCUIApplication) {
        let back = app.buttons["plan.back"]
        XCTAssertTrue(back.label.contains("Treinos"), "Back: \(back.label)")
        back.tap()
        XCTAssertTrue(app.buttons["workouts.plan"].waitForExistence(timeout: 10), "Workout list not shown")
    }

    /// Picks `choice` (a workout's name or "Descanso") in the sheet of today's row.
    @MainActor
    private func chooseForToday(_ choice: String, in app: XCUIApplication) {
        choose(choice, inRow: element("plan.today", in: app), app: app)
    }

    /// Opens the sheet of `row`, picks `choice` (a workout's name or "Descanso") and waits until the sheet
    /// is gone.
    @MainActor
    private func choose(_ choice: String, inRow row: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Day's row not found")
        row.tap()
        let option = app.buttons[choice == "Descanso" ? "plan.option.rest" : "plan.option.\(choice)"]
        XCTAssertTrue(option.waitForExistence(timeout: 10), "'\(choice)' not in the sheet")
        option.tap()
        XCTAssertTrue(option.waitForNonExistence(timeout: 10), "Sheet not closed")
    }

    /// Today's weekday in the plan, 1 = Monday to 7 = Sunday.
    private var todayWeekday: Int {
        (Calendar(identifier: .gregorian).component(.weekday, from: .now) + 5) % 7 + 1
    }

    @MainActor
    func testPlanTodayStartAndComplete() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa Pronada"])

        // Planned for today: the row says the day, today and the workout.
        openPlan(in: app)
        chooseForToday("Push", in: app)
        XCTAssertTrue(waitForLabel(of: element("plan.today", in: app), containing: ", hoje, Push"), "Today's row: \(element("plan.today", in: app).label)")
        attachScreenshot(named: "41-weekly-plan", of: app)
        closePlan(in: app)

        // The Home offers to start it, besides choosing another workout and a free one.
        openTab("Início", in: app)
        let start = app.buttons["home.startPlanned"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "No Iniciar Push on the Home")
        XCTAssertEqual(start.label, "Iniciar Push")
        let card = element("home.today", in: app)
        XCTAssertTrue(card.label.contains("Push"), "Card: \(card.label)")
        XCTAssertTrue(card.label.contains("programado para hoje"), "Card: \(card.label)")
        XCTAssertEqual(app.buttons["home.chooseWorkout"].label, "Escolher outro treino")
        XCTAssertTrue(app.buttons["home.startFree"].exists, "No Iniciar treino livre")
        attachScreenshot(named: "42-home-planned", of: app)

        // Starting it opens a session of that workout.
        start.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
        XCTAssertEqual(element("session.name", in: app).label, "Push")
        completeFirstSetAndFinishSession(in: app)

        // Finished today: the card says so and no longer offers to start it.
        XCTAssertTrue(waitForLabel(of: card, containing: "Push concluído hoje"), "Card: \(card.label)")
        XCTAssertTrue(start.waitForNonExistence(timeout: 10), "Iniciar Push still offered")
        XCTAssertEqual(app.buttons["home.chooseWorkout"].label, "Escolher outro treino")
        XCTAssertTrue(app.buttons["home.startFree"].exists, "No Iniciar treino livre")
    }

    /// The screen of the model: the count of days, the week's goal and the seven days; a day's sheet
    /// lists "Descanso" and every workout, and a choice is saved at once.
    @MainActor
    func testPlanScreenAndDaySheet() throws {
        continueAfterFailure = false
        let other = todayWeekday == 2 ? 3 : 2
        let planned = [1, 2, 3, 4, 5, 6, 7].filter { $0 != other && $0 != todayWeekday }.prefix(2).map(String.init).joined(separator: "|")
        let app = launchOnTab("Treinos", seed: [
            "workout:Push:Supino Reto com Barra|Desenvolvimento com Halteres",
            "workout:Pull:Barra Fixa Pronada",
            "workout:Vazio",
            "plan:Push:\(planned)",
            "plan-today:Pull",
        ])
        openPlan(in: app)

        let header = element("plan.header", in: app)
        XCTAssertEqual(header.label, "3 dias de treino · 4 de descanso")
        XCTAssertTrue(element("plan.goal", in: app).label.contains("Meta da semana: 3 treinos"), element("plan.goal", in: app).label)
        let today = element("plan.today", in: app)
        XCTAssertTrue(today.label.contains(", hoje, Pull, 1 exercício · 3 séries, Costas"), "Today's row: \(today.label)")
        let row = element("plan.day.\(other)", in: app)
        XCTAssertTrue(row.label.hasSuffix(", descanso"), "Rest day: \(row.label)")
        attachScreenshot(named: "89-weekly-plan", of: app)

        // The day's sheet: its name, "Descanso" checked and every workout with what it holds.
        row.tap()
        let rest = app.buttons["plan.option.rest"]
        XCTAssertTrue(rest.waitForExistence(timeout: 10), "Day's sheet not shown")
        XCTAssertTrue(rest.isSelected, "Descanso not checked")
        XCTAssertEqual(rest.label, "Descanso, Sem treino neste dia")
        XCTAssertEqual(app.buttons["plan.option.Vazio"].label, "Vazio, Nenhum exercício ainda")
        XCTAssertFalse(app.buttons["plan.option.Pull"].isSelected)
        XCTAssertTrue(app.staticTexts["Escolha o treino deste dia. A mudança é salva na hora."].exists)
        // The sheet is as tall as its content: "Cancelar" right below the last workout.
        let gap = app.buttons["plan.sheet.cancel"].frame.minY - app.buttons["plan.option.Vazio"].frame.maxY
        XCTAssertTrue((0...40).contains(gap), "Space between the last workout and Cancelar: \(gap)")
        attachScreenshot(named: "90-plan-day-sheet", of: app)

        // Choosing saves at once and closes the sheet; the count and the goal follow.
        app.buttons["plan.option.Pull"].tap()
        XCTAssertTrue(rest.waitForNonExistence(timeout: 10), "Sheet not closed")
        XCTAssertTrue(waitForLabel(of: row, containing: ", Pull, 1 exercício · 3 séries"), "Day's row: \(row.label)")
        XCTAssertTrue(waitForLabel(of: header, toBe: "4 dias de treino · 3 de descanso"), "Header: \(header.label)")
        XCTAssertTrue(element("plan.goal", in: app).label.contains("Meta da semana: 4 treinos"))

        // "Cancelar" changes nothing.
        row.tap()
        let cancel = app.buttons["plan.sheet.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "Day's sheet not shown again")
        XCTAssertTrue(app.buttons["plan.option.Pull"].isSelected, "Pull not checked")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 10), "Sheet not closed")
        XCTAssertEqual(header.label, "4 dias de treino · 3 de descanso")
    }

    /// Without the navigation bar, a swipe from the left edge still goes back, and the tab bar returns.
    @MainActor
    func testSwipeFromTheEdgeGoesBack() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa Pronada"])
        openPlan(in: app)

        let window = app.windows.firstMatch
        let edge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        XCTAssertTrue(app.buttons["workouts.plan"].waitForExistence(timeout: 10), "The swipe did not go back to Treinos")
        XCTAssertTrue(element("plan.screen", in: app).waitForNonExistence(timeout: 10), "Plan still shown")
        XCTAssertTrue(app.tabBars.buttons["Treinos"].waitForExistence(timeout: 10), "Tab bar not shown again")
    }

    @MainActor
    func testRestDayAndDeletedWorkout() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa Pronada", "workout:Pull:Barra Fixa Pronada"])

        // Planned for today: the Home shows it at once, without reopening the app.
        openPlan(in: app)
        chooseForToday("Push", in: app)
        closePlan(in: app)
        openTab("Início", in: app)
        XCTAssertTrue(app.buttons["home.startPlanned"].waitForExistence(timeout: 10), "No Iniciar Push on the Home")
        XCTAssertEqual(app.buttons["home.startPlanned"].label, "Iniciar Push")

        // Today becomes a rest day: the Home follows at once.
        openTab("Treinos", in: app)
        openPlan(in: app)
        chooseForToday("Descanso", in: app)
        XCTAssertTrue(waitForLabel(of: element("plan.today", in: app), containing: ", hoje, descanso"), "Today's row: \(element("plan.today", in: app).label)")
        closePlan(in: app)
        openTab("Início", in: app)
        let card = element("home.today", in: app)
        XCTAssertTrue(waitForLabel(of: card, containing: "Nada programado para hoje."), "Card: \(card.label)")
        XCTAssertTrue(app.buttons["home.startPlanned"].waitForNonExistence(timeout: 10), "Iniciar Push still offered")
        XCTAssertEqual(app.buttons["home.chooseWorkout"].label, "Escolher treino")

        // Planned again, then the workout is deleted: its day becomes a rest day.
        openTab("Treinos", in: app)
        openPlan(in: app)
        chooseForToday("Push", in: app)
        closePlan(in: app)
        openWorkout(named: "Push", in: app)
        deleteWorkoutFromEditor(in: app)
        XCTAssertTrue(element("workout.title", in: app).waitForNonExistence(timeout: 10), "Editor still open after deleting")

        openPlan(in: app)
        XCTAssertTrue(waitForLabel(of: element("plan.today", in: app), containing: ", hoje, descanso"), "Today's row: \(element("plan.today", in: app).label)")
        closePlan(in: app)
        openTab("Início", in: app)
        XCTAssertTrue(waitForLabel(of: card, containing: "Nada programado para hoje."), "Card: \(card.label)")
        XCTAssertFalse(app.buttons["home.startPlanned"].exists, "Iniciar Push offered after deleting the workout")
    }
}
