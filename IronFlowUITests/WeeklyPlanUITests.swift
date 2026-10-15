import XCTest

/// The weekly plan: planning a workout for today, the Home card that follows the plan, a rest day and a
/// planned workout that is deleted. Works on any day of the week: the tests only use today's row.
/// Runs on an in-memory store with the built-in library.
final class WeeklyPlanUITests: XCTestCase {
    @MainActor
    private func launchOnWorkoutsTab(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extraArguments
        app.launch()
        openTab("Treinos", in: app)
        return app
    }

    @MainActor
    private func openTab(_ label: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Tab '\(label)' not found")
        tab.tap()
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Creates a workout with one exercise (three planned sets of 8–12, no load) and goes back to the list.
    @MainActor
    private func createWorkout(named name: String, exercise: String, in app: XCUIApplication) {
        let add = app.buttons["workouts.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Add workout button not found")
        add.tap()
        let field = app.textFields["workout.name.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Name field not found")
        field.tap()
        field.typeText(name)
        app.buttons["workout.name.save"].tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 10), "Editor of '\(name)' did not open")

        app.buttons["workout.addExercises"].firstMatch.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "Picker search field not found")
        search.tapAndWaitForKeyboardFocus()
        search.typeText(exercise)
        let row = app.buttons[exercise]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Exercise '\(exercise)' not found in the picker")
        row.tap()
        app.buttons["picker.add"].tap()
        XCTAssertTrue(element("workout.exercise", in: app).waitForExistence(timeout: 10), "Exercise not added")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["workouts.start"].firstMatch.waitForExistence(timeout: 10), "Workout list not shown")
    }

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
    private func waitForLabel(of element: XCUIElement, containing text: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }

    @MainActor
    private func attachScreenshot(named name: String, of app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testPlanTodayStartAndComplete() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)

        // Planned for today: the row says the day, today and the workout.
        openPlan(in: app)
        chooseForToday("Push", in: app)
        XCTAssertTrue(waitForLabel(of: element("plan.today", in: app), containing: ", hoje, Push"), "Today's row: \(element("plan.today", in: app).label)")
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

        // Starting it opens a session of that workout.
        start.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
        XCTAssertEqual(element("session.name", in: app).label, "Push")
        app.buttons.matching(identifier: "session.set.check").element(boundBy: 0).tap()
        app.buttons["session.finish"].tap()
        let confirm = app.buttons["Concluir treino"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Finish confirmation not shown")
        confirm.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")

        // Finished today: the card says so and no longer offers to start it.
        XCTAssertTrue(waitForLabel(of: card, containing: "Push concluído hoje"), "Card: \(card.label)")
        XCTAssertTrue(start.waitForNonExistence(timeout: 10), "Iniciar Push still offered")
        XCTAssertEqual(app.buttons["home.chooseWorkout"].label, "Escolher outro treino")
        XCTAssertTrue(app.buttons["home.startFree"].exists, "No Iniciar treino livre")
    }

    @MainActor
    func testRestDayAndDeletedWorkout() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)
        createWorkout(named: "Pull", exercise: "Barra Fixa", in: app)

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
        app.buttons["workouts.card"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Push"].waitForExistence(timeout: 10), "Editor of 'Push' not opened")
        app.buttons["workout.menu"].tap()
        let delete = app.buttons["Excluir treino"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "Delete option not found")
        delete.tap()
        let confirmDelete = app.buttons["Excluir"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 10), "Delete confirmation not shown")
        confirmDelete.tap()
        XCTAssertTrue(app.navigationBars["Push"].waitForNonExistence(timeout: 10), "Editor still open after deleting")

        openPlan(in: app)
        XCTAssertTrue(waitForLabel(of: element("plan.today", in: app), containing: ", hoje, descanso"), "Today's row: \(element("plan.today", in: app).label)")
        closePlan(in: app)
        openTab("Início", in: app)
        XCTAssertTrue(waitForLabel(of: card, containing: "Nenhum treino planejado para hoje."), "Card: \(card.label)")
        XCTAssertFalse(app.buttons["home.startPlanned"].exists, "Iniciar Push offered after deleting the workout")
    }

    @MainActor
    func testDarkAppearance() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab(extraArguments: ["-ui-dark-appearance"])
        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)

        openPlan(in: app)
        chooseForToday("Push", in: app)
        XCTAssertTrue(waitForLabel(of: element("plan.today", in: app), containing: ", hoje, Push"), "Today's row: \(element("plan.today", in: app).label)")
        attachScreenshot(named: "41-weekly-plan-dark", of: app)
        closePlan(in: app)

        openTab("Início", in: app)
        XCTAssertTrue(app.buttons["home.startPlanned"].waitForExistence(timeout: 10), "No Iniciar Push on the Home")
        attachScreenshot(named: "42-home-planned-dark", of: app)
    }
}
