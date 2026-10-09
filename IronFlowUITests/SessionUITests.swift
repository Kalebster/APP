import XCTest

/// The session in progress: starting from a workout, checking sets, minimizing and continuing from
/// the "Treino em andamento" bar, finishing (then the history) and discarding.
/// Runs on an in-memory store with the built-in library.
final class SessionUITests: XCTestCase {
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
        search.tap()
        search.typeText(exercise)
        let row = app.buttons[exercise]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Exercise '\(exercise)' not found in the picker")
        row.tap()
        app.buttons["picker.add"].tap()
        XCTAssertTrue(element("workout.exercise", in: app).waitForExistence(timeout: 10), "Exercise not added")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["workouts.start"].waitForExistence(timeout: 10), "Workout list not shown")
    }

    /// Starts the first workout of the list and waits for the session screen.
    @MainActor
    private func startFirstWorkout(in app: XCUIApplication) {
        app.buttons["workouts.start"].firstMatch.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
    }

    @MainActor
    private func checks(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "session.set.check")
    }

    @MainActor
    private func repsFields(in app: XCUIApplication) -> XCUIElementQuery {
        app.textFields.matching(identifier: "session.set.reps")
    }

    @MainActor
    private func attachScreenshot(named name: String, of app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testStartCheckMinimizeContinueAndFinish() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)
        startFirstWorkout(in: app)

        XCTAssertEqual(element("session.name", in: app).label, "Push")
        XCTAssertEqual(checks(in: app).count, 3, "The session should copy the three planned sets")

        // Empty repetitions take the target (8–12 → 12): the set is checked here, and its stored
        // repetitions are proven after the session is opened again (below).
        checks(in: app).element(boundBy: 0).tap()
        XCTAssertTrue(checks(in: app).element(boundBy: 0).isSelected, "First set not checked")

        // Typed repetitions are recorded.
        repsFields(in: app).element(boundBy: 1).tap()
        repsFields(in: app).element(boundBy: 1).typeText("10")
        checks(in: app).element(boundBy: 1).tap()
        XCTAssertEqual(repsFields(in: app).element(boundBy: 1).value as? String, "10")
        XCTAssertTrue(checks(in: app).element(boundBy: 1).isSelected, "Second set not checked")

        // A set added during the session copies the last one.
        app.buttons["session.addSet"].tap()
        XCTAssertTrue(checks(in: app).element(boundBy: 3).waitForExistence(timeout: 10), "Set not added")
        attachScreenshot(named: "25-session", of: app)

        // Minimized, the bar is shown on the other tabs and opens the session again; the Home
        // offers "Continuar" in its card instead of the bar.
        app.buttons["session.minimize"].tap()
        let bar = app.buttons["session.bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Session bar not shown")
        attachScreenshot(named: "26-session-bar", of: app)
        openTab("Início", in: app)
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 10), "No Continuar on the Home")
        XCTAssertFalse(bar.exists, "Session bar shown on the Home")
        openTab("Exercícios", in: app)
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Session bar not shown on Exercícios")
        bar.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session not opened from the bar")
        XCTAssertTrue(checks(in: app).element(boundBy: 0).isSelected, "Checked set lost after minimizing")

        // The session screen was created again, so the field shows the stored repetitions. Its
        // empty hint is also "12", so the value alone proves nothing: typing one digit must give
        // three characters (1, 2 and 3, wherever the caret is), which only happens when the field
        // really holds "12"; an empty field would show "3". The digit is then deleted again.
        let firstReps = repsFields(in: app).element(boundBy: 0)
        firstReps.tap()
        firstReps.typeText("3")
        let typed = try XCTUnwrap(firstReps.value as? String)
        XCTAssertEqual(typed.count, 3, "The checked set does not hold 12 repetitions: \(typed)")
        XCTAssertEqual(Set(typed), ["1", "2", "3"], "The checked set does not hold 12 repetitions: \(typed)")
        firstReps.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual(firstReps.value as? String, "12")

        // Finishing with sets not done asks first; they stay recorded as not done.
        app.buttons["session.finish"].tap()
        let confirm = app.buttons["Concluir treino"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Finish confirmation not shown")
        confirm.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
        XCTAssertTrue(bar.waitForNonExistence(timeout: 10), "Session bar still shown after finishing")

        openTab("Histórico", in: app)
        let finished = element("history.session", in: app)
        XCTAssertTrue(finished.waitForExistence(timeout: 10), "Finished session not in the history")
        XCTAssertTrue(finished.label.contains("Push"), "History: \(finished.label)")
        XCTAssertTrue(finished.label.contains("1 exercício · 2 séries"), "History: \(finished.label)")
        attachScreenshot(named: "27-history", of: app)
    }

    @MainActor
    func testFinishNeedsACompletedSetAndDiscardKeepsThePlan() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Pull", exercise: "Barra Fixa", in: app)
        startFirstWorkout(in: app)

        app.buttons["session.finish"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "No message when finishing without sets")
        XCTAssertTrue(alert.staticTexts["Conclua pelo menos uma série ou descarte o treino."].exists)
        alert.buttons["OK"].tap()

        app.buttons["session.discard"].tap()
        let discard = app.buttons["Descartar"]
        XCTAssertTrue(discard.waitForExistence(timeout: 10), "Discard confirmation not shown")
        discard.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
        XCTAssertFalse(app.buttons["session.bar"].exists, "Session bar still shown after discarding")

        // The planned workout is kept; nothing reaches the history.
        XCTAssertTrue(app.buttons["workouts.start"].waitForExistence(timeout: 10), "Workout lost after discarding")
        openTab("Histórico", in: app)
        XCTAssertTrue(element("history.empty", in: app).waitForExistence(timeout: 10), "Discarded session in the history")
    }

    @MainActor
    func testSecondStartOffersTheCurrentSession() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Legs", exercise: "Barra Fixa", in: app)
        startFirstWorkout(in: app)
        app.buttons["session.minimize"].tap()
        XCTAssertTrue(app.buttons["session.bar"].waitForExistence(timeout: 10), "Session bar not shown")

        app.buttons["workouts.start"].firstMatch.tap()
        let resume = app.buttons["Continuar treino atual"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "No notice about the session in progress")
        resume.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Current session not opened")
        XCTAssertEqual(element("session.name", in: app).label, "Legs")
    }

    @MainActor
    func testDarkAppearance() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab(extraArguments: ["-ui-dark-appearance"])
        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)
        startFirstWorkout(in: app)
        checks(in: app).element(boundBy: 0).tap()
        attachScreenshot(named: "28-session-dark", of: app)

        app.buttons["session.minimize"].tap()
        XCTAssertTrue(app.buttons["session.bar"].waitForExistence(timeout: 10), "Session bar not shown")
        attachScreenshot(named: "29-session-bar-dark", of: app)
    }
}
