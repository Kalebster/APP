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
    }

    /// Goes back from the plan to the Treinos list.
    @MainActor
    private func closePlan(in app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["workouts.plan"].waitForExistence(timeout: 10), "Workout list not shown")
    }

    /// Picks `choice` (a workout's name or "Descanso") in the menu of today's row.
    @MainActor
    private func chooseForToday(_ choice: String, in app: XCUIApplication) {
        let today = element("plan.today", in: app)
        XCTAssertTrue(today.waitForExistence(timeout: 10), "Today's row not found")
        today.tap()
        let option = app.buttons[choice]
        XCTAssertTrue(option.waitForExistence(timeout: 10), "'\(choice)' not in the menu")
        option.tap()
        XCTAssertTrue(option.waitForNonExistence(timeout: 10), "Menu not closed")
    }

    @MainActor
    func testPlanTodayStartAndComplete() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa"])

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
        XCTAssertTrue(card.label.contains("Programado para hoje"), "Card: \(card.label)")
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

    @MainActor
    func testRestDayAndDeletedWorkout() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa", "workout:Pull:Barra Fixa"])

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
        XCTAssertTrue(waitForLabel(of: card, containing: "Nenhum treino planejado para hoje."), "Card: \(card.label)")
        XCTAssertTrue(app.buttons["home.startPlanned"].waitForNonExistence(timeout: 10), "Iniciar Push still offered")
        XCTAssertEqual(app.buttons["home.chooseWorkout"].label, "Escolher um treino")

        // Planned again, then the workout is deleted: its day becomes a rest day.
        openTab("Treinos", in: app)
        openPlan(in: app)
        chooseForToday("Push", in: app)
        closePlan(in: app)
        openWorkout(named: "Push", in: app)
        deleteWorkoutFromEditor(in: app)
        XCTAssertTrue(app.navigationBars["Push"].waitForNonExistence(timeout: 10), "Editor still open after deleting")

        openPlan(in: app)
        XCTAssertTrue(waitForLabel(of: element("plan.today", in: app), containing: ", hoje, descanso"), "Today's row: \(element("plan.today", in: app).label)")
        closePlan(in: app)
        openTab("Início", in: app)
        XCTAssertTrue(waitForLabel(of: card, containing: "Nenhum treino planejado para hoje."), "Card: \(card.label)")
        XCTAssertFalse(app.buttons["home.startPlanned"].exists, "Iniciar Push offered after deleting the workout")
    }
}
