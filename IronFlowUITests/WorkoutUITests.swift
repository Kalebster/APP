import XCTest

/// The workout editor in the approved model: creating a workout and its empty state, adding exercises
/// with the picker ("NO TREINO" for those already in it), editing loads and repetitions in place and
/// finding them saved after leaving, the minimum and maximum kept in order, the set types and their
/// sheet, adding and removing sets, reordering, removing an exercise, renaming, deleting, starting the
/// workout, going back with a swipe, a value that cannot be saved, and large text. Runs on an in-memory store with the built-in
/// library; most tests have their workout ready (`-ui-seed`).
final class WorkoutUITests: IronFlowUITestCase {
    /// Push with four exercises of the built-in library, like the model.
    private let push = "workout:Push:Supino Reto com Barra|Supino Inclinado com Halteres|Desenvolvimento com Halteres|Tríceps na Polia com Corda"

    /// The exercise headers of the open workout, top to bottom.
    @MainActor
    private func exerciseHeaders(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "workout.exercise")
    }

    /// The set numbers (with their types) of the open workout, top to bottom.
    @MainActor
    private func setTypes(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "workout.set.type")
    }

    @MainActor
    private func fields(_ identifier: String, in app: XCUIApplication) -> XCUIElementQuery {
        app.textFields.matching(identifier: identifier)
    }

    /// Adds exercises through the picker, choosing each one by searching its exact name.
    @MainActor
    private func addExercises(_ names: [String], in app: XCUIApplication) {
        let add = app.buttons["workout.addExercises"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Add exercises button not found")
        add.tap()
        for name in names {
            searchPicker(for: name, in: app)
            let card = pickerCard(name, in: app)
            XCTAssertTrue(card.waitForExistence(timeout: 10), "Exercise '\(name)' not found in the picker")
            card.tap()
        }
        let confirm = app.buttons["picker.add"]
        XCTAssertTrue(confirm.isEnabled, "Add button disabled after selecting exercises")
        XCTAssertEqual(confirm.label, "Adicionar (\(names.count))")
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 10), "Picker not closed")
    }

    /// Replaces the whole text of a field. The tap is on the right side of the field, past its centered
    /// text, so the cursor lands after the last character; that many deletes clear it, then `text` is typed.
    @MainActor
    private func replaceText(of field: XCUIElement, with text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 10), .completed, "Field did not get keyboard focus")
        // An empty field reports its placeholder as its value.
        let current = field.value as? String ?? ""
        let count = current == field.placeholderValue ? 0 : current.count
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count) + text)
    }

    /// Ends typing with the keyboard's OK, which saves the field.
    @MainActor
    private func tapOK(in app: XCUIApplication) {
        let ok = app.buttons["OK"]
        XCTAssertTrue(ok.waitForExistence(timeout: 10), "Keyboard OK not shown")
        ok.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Keyboard still shown")
    }

    /// Opens the set type sheet of the set at `index` and chooses `type` ("warmup", "working"...).
    @MainActor
    private func chooseType(_ type: String, forSetAt index: Int, in app: XCUIApplication) {
        setTypes(in: app).element(boundBy: index).tap()
        let option = app.buttons["setType.\(type)"]
        XCTAssertTrue(option.waitForExistence(timeout: 10), "Set type sheet not shown")
        option.tap()
        XCTAssertTrue(option.waitForNonExistence(timeout: 10), "Set type sheet not closed")
    }

    /// Removes the set at `index` with "Remover série" in its type sheet.
    @MainActor
    private func removeSet(at index: Int, in app: XCUIApplication) {
        setTypes(in: app).element(boundBy: index).tap()
        let remove = app.buttons["setType.remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 10), "Set type sheet not shown")
        remove.tap()
        XCTAssertTrue(remove.waitForNonExistence(timeout: 10), "Set type sheet not closed")
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

    /// While reordering three exercises: drags the first one by its handle below the last one, slowly
    /// and held a moment over its new place, so the list follows the drag on a busy simulator too.
    @MainActor
    private func dragFirstExerciseBelowTheLast(in app: XCUIApplication) {
        let cells = app.cells.containing(.any, identifier: "workout.ordering.exercise")
        let first = cells.element(boundBy: 0)
        let last = cells.element(boundBy: 2)
        let handle = first.buttons.firstMatch
        let start = handle.exists
            ? handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            : first.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        start.press(
            forDuration: 0.8,
            thenDragTo: last.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)),
            withVelocity: XCUIGestureVelocity(rawValue: 150),
            thenHoldForDuration: 0.6
        )
    }

    /// Opens the editor's ⋯ menu and chooses `option`.
    @MainActor
    private func chooseFromEditorMenu(_ option: String, in app: XCUIApplication) {
        app.buttons["workout.menu"].tap()
        let button = app.buttons[option]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "'\(option)' not in the menu")
        button.tap()
    }

    // MARK: - Creating and adding exercises

    @MainActor
    func testEmptyStateAndCreateWorkout() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos")

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
        field.typeText("Costas e Bíceps")
        XCTAssertTrue(save.isEnabled, "Save disabled with a valid name")
        save.tap()

        // Saving closes the name sheet; the new workout's editor opens once the sheet has closed, with only
        // the empty card: no legend, no dashed button, no "Iniciar".
        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "Name sheet did not close after saving")
        waitForEditor(of: "Costas e Bíceps", in: app)
        XCTAssertTrue(element("workout.empty", in: app).exists, "Empty card not shown")
        XCTAssertEqual(element("workout.summary", in: app).label, "Nenhum exercício ainda")
        XCTAssertFalse(element("workout.legend", in: app).exists, "Legend shown without exercises")
        XCTAssertFalse(app.buttons["workout.start"].exists, "Iniciar shown without exercises")
        XCTAssertEqual(app.buttons.matching(identifier: "workout.addExercises").count, 1, "More than the empty card's button")
        attachScreenshot(named: "79-workout-new", of: app)

        goBackFromEditor(in: app)
        let card = app.buttons["workouts.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Workout card not shown")
        XCTAssertTrue(card.label.contains("Costas e Bíceps"), "Unexpected card label: \(card.label)")
        XCTAssertTrue(card.label.contains("Nenhum exercício"), "Unexpected card label: \(card.label)")

        card.tap()
        waitForEditor(of: "Costas e Bíceps", in: app)
    }

    /// Several exercises enter in the order they were chosen, each with 3 sets; those already in the
    /// workout show "NO TREINO" and cannot be chosen.
    @MainActor
    func testAddSeveralExercisesInOrder() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos")
        createWorkout(named: "Push", in: app)

        addExercises(["Crossover na Polia Alta", "Barra Fixa Pronada"], in: app)
        let headers = exerciseHeaders(in: app)
        XCTAssertTrue(headers.firstMatch.waitForExistence(timeout: 10), "Exercises not added")
        XCTAssertEqual(headers.count, 2)
        XCTAssertTrue(headers.element(boundBy: 0).label.hasPrefix("Crossover na Polia Alta,"), "First: \(headers.element(boundBy: 0).label)")
        XCTAssertTrue(headers.element(boundBy: 1).label.hasPrefix("Barra Fixa Pronada,"), "Second: \(headers.element(boundBy: 1).label)")
        XCTAssertTrue(headers.element(boundBy: 0).label.hasSuffix("3 séries"), "Default sets missing: \(headers.element(boundBy: 0).label)")
        XCTAssertEqual(element("workout.summary", in: app).label, "2 exercícios · 6 séries")

        // The picker again, from the dashed button: the chest exercises, the one already in the workout
        // at half opacity with "NO TREINO", two more chosen.
        scrollToBottom(in: app)
        app.buttons["workout.addExercises"].tap()
        let chest = app.buttons["picker.filter.chest"]
        XCTAssertTrue(chest.waitForExistence(timeout: 10), "Chest filter not shown")
        chest.tap()
        let inWorkout = pickerCard("Crossover na Polia Alta", in: app)
        XCTAssertTrue(inWorkout.waitForExistence(timeout: 10), "Exercise not found in the picker")
        XCTAssertTrue(inWorkout.label.hasSuffix("Já está no treino"), "Missing 'NO TREINO': \(inWorkout.label)")
        XCTAssertFalse(inWorkout.isEnabled, "An exercise already in the workout can be chosen")
        let add = app.buttons["picker.add"]
        XCTAssertFalse(add.isEnabled, "Add button enabled without a selection")
        inWorkout.tap()
        XCTAssertFalse(add.isEnabled, "An exercise already in the workout was chosen")
        for name in ["Crossover na Polia Média", "Crossover na Polia Baixa"] {
            let card = pickerCard(name, in: app)
            XCTAssertTrue(card.waitForExistence(timeout: 10), "'\(name)' not found in the picker")
            card.tap()
            XCTAssertTrue(card.isSelected, "'\(name)' not shown as chosen")
        }
        XCTAssertEqual(add.label, "Adicionar (2)")
        attachScreenshot(named: "77-exercise-picker", of: app)

        // Cancelling adds nothing.
        app.buttons["picker.cancel"].tap()
        XCTAssertTrue(add.waitForNonExistence(timeout: 10), "Picker not closed")
        XCTAssertEqual(element("workout.summary", in: app).label, "2 exercícios · 6 séries")

        // Added in the order they were chosen.
        addExercises(["Crossover na Polia Média", "Crossover na Polia Baixa"], in: app)
        XCTAssertTrue(waitForLabel(of: element("workout.summary", in: app), toBe: "4 exercícios · 12 séries"), "Summary after adding")
        scrollToTop(in: app)
        let names = (0..<headers.count).map { headers.element(boundBy: $0).label.components(separatedBy: ",")[0] }
        XCTAssertEqual(Array(names.prefix(2)), ["Crossover na Polia Alta", "Barra Fixa Pronada"])
        scrollToBottom(in: app)
        let lastNames = (0..<headers.count).map { headers.element(boundBy: $0).label.components(separatedBy: ",")[0] }
        XCTAssertEqual(Array(lastNames.suffix(2)), ["Crossover na Polia Média", "Crossover na Polia Baixa"])
    }

    /// A double tap on "Adicionar (N)" adds the exercises once, closes the picker and shows no error.
    @MainActor
    func testDoubleTapOnAddAddsExercisesOnce() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push"])
        openWorkout(named: "Push", in: app)

        app.buttons["workout.addExercises"].tap()
        for name in ["Crossover na Polia Alta", "Crossover na Polia Baixa"] {
            searchPicker(for: name, in: app)
            let card = pickerCard(name, in: app)
            XCTAssertTrue(card.waitForExistence(timeout: 10), "Exercise '\(name)' not found in the picker")
            card.tap()
        }
        let confirm = app.buttons["picker.add"]
        XCTAssertTrue(confirm.isEnabled, "Add button disabled after selecting exercises")
        confirm.doubleTap()

        XCTAssertTrue(confirm.waitForNonExistence(timeout: 10), "Picker not closed after adding")
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 3), "An error alert appeared after a double tap")
        let headers = exerciseHeaders(in: app)
        XCTAssertTrue(headers.firstMatch.waitForExistence(timeout: 10), "Exercises not added")
        XCTAssertTrue(waitForLabel(of: element("workout.summary", in: app), toBe: "2 exercícios · 6 séries"), "Exercises added more than once")
        XCTAssertTrue(headers.element(boundBy: 0).label.hasPrefix("Crossover na Polia Alta,"), "First: \(headers.element(boundBy: 0).label)")
    }

    // MARK: - Sets

    /// The editor of the model: the legend and each set's number in the colors of its type. A tap on the
    /// number opens the sheet; the type chosen is saved and kept after leaving.
    @MainActor
    func testChangeTheTypeOfASet() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: [push, "set-types:Push"])
        openWorkout(named: "Push", in: app)

        let types = setTypes(in: app)
        XCTAssertTrue(types.firstMatch.waitForExistence(timeout: 10), "Sets not shown")
        XCTAssertTrue(element("workout.legend", in: app).exists, "Legend not shown")
        XCTAssertEqual(element("workout.summary", in: app).label, "4 exercícios · 14 séries")
        XCTAssertEqual((0..<5).map { types.element(boundBy: $0).label }, [
            "Série 1, Aquecimento", "Série 2, Preparatória", "Série 3, Válida", "Série 4, Válida", "Série 5, Falha",
        ])
        XCTAssertEqual(fields("workout.set.weight", in: app).element(boundBy: 0).value as? String, "40")
        XCTAssertEqual(fields("workout.set.min", in: app).element(boundBy: 0).value as? String, "12")
        XCTAssertEqual(fields("workout.set.max", in: app).element(boundBy: 0).value as? String, "15")
        attachScreenshot(named: "75-workout-editor", of: app)

        types.element(boundBy: 2).tap()
        let working = app.buttons["setType.working"]
        XCTAssertTrue(working.waitForExistence(timeout: 10), "Set type sheet not shown")
        XCTAssertTrue(working.isSelected, "The set's type is not the chosen one")
        XCTAssertFalse(app.buttons["setType.warmup"].isSelected)
        XCTAssertTrue(app.buttons["setType.remove"].isEnabled, "Remover série disabled with 5 sets")
        attachScreenshot(named: "76-set-type-sheet", of: app)
        app.buttons["setType.warmup"].tap()
        XCTAssertTrue(working.waitForNonExistence(timeout: 10), "Choosing a type did not close the sheet")
        XCTAssertTrue(waitForLabel(of: types.element(boundBy: 2), toBe: "Série 3, Aquecimento"), "Type not changed")

        // Kept after leaving and coming back.
        goBackFromEditor(in: app)
        openWorkout(named: "Push", in: app)
        XCTAssertTrue(waitForLabel(of: setTypes(in: app).element(boundBy: 2), toBe: "Série 3, Aquecimento"), "Type not saved")
    }

    /// A load and repetitions typed in place are saved when the field is left, and are there after leaving
    /// the editor and coming back. A maximum below the minimum moves the minimum and shows the notice.
    @MainActor
    func testEditLoadAndRepetitionsInPlace() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Supino Reto com Barra|Barra Fixa Pronada"])
        openWorkout(named: "Push", in: app)

        let weight = fields("workout.set.weight", in: app).element(boundBy: 0)
        let minimum = fields("workout.set.min", in: app).element(boundBy: 0)
        let maximum = fields("workout.set.max", in: app).element(boundBy: 0)
        XCTAssertTrue(weight.waitForExistence(timeout: 10), "Sets not shown")
        XCTAssertEqual(minimum.value as? String, "8")
        XCTAssertEqual(maximum.value as? String, "12")

        // Moving from field to field saves each one; OK saves the last.
        replaceText(of: weight, with: "62")
        replaceText(of: minimum, with: "6")
        replaceText(of: maximum, with: "10")
        tapOK(in: app)
        XCTAssertEqual(weight.value as? String, "62")
        XCTAssertEqual(minimum.value as? String, "6")
        XCTAssertEqual(maximum.value as? String, "10")
        XCTAssertEqual(fields("workout.set.min", in: app).element(boundBy: 1).value as? String, "8", "Another set changed")

        goBackFromEditor(in: app)
        openWorkout(named: "Push", in: app)
        XCTAssertTrue(fields("workout.set.weight", in: app).element(boundBy: 0).waitForValue("62"), "Load not saved")
        XCTAssertEqual(fields("workout.set.min", in: app).element(boundBy: 0).value as? String, "6", "Minimum not saved")
        XCTAssertEqual(fields("workout.set.max", in: app).element(boundBy: 0).value as? String, "10", "Maximum not saved")

        // A maximum below the minimum: the minimum follows it, with the notice. The notice shows for a
        // few seconds, so it is looked for right after OK, before anything else is waited for.
        replaceText(of: fields("workout.set.max", in: app).element(boundBy: 0), with: "4")
        app.buttons["OK"].tap()
        let notice = element("workout.rangeNotice", in: app)
        XCTAssertTrue(notice.waitForExistence(timeout: 3), "Notice not shown")
        XCTAssertEqual(notice.label, "O máximo não pode ser menor que o mínimo.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Keyboard still shown")
        XCTAssertEqual(fields("workout.set.min", in: app).element(boundBy: 0).value as? String, "4")
        XCTAssertEqual(fields("workout.set.max", in: app).element(boundBy: 0).value as? String, "4")
        XCTAssertTrue(notice.waitForNonExistence(timeout: 10), "Notice did not go away")

        // Clearing the load removes it: the field shows its placeholder.
        replaceText(of: fields("workout.set.weight", in: app).element(boundBy: 0), with: "")
        tapOK(in: app)
        let cleared = fields("workout.set.weight", in: app).element(boundBy: 0)
        XCTAssertEqual(cleared.value as? String, cleared.placeholderValue, "Load not removed")
    }

    /// "+ Adicionar série" copies the last set, a warm-up giving a working set; "Remover série" removes
    /// a set, and the last one cannot be removed.
    @MainActor
    func testAddAndRemoveSets() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Supino Reto com Barra", "set-types:Push"])
        openWorkout(named: "Push", in: app)
        let types = setTypes(in: app)
        XCTAssertTrue(waitForCount(types, 5), "Sets not shown")

        // A copy of the failure set is a failure set, with its values.
        app.buttons["workout.addSet"].tap()
        XCTAssertTrue(waitForCount(types, 6), "Set not added")
        XCTAssertEqual(types.element(boundBy: 5).label, "Série 6, Falha")
        XCTAssertEqual(fields("workout.set.weight", in: app).element(boundBy: 5).value as? String, "55")
        XCTAssertEqual(fields("workout.set.max", in: app).element(boundBy: 5).value as? String, "12")

        // A copy of a warm-up is a working set.
        chooseType("warmup", forSetAt: 5, in: app)
        app.buttons["workout.addSet"].tap()
        XCTAssertTrue(waitForCount(types, 7), "Set not added")
        XCTAssertEqual(types.element(boundBy: 6).label, "Série 7, Válida")
        XCTAssertEqual(element("workout.summary", in: app).label, "1 exercício · 7 séries")

        // Removing sets renumbers the others, down to the last one, which cannot be removed.
        removeSet(at: 0, in: app)
        XCTAssertTrue(waitForCount(types, 6), "Set not removed")
        XCTAssertEqual(types.element(boundBy: 0).label, "Série 1, Preparatória")
        for expected in (1...5).reversed() {
            removeSet(at: 0, in: app)
            XCTAssertTrue(waitForCount(types, expected), "Set not removed")
        }
        types.element(boundBy: 0).tap()
        let remove = app.buttons["setType.remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 10), "Set type sheet not shown")
        XCTAssertFalse(remove.isEnabled, "The last set can be removed")
        XCTAssertEqual(element("setType.removeHint", in: app).label, "O exercício precisa ter pelo menos 1 série.")
        // Choosing the type it has closes the sheet without a change.
        app.buttons["setType.working"].tap()
        XCTAssertTrue(remove.waitForNonExistence(timeout: 10), "Set type sheet not closed")
        XCTAssertEqual(types.count, 1)
    }

    // MARK: - Exercises

    @MainActor
    func testReorderExercises() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Supino Reto com Barra|Barra Fixa Pronada|Tríceps na Polia com Corda"])
        openWorkout(named: "Push", in: app)
        XCTAssertTrue(exerciseHeaders(in: app).firstMatch.waitForExistence(timeout: 10), "Exercises not shown")

        chooseFromEditorMenu("Ordenar exercícios", in: app)
        let rows = app.descendants(matching: .any).matching(identifier: "workout.ordering.exercise")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "Reorder mode not entered")
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(app.buttons["workout.ordering.done"].exists, "Concluir not shown")
        XCTAssertFalse(app.buttons["workout.menu"].exists, "The ⋯ menu is still shown")
        XCTAssertEqual(rows.element(boundBy: 0).label, "Supino Reto com Barra, 3 séries")
        attachScreenshot(named: "78-workout-reorder", of: app)

        // The first exercise dragged by its handle below the last one. A drag the list did not follow at
        // all (seen on a busy CI machine: the order unchanged) is made once more; the new order is
        // checked either way.
        let moved = "Supino Reto com Barra, 3 séries"
        dragFirstExerciseBelowTheLast(in: app)
        if !waitForLabel(of: rows.element(boundBy: 2), toBe: moved, timeout: 5), rows.element(boundBy: 0).label == moved {
            dragFirstExerciseBelowTheLast(in: app)
        }
        XCTAssertTrue(waitForLabel(of: rows.element(boundBy: 2), toBe: moved), "Not reordered: \(rows.element(boundBy: 2).label)")

        app.buttons["workout.ordering.done"].tap()
        XCTAssertTrue(app.buttons["workout.menu"].waitForExistence(timeout: 10), "Reorder mode not left")
        let headers = exerciseHeaders(in: app)
        XCTAssertTrue(headers.element(boundBy: 0).label.hasPrefix("Barra Fixa Pronada,"), "First: \(headers.element(boundBy: 0).label)")

        // Kept after leaving.
        goBackFromEditor(in: app)
        openWorkout(named: "Push", in: app)
        XCTAssertTrue(exerciseHeaders(in: app).element(boundBy: 0).label.hasPrefix("Barra Fixa Pronada,"), "Order not saved")

        // The exercise's ⋯ menu also starts reordering.
        app.buttons.matching(identifier: "workout.exercise.menu").element(boundBy: 0).tap()
        let reorder = app.buttons["Ordenar exercícios"]
        XCTAssertTrue(reorder.waitForExistence(timeout: 10), "Reorder option not in the exercise menu")
        reorder.tap()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "Reorder mode not entered from the exercise menu")
    }

    @MainActor
    func testRemoveExerciseCancelAndConfirm() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Crossover na Polia Alta|Barra Fixa Pronada"])
        openWorkout(named: "Push", in: app)
        let headers = exerciseHeaders(in: app)
        XCTAssertTrue(headers.firstMatch.waitForExistence(timeout: 10), "Exercises not shown")

        let menu = app.buttons.matching(identifier: "workout.exercise.menu").element(boundBy: 0)
        menu.tap()
        app.buttons["Remover do treino"].tap()
        XCTAssertTrue(app.staticTexts["Remover Crossover na Polia Alta?"].waitForExistence(timeout: 10), "Removal question not shown")
        XCTAssertTrue(app.staticTexts["As séries planejadas dele também saem deste treino. O histórico não muda."].exists, "Removal message")
        // The question points to the exercise's ⋯: it opens right below it.
        let menuFrame = menu.frame
        let confirmationFrame = app.buttons["Remover do treino"].frame
        XCTAssertGreaterThan(confirmationFrame.minY, menuFrame.maxY, "Confirmation not below the exercise's ⋯ \(menuFrame): \(confirmationFrame)")
        XCTAssertLessThan(confirmationFrame.minY, menuFrame.maxY + 300, "Confirmation far from the exercise's ⋯ \(menuFrame): \(confirmationFrame)")
        cancelDialog(confirmLabel: "Remover do treino", in: app)
        XCTAssertEqual(element("workout.summary", in: app).label, "2 exercícios · 6 séries", "Cancel removed the exercise")

        menu.tap()
        app.buttons["Remover do treino"].tap()
        let confirm = app.buttons["Remover do treino"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Removal confirmation not shown")
        confirm.tap()

        XCTAssertTrue(waitForLabel(of: element("workout.summary", in: app), toBe: "1 exercício · 3 séries"), "Exercise not removed")
        XCTAssertTrue(headers.element(boundBy: 0).label.hasPrefix("Barra Fixa Pronada,"), "Wrong exercise removed: \(headers.element(boundBy: 0).label)")
    }

    // MARK: - Workout

    @MainActor
    func testRenameWorkout() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push"])
        openWorkout(named: "Push", in: app)

        chooseFromEditorMenu("Renomear treino", in: app)
        let field = app.textFields["workout.name.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Name field not found")
        XCTAssertEqual(field.value as? String, "Push")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Push".count))
        XCTAssertFalse(app.buttons["workout.name.save"].isEnabled, "Save enabled with an empty name")
        field.typeText("Peito e Tríceps")
        app.buttons["workout.name.save"].tap()

        XCTAssertTrue(waitForLabel(of: element("workout.title", in: app), toBe: "Peito e Tríceps"), "Title not renamed")
        goBackFromEditor(in: app)
        let card = app.buttons["workouts.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(card.label.contains("Peito e Tríceps"), "Card not renamed: \(card.label)")
    }

    @MainActor
    func testDeleteWorkoutCancelAndConfirm() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push"])
        openWorkout(named: "Push", in: app)

        let menu = app.buttons["workout.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "Editor menu not shown")
        let menuFrame = menu.frame
        chooseFromEditorMenu("Excluir treino", in: app)
        XCTAssertTrue(element(labelStartingWith: "Excluir “Push”", in: app).waitForExistence(timeout: 10), "Delete confirmation not shown")
        XCTAssertTrue(app.staticTexts["O histórico dos treinos já feitos continua salvo. Não dá para desfazer."].exists, "Delete message")
        // The confirmation points to the ⋯ it came from: it opens right below it.
        let confirmationFrame = app.buttons["Excluir"].frame
        XCTAssertGreaterThan(confirmationFrame.minY, menuFrame.maxY, "Confirmation not below the ⋯ \(menuFrame): \(confirmationFrame)")
        XCTAssertLessThan(confirmationFrame.minY, menuFrame.maxY + 300, "Confirmation far from the ⋯ \(menuFrame): \(confirmationFrame)")
        attachScreenshot(named: "15-workout-delete-confirmation", of: app)
        cancelDialog(confirmLabel: "Excluir", in: app)
        XCTAssertTrue(waitForLabel(of: element("workout.title", in: app), toBe: "Push"), "Cancel left the editor")

        chooseFromEditorMenu("Excluir treino", in: app)
        let confirm = app.buttons["Excluir"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Delete confirmation not shown")
        confirm.tap()

        XCTAssertTrue(element("workouts.empty", in: app).waitForExistence(timeout: 10), "List not shown empty after deleting")
        XCTAssertFalse(app.buttons["workouts.card"].exists, "Deleted workout still listed")
    }

    /// "Iniciar Push" at the end of the editor starts the workout, as the ▶ of the card does.
    @MainActor
    func testStartFromTheEditor() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Supino Reto com Barra", "set-types:Push"])
        openWorkout(named: "Push", in: app)

        scrollToBottom(in: app)
        let start = app.buttons["workout.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "Iniciar not shown")
        XCTAssertEqual(start.label, "Iniciar Push")
        start.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
        // The session starts with the types of the plan.
        let first = app.buttons.matching(identifier: "session.set.type").element(boundBy: 0)
        XCTAssertTrue(waitForLabel(of: first, toBe: "Série 1, Aquecimento, atual"), "First set: \(first.label)")
    }

    /// A load that cannot be saved is never lost: "‹ Treinos" and "Iniciar" report it and the editor
    /// stays, with the stored value back in the field; a swipe back cannot stay, and the root of the app
    /// reports it over the Treinos list.
    @MainActor
    func testAValueThatCannotBeSavedIsReported() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa Pronada"])
        openWorkout(named: "Push", in: app)
        let weight = fields("workout.set.weight", in: app).element(boundBy: 0)
        XCTAssertTrue(weight.waitForExistence(timeout: 10), "Sets not shown")

        // "‹ Treinos" with the keyboard still up.
        replaceText(of: weight, with: "1500")
        app.buttons["workout.back"].tap()
        acceptLoadError(in: app)
        XCTAssertTrue(element("workout.title", in: app).exists, "The editor closed with a value not saved")
        XCTAssertEqual(weight.value as? String, weight.placeholderValue, "The value not saved is still in the field")

        // "Iniciar", the same way.
        replaceText(of: weight, with: "1500")
        scrollToBottom(in: app)
        app.buttons["workout.start"].tap()
        acceptLoadError(in: app)
        XCTAssertFalse(element("session.name", in: app).exists, "The workout started with a value not saved")
        XCTAssertTrue(element("workout.title", in: app).exists, "The editor closed with a value not saved")

        // A swipe from the left edge closes the editor; the problem is shown over the list.
        scrollToTop(in: app)
        replaceText(of: fields("workout.set.weight", in: app).element(boundBy: 0), with: "1500")
        let window = app.windows.firstMatch
        let edge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        acceptLoadError(in: app)
        XCTAssertTrue(app.buttons["workouts.add"].waitForExistence(timeout: 10), "The swipe did not go back to Treinos")

        // Nothing was saved.
        openWorkout(named: "Push", in: app)
        let reopened = fields("workout.set.weight", in: app).element(boundBy: 0)
        XCTAssertTrue(reopened.waitForExistence(timeout: 10), "Sets not shown")
        XCTAssertEqual(reopened.value as? String, reopened.placeholderValue, "A value not valid was saved")
    }

    /// Waits for the message of a load over the maximum and closes it with OK.
    @MainActor
    private func acceptLoadError(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "The problem was not reported", file: file, line: line)
        let message = alert.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "A carga pode ser no máximo")).firstMatch
        XCTAssertTrue(message.exists, "Message: \(alert.staticTexts.allElementsBoundByIndex.map(\.label))", file: file, line: line)
        alert.buttons["OK"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 10), "The message did not close", file: file, line: line)
    }

    /// The editor is pushed over the Treinos list, without the tab bar as in the model: a swipe from the
    /// left edge goes back, as on any screen.
    @MainActor
    func testSwipeFromTheEdgeGoesBack() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Supino Reto com Barra"])
        openWorkout(named: "Push", in: app)
        XCTAssertTrue(waitForHiddenTabBar(in: app), "Tab bar shown on the editor")

        let window = app.windows.firstMatch
        let edge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        XCTAssertTrue(app.buttons["workouts.add"].waitForExistence(timeout: 10), "The swipe did not go back to Treinos")
        XCTAssertTrue(element("workout.title", in: app).waitForNonExistence(timeout: 10), "Editor still shown")
    }

    /// With the largest text the rows wrap: the repetitions go below the load, and no field is cut or
    /// leaves the screen.
    @MainActor
    func testLargeTextKeepsTheEditorOnScreen() throws {
        continueAfterFailure = false
        let app = launchOnTab(
            "Treinos",
            seed: [push, "set-types:Push"],
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )
        openWorkout(named: "Push", in: app)

        let type = setTypes(in: app).element(boundBy: 0)
        let weight = fields("workout.set.weight", in: app).element(boundBy: 0)
        let minimum = fields("workout.set.min", in: app).element(boundBy: 0)
        let maximum = fields("workout.set.max", in: app).element(boundBy: 0)
        XCTAssertTrue(weight.waitForExistence(timeout: 10), "Sets not shown")
        let screen = app.windows.firstMatch.frame
        for (name, field) in [("load", weight), ("minimum", minimum), ("maximum", maximum)] {
            XCTAssertTrue(field.exists, "\(name) not shown")
            XCTAssertGreaterThanOrEqual(field.frame.minX, screen.minX, "\(name) leaves the screen")
            XCTAssertLessThanOrEqual(field.frame.maxX, screen.maxX, "\(name) leaves the screen")
            XCTAssertGreaterThanOrEqual(field.frame.height, 32, "\(name) is cut")
        }
        XCTAssertGreaterThan(minimum.frame.minY, weight.frame.maxY, "The repetitions are not below the load")
        XCTAssertEqual(type.label, "Série 1, Aquecimento")
        // The exercise's icon stops growing at the largest standard size: the name keeps most of the width.
        let name = app.staticTexts["Supino Reto com Barra"].firstMatch
        XCTAssertTrue(name.exists, "Exercise name not shown")
        XCTAssertLessThan(name.frame.minX, screen.width / 4, "The icon takes the name's room: \(name.frame)")
        recordMeasurement(
            "Medição: editor com o maior texto (tela de \(Int(screen.width)) pt)",
            "name \(Int(name.frame.minX))–\(Int(name.frame.maxX)) × \(Int(name.frame.minY))–\(Int(name.frame.maxY)); type \(Int(type.frame.minX))–\(Int(type.frame.maxX)); load \(Int(weight.frame.minX))–\(Int(weight.frame.maxX)) × \(Int(weight.frame.minY))–\(Int(weight.frame.maxY)); min \(Int(minimum.frame.minX))–\(Int(minimum.frame.maxX)); max \(Int(maximum.frame.minX))–\(Int(maximum.frame.maxX)) × \(Int(maximum.frame.minY))–\(Int(maximum.frame.maxY))"
        )
        attachScreenshot(named: "81-workout-editor-large-text", of: app)
    }
}
