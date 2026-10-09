import XCTest

/// The Workouts tab: creating, opening, renaming and deleting planned workouts, and adding,
/// removing and reordering their exercises. Runs on an in-memory store with the built-in library.
final class WorkoutUITests: XCTestCase {
    @MainActor
    private func launchOnWorkoutsTab(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extraArguments
        app.launch()
        let tab = app.tabBars.buttons["Treinos"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Workouts tab not found")
        tab.tap()
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Any element whose accessibility label starts with `prefix`.
    @MainActor
    private func element(labelStartingWith prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// The exercise rows of the open workout, top to bottom.
    @MainActor
    private func exerciseRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "workout.exercise")
    }

    /// Creates a workout from the list and waits for its editor.
    @MainActor
    private func createWorkout(named name: String, in app: XCUIApplication) {
        let add = app.buttons["workouts.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Add workout button not found")
        add.tap()
        let field = app.textFields["workout.name.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Name field not found")
        field.tap()
        field.typeText(name)
        app.buttons["workout.name.save"].tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 10), "Editor of '\(name)' did not open")
    }

    /// Adds exercises through the picker, choosing each one by searching its exact name.
    @MainActor
    private func addExercises(_ names: [String], in app: XCUIApplication) {
        let add = app.buttons["workout.addExercises"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Add exercises button not found")
        add.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "Picker search field not found")
        for name in names {
            // The search field's clear button (shown while editing) empties it wherever the tap
            // left the cursor.
            search.tapAndWaitForKeyboardFocus()
            let clear = search.buttons.firstMatch
            if clear.exists {
                clear.tap()
            }
            search.typeText(name)
            let row = app.buttons[name]
            XCTAssertTrue(row.waitForExistence(timeout: 10), "Exercise '\(name)' not found in the picker")
            row.tap()
        }
        let confirm = app.buttons["picker.add"]
        XCTAssertTrue(confirm.isEnabled, "Add button disabled after selecting exercises")
        confirm.tap()
        XCTAssertTrue(exerciseRows(in: app).firstMatch.waitForExistence(timeout: 10), "Exercises not added")
    }

    /// Cancels the confirmation dialog whose confirm button is `confirmLabel`. Depending on the
    /// system layout the dialog has a "Cancelar" button or is dismissed by tapping outside it.
    @MainActor
    private func cancelDialog(confirmLabel: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[confirmLabel].waitForExistence(timeout: 10), "Confirmation '\(confirmLabel)' not shown")
        let cancel = app.buttons["Cancelar"]
        if cancel.exists {
            cancel.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        XCTAssertTrue(app.buttons[confirmLabel].waitForNonExistence(timeout: 10), "Confirmation not dismissed")
    }

    /// Opens the planned sets of the exercise at `index` in the open workout.
    @MainActor
    private func openExercise(at index: Int, in app: XCUIApplication) {
        exerciseRows(in: app).element(boundBy: index).tap()
        XCTAssertTrue(app.buttons["exercise.addSet"].waitForExistence(timeout: 10), "Planned sets not shown")
    }

    /// The planned set rows of the open exercise, top to bottom.
    @MainActor
    private func setRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "exercise.set")
    }

    /// Replaces the whole number in a field. Selecting it with a double tap does not depend on
    /// where the cursor lands; what is typed then replaces the selection.
    @MainActor
    private func replaceText(of field: XCUIElement, with text: String) {
        field.tap()
        // An empty field reports its placeholder as its value.
        let isEmpty = (field.value as? String) == field.placeholderValue
        if !isEmpty {
            field.doubleTap()
        }
        field.typeText(text.isEmpty ? XCUIKeyboardKey.delete.rawValue : text)
        let expected = text.isEmpty ? field.placeholderValue : text
        XCTAssertEqual(field.value as? String, expected, "Field text not replaced")
    }

    /// Waits until the query has `expected` elements, so row animations do not race the check.
    @MainActor
    private func waitForCount(_ query: XCUIElementQuery, _ expected: Int) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while query.count != expected && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return query.count == expected
    }

    /// Opens the set at `index`, types its values and saves.
    @MainActor
    private func editSet(at index: Int, min: String, max: String, weight: String, in app: XCUIApplication) {
        setRows(in: app).element(boundBy: index).tap()
        let minField = app.textFields["set.editor.min"]
        XCTAssertTrue(minField.waitForExistence(timeout: 10), "Set editor not shown")
        replaceText(of: minField, with: min)
        replaceText(of: app.textFields["set.editor.max"], with: max)
        replaceText(of: app.textFields["set.editor.weight"], with: weight)
        let save = app.buttons["set.editor.save"]
        XCTAssertTrue(save.isEnabled, "Save disabled with valid values")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10), "Set editor not closed")
    }

    /// Swipes the row to reveal "Remover" and taps it. A swipe made while the list is still
    /// animating may not open the row, so it is repeated once when the button does not appear.
    @MainActor
    private func swipeAndTapRemove(_ row: XCUIElement, in app: XCUIApplication) {
        let remove = app.buttons["Remover"].firstMatch
        row.swipeLeft()
        if !remove.waitForExistence(timeout: 3) {
            row.swipeLeft()
        }
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "\"Remover\" not revealed by the swipe")
        remove.tap()
    }

    @MainActor
    private func attachScreenshot(named name: String, of app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testEmptyStateAndCreateWorkout() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()

        XCTAssertTrue(element("workouts.empty", in: app).waitForExistence(timeout: 10), "Empty state not shown")
        attachScreenshot(named: "11-workouts-empty", of: app)

        app.buttons["workouts.empty.create"].tap()
        let field = app.textFields["workout.name.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Name field not found")
        let save = app.buttons["workout.name.save"]
        XCTAssertFalse(save.isEnabled, "Save enabled with an empty name")
        field.tap()
        field.typeText("   ")
        XCTAssertFalse(save.isEnabled, "Save enabled with a blank name")
        field.typeText("Push")
        XCTAssertTrue(save.isEnabled, "Save disabled with a valid name")
        XCTAssertEqual(field.value as? String, "   Push", "Typed name")
        save.tap()

        // Saving closes the name sheet; the new workout's editor opens once the sheet has closed.
        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "Name sheet did not close after saving")
        XCTAssertTrue(app.navigationBars["Push"].waitForExistence(timeout: 10), "Editor did not open after creating")
        XCTAssertTrue(element("workout.empty", in: app).exists, "Editor empty state not shown")
        attachScreenshot(named: "12-workout-editor-empty", of: app)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let card = app.buttons["workouts.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Workout card not shown")
        XCTAssertTrue(card.label.contains("Push"), "Unexpected card label: \(card.label)")
        XCTAssertTrue(card.label.contains("Nenhum exercício"), "Unexpected card label: \(card.label)")

        card.tap()
        XCTAssertTrue(app.navigationBars["Push"].waitForExistence(timeout: 10), "Editor did not open from the card")
    }

    @MainActor
    func testAddExercisesInOrderAndShowInWorkout() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", in: app)

        addExercises(["Crossover na Polia", "Barra Fixa"], in: app)

        let rows = exerciseRows(in: app)
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("Crossover na Polia"), "First row: \(rows.element(boundBy: 0).label)")
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("Barra Fixa"), "Second row: \(rows.element(boundBy: 1).label)")
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("3 séries"), "Default sets missing: \(rows.element(boundBy: 0).label)")
        attachScreenshot(named: "13-workout-editor", of: app)

        app.buttons["workout.addExercises"].tap()
        let inWorkout = element(labelStartingWith: "Crossover na Polia", in: app)
        XCTAssertTrue(inWorkout.waitForExistence(timeout: 10), "Exercise not found in the picker")
        XCTAssertTrue(inWorkout.label.contains("No treino"), "Missing 'No treino': \(inWorkout.label)")
        XCTAssertFalse(inWorkout.isEnabled, "An exercise already in the workout can be selected")
        XCTAssertFalse(app.buttons["picker.add"].isEnabled, "Add button enabled without a selection")
        attachScreenshot(named: "14-exercise-picker", of: app)

        app.buttons["picker.cancel"].tap()
        XCTAssertTrue(app.buttons["picker.add"].waitForNonExistence(timeout: 10), "Picker not closed")
        XCTAssertEqual(exerciseRows(in: app).count, 2)

        let reorder = app.buttons["workout.reorder"]
        XCTAssertTrue(reorder.waitForExistence(timeout: 10), "Reorder button not found")
        reorder.tap()
        XCTAssertTrue(reorder.label.contains("Concluir"), "Reorder mode not entered: \(reorder.label)")
        reorder.tap()
        XCTAssertTrue(reorder.label.contains("Ordenar"), "Reorder mode not left: \(reorder.label)")
    }

    /// A double tap on "Adicionar (N)" adds the exercises once, closes the picker and shows no error.
    /// The service also rejects adding the same exercises again, so this checks what the user sees,
    /// whichever layer stops the second tap (the picker ignores it; the service would reject it).
    @MainActor
    func testDoubleTapOnAddAddsExercisesOnce() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", in: app)

        app.buttons["workout.addExercises"].tap()
        // The first exercises of the library are visible without searching.
        for name in ["Crossover na Polia", "Crucifixo com Halteres"] {
            let row = app.buttons[name]
            XCTAssertTrue(row.waitForExistence(timeout: 10), "Exercise '\(name)' not found in the picker")
            row.tap()
        }
        let confirm = app.buttons["picker.add"]
        XCTAssertTrue(confirm.isEnabled, "Add button disabled after selecting exercises")
        confirm.doubleTap()

        XCTAssertTrue(confirm.waitForNonExistence(timeout: 10), "Picker not closed after adding")
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 3), "An error alert appeared after a double tap")
        let rows = exerciseRows(in: app)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "Exercises not added")
        XCTAssertEqual(rows.count, 2, "Exercises added more than once")
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("Crossover na Polia"), "First row: \(rows.element(boundBy: 0).label)")
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("Crucifixo com Halteres"), "Second row: \(rows.element(boundBy: 1).label)")
    }

    @MainActor
    func testRemoveExerciseCancelAndConfirm() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", in: app)
        addExercises(["Crossover na Polia", "Barra Fixa"], in: app)
        let rows = exerciseRows(in: app)

        swipeAndTapRemove(rows.element(boundBy: 0), in: app)
        cancelDialog(confirmLabel: "Remover exercício", in: app)
        XCTAssertEqual(rows.count, 2, "Cancel removed the exercise")

        swipeAndTapRemove(rows.element(boundBy: 0), in: app)
        let confirm = app.buttons["Remover exercício"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Removal confirmation not shown")
        confirm.tap()

        let remaining = rows.element(boundBy: 0)
        XCTAssertTrue(remaining.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(remaining.label.contains("Barra Fixa"), "Wrong exercise removed: \(remaining.label)")
        XCTAssertTrue(remaining.label.hasPrefix("1"), "Remaining exercise not renumbered: \(remaining.label)")
    }

    @MainActor
    func testRenameWorkout() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", in: app)

        app.buttons["workout.menu"].tap()
        let rename = app.buttons["Renomear"]
        XCTAssertTrue(rename.waitForExistence(timeout: 10), "Rename option not found")
        rename.tap()
        let field = app.textFields["workout.name.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Name field not found")
        XCTAssertEqual(field.value as? String, "Push")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Push".count))
        XCTAssertFalse(app.buttons["workout.name.save"].isEnabled, "Save enabled with an empty name")
        field.typeText("Peito e Tríceps")
        app.buttons["workout.name.save"].tap()

        XCTAssertTrue(app.navigationBars["Peito e Tríceps"].waitForExistence(timeout: 10), "Title not renamed")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let card = app.buttons["workouts.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(card.label.contains("Peito e Tríceps"), "Card not renamed: \(card.label)")
    }

    @MainActor
    func testDeleteWorkoutCancelAndConfirm() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", in: app)

        app.buttons["workout.menu"].tap()
        let delete = app.buttons["Excluir treino"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "Delete option not found")
        delete.tap()
        XCTAssertTrue(element(labelStartingWith: "Excluir “Push”", in: app).waitForExistence(timeout: 10), "Delete confirmation not shown")
        attachScreenshot(named: "15-workout-delete-confirmation", of: app)
        cancelDialog(confirmLabel: "Excluir", in: app)
        XCTAssertTrue(app.navigationBars["Push"].waitForExistence(timeout: 10), "Cancel left the editor")

        app.buttons["workout.menu"].tap()
        XCTAssertTrue(app.buttons["Excluir treino"].waitForExistence(timeout: 10))
        app.buttons["Excluir treino"].tap()
        let confirm = app.buttons["Excluir"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Delete confirmation not shown")
        confirm.tap()

        XCTAssertTrue(element("workouts.empty", in: app).waitForExistence(timeout: 10), "List not shown empty after deleting")
        XCTAssertFalse(app.buttons["workouts.card"].exists, "Deleted workout still listed")
    }

    @MainActor
    func testEditPlannedSet() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", in: app)
        addExercises(["Crossover na Polia"], in: app)
        openExercise(at: 0, in: app)

        let sets = setRows(in: app)
        XCTAssertEqual(sets.count, 3)
        let first = sets.element(boundBy: 0)
        XCTAssertTrue(first.label.contains("Série 1"), "First set: \(first.label)")
        XCTAssertTrue(first.label.contains("8–12 reps"), "First set: \(first.label)")
        XCTAssertTrue(first.label.contains("Sem carga"), "First set: \(first.label)")
        attachScreenshot(named: "18-workout-exercise", of: app)

        first.tap()
        let minField = app.textFields["set.editor.min"]
        let maxField = app.textFields["set.editor.max"]
        XCTAssertTrue(minField.waitForExistence(timeout: 10), "Set editor not shown")
        XCTAssertEqual(minField.value as? String, "8")
        XCTAssertEqual(maxField.value as? String, "12")
        replaceText(of: minField, with: "12")
        replaceText(of: maxField, with: "10")
        let save = app.buttons["set.editor.save"]
        XCTAssertFalse(save.isEnabled, "Save enabled with the minimum above the maximum")
        XCTAssertTrue(element("set.editor.error", in: app).exists, "Error not shown")

        replaceText(of: maxField, with: "15")
        replaceText(of: app.textFields["set.editor.weight"], with: "80")
        XCTAssertTrue(save.isEnabled, "Save disabled with valid values")
        XCTAssertFalse(element("set.editor.error", in: app).exists, "Error still shown")
        attachScreenshot(named: "19-set-editor", of: app)
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10), "Set editor not closed")
        XCTAssertTrue(first.label.contains("12–15 reps"), "Edited set: \(first.label)")
        XCTAssertTrue(first.label.contains("80 kg"), "Edited set: \(first.label)")

        // Clearing the load removes it.
        editSet(at: 0, min: "12", max: "15", weight: "", in: app)
        XCTAssertTrue(first.label.contains("Sem carga"), "Load not removed: \(first.label)")
        XCTAssertTrue(sets.element(boundBy: 1).label.contains("8–12 reps"), "Another set changed")
    }

    @MainActor
    func testAddAndRemovePlannedSets() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", in: app)
        addExercises(["Crossover na Polia"], in: app)
        openExercise(at: 0, in: app)
        let sets = setRows(in: app)

        // A new set copies the last one.
        editSet(at: 2, min: "6", max: "8", weight: "40", in: app)
        app.buttons["exercise.addSet"].tap()
        XCTAssertTrue(waitForCount(sets, 4), "Set not added")
        let added = sets.element(boundBy: 3)
        XCTAssertTrue(added.label.contains("Série 4"), "Added set: \(added.label)")
        XCTAssertTrue(added.label.contains("6–8 reps"), "Added set: \(added.label)")
        XCTAssertTrue(added.label.contains("40 kg"), "Added set: \(added.label)")

        // Removing the second set renumbers the others.
        swipeAndTapRemove(sets.element(boundBy: 1), in: app)
        XCTAssertTrue(waitForCount(sets, 3), "Set not removed")
        XCTAssertTrue(sets.element(boundBy: 1).label.contains("Série 2"), "Second set: \(sets.element(boundBy: 1).label)")
        XCTAssertTrue(sets.element(boundBy: 1).label.contains("6–8 reps"), "Second set: \(sets.element(boundBy: 1).label)")

        // The last set cannot be removed.
        for expected in [2, 1] {
            swipeAndTapRemove(sets.element(boundBy: 0), in: app)
            XCTAssertTrue(waitForCount(sets, expected), "Set not removed")
        }
        XCTAssertTrue(element("exercise.lastSetHint", in: app).waitForExistence(timeout: 10), "Last set hint not shown")
        sets.element(boundBy: 0).swipeLeft()
        XCTAssertFalse(app.buttons["Remover"].exists, "The last set can be removed")
        XCTAssertEqual(sets.count, 1)

        // The workout shows the new number of sets. The first tap may only end the swipe.
        let back = app.navigationBars.buttons.element(boundBy: 0)
        back.tap()
        let row = exerciseRows(in: app).element(boundBy: 0)
        if !row.waitForExistence(timeout: 3) {
            back.tap()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Workout not shown")
        XCTAssertTrue(row.label.contains("1 série"), "Exercise row: \(row.label)")
    }

    @MainActor
    func testDarkAppearance() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab(extraArguments: ["-ui-dark-appearance"])
        createWorkout(named: "Push", in: app)
        addExercises(["Crossover na Polia", "Barra Fixa"], in: app)
        attachScreenshot(named: "16-workout-editor-dark", of: app)

        openExercise(at: 0, in: app)
        attachScreenshot(named: "20-workout-exercise-dark", of: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(exerciseRows(in: app).firstMatch.waitForExistence(timeout: 10), "Workout not shown")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["workouts.card"].waitForExistence(timeout: 10))
        attachScreenshot(named: "17-workouts-dark", of: app)
    }
}
