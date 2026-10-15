import XCTest

/// The history detail: a finished session opens a read-only record that keeps its original name
/// and values after the planned workout is deleted. Runs on an in-memory store with the built-in library.
final class HistoryUITests: XCTestCase {
    @MainActor
    private func launchOnWorkoutsTab() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
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
        XCTAssertTrue(app.buttons["workouts.start"].waitForExistence(timeout: 10), "Workout list not shown")
    }

    @MainActor
    private func attachScreenshot(named name: String, of app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testFinishedSessionDetailAfterItsWorkoutIsDeleted() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)

        // A session with two sets done and one not done.
        app.buttons["workouts.start"].firstMatch.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
        let weights = app.textFields.matching(identifier: "session.set.weight")
        let reps = app.textFields.matching(identifier: "session.set.reps")
        let checks = app.buttons.matching(identifier: "session.set.check")
        XCTAssertEqual(checks.count, 3, "The session should copy the three planned sets")
        weights.element(boundBy: 0).tap()
        weights.element(boundBy: 0).typeText("20")
        reps.element(boundBy: 0).tap()
        reps.element(boundBy: 0).typeText("10")
        checks.element(boundBy: 0).tap()
        XCTAssertTrue(checks.element(boundBy: 0).isSelected, "First set not checked")
        // Empty repetitions take the target (8–12 → 12).
        checks.element(boundBy: 1).tap()
        XCTAssertTrue(checks.element(boundBy: 1).isSelected, "Second set not checked")

        app.buttons["session.finish"].tap()
        let confirmFinish = app.buttons["Concluir treino"]
        XCTAssertTrue(confirmFinish.waitForExistence(timeout: 10), "Finish confirmation not shown")
        confirmFinish.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")

        // The planned workout is deleted; the session it came from stays in the history.
        app.buttons["workouts.card"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Push"].waitForExistence(timeout: 10), "Workout editor not opened")
        app.buttons["workout.menu"].tap()
        let delete = app.buttons["Excluir treino"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "Delete option not found")
        delete.tap()
        let confirmDelete = app.buttons["Excluir"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 10), "Delete confirmation not shown")
        confirmDelete.tap()
        XCTAssertTrue(element("workouts.empty", in: app).waitForExistence(timeout: 10), "Workout not deleted")

        openTab("Histórico", in: app)
        let card = element("history.session", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Finished session not in the history")
        XCTAssertTrue(card.label.contains("Push"), "History: \(card.label)")
        XCTAssertTrue(card.label.contains("1 exercício · 2 séries"), "History: \(card.label)")
        card.tap()

        // The record: the original name, the exercise, and every set with its values and state.
        let detail = element("history.detail", in: app)
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "Session detail not opened")
        XCTAssertTrue(app.navigationBars["Push"].exists, "The detail does not show the session's name")
        let exercises = detail.descendants(matching: .any).matching(identifier: "history.detail.exercise")
        XCTAssertEqual(exercises.count, 1)
        XCTAssertTrue(exercises.element(boundBy: 0).staticTexts["Barra Fixa"].exists, "Exercise name not shown")
        let sets = detail.descendants(matching: .any).matching(identifier: "history.detail.set")
        XCTAssertEqual(sets.count, 3)
        XCTAssertEqual(sets.element(boundBy: 0).label, "Série 1, Meta: 8–12, Carga: 20 kg, 10 repetições, Concluída")
        XCTAssertEqual(sets.element(boundBy: 1).label, "Série 2, Meta: 8–12, Sem carga, 12 repetições, Concluída")
        XCTAssertEqual(sets.element(boundBy: 2).label, "Série 3, Meta: 8–12, Sem carga, Sem repetições, Não concluída")
        // Read-only: nothing to type in and no action to take.
        XCTAssertEqual(detail.textFields.count, 0, "The detail has editable fields")
        XCTAssertEqual(detail.buttons.count, 0, "The detail has action buttons")
        attachScreenshot(named: "37-history-detail", of: app)

        // Back to the list, which still opens the detail.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(detail.waitForNonExistence(timeout: 10), "Detail still shown after going back")
        XCTAssertTrue(card.waitForExistence(timeout: 10), "History list not shown after going back")
        card.tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "Session detail not opened again")
    }
}
