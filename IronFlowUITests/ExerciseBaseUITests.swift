import XCTest

/// The base list ("Lista base de exercícios"): the rows EQUIPAMENTO and PEGADA or VARIAÇÃO of an exercise
/// screen, each combination with its own history; the choice sheet of the picker (choose, unchoose, "Já está
/// no treino", and the equipment filter choosing at once); "Adicionar a um treino" from the exercise screen
/// (a workout, a workout that has it, a new workout); and "Montar treino" from the Exercícios tab, with
/// "Continuar". The screenshots 127 to 131 use the prototype's history, its "today" (16 October 2026) and its
/// three workouts.
final class ExerciseBaseUITests: IronFlowUITestCase {
    private let prototypeToday = ["-ui-today", "2026-10-16"]
    /// The prototype's workouts, with 3 sets in each exercise.
    private let workouts = [
        "workout:Push:Supino Reto (Barra)|Supino Inclinado (Halter)|Desenvolvimento (Halter)|Tríceps Corda (Polia)",
        "workout:Pull:Puxada Alta Aberta (Polia)|Rosca Direta (Barra)",
        "workout:Pernas:Agachamento Livre (Barra)|Leg Press 45° (Máquina)|Cadeira Extensora (Máquina)|Mesa Flexora (Máquina)|Stiff (Barra)",
    ]

    // MARK: - Helpers

    /// On the Exercícios tab: searches `search`, lets the keyboard go and opens the screen of the base `base`.
    @MainActor
    private func openBase(_ base: String, search: String, in app: XCUIApplication) {
        let field = app.textFields["exercises.search"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Search field not found")
        field.tapAndWaitForKeyboardFocus()
        field.typeText(search)
        XCTAssertTrue(field.waitForValue(search), "The search field holds \(String(describing: field.value))")
        field.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Keyboard still shown")
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "exercises.card", "\(base), "))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No card for \(base)")
        card.tap()
        let title = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label == %@", "exercise.title", base))
            .firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 20), "Exercise screen of \(base) not shown")
    }

    @MainActor
    private func waitForSelected(_ element: XCUIElement, _ isSelected: Bool = true) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == %@", NSNumber(value: isSelected)), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }

    /// The rows of the sheet "Adicionar a um treino", in the order of the Treinos tab.
    @MainActor
    private func workoutRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "addToWorkout.workout")
    }

    // MARK: - The rows of the exercise screen

    @MainActor
    func testRowsChooseTheCombination() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", seed: ["prototype-history"], extraArguments: prototypeToday)
        openBase("Puxada Alta", search: "puxada alta", in: app)
        XCTAssertEqual(element("exercise.subtitle", in: app).label, "Dorsais")

        // It opens on the combination done last, with its history.
        let cable = app.buttons["exercise.equipment.cable"]
        let open = app.buttons["exercise.variation.Aberta"]
        let closed = app.buttons["exercise.variation.Fechada"]
        XCTAssertTrue(cable.waitForExistence(timeout: 10), "No EQUIPAMENTO row")
        XCTAssertTrue(cable.isSelected && open.isSelected, "Not on Puxada Alta Aberta (Polia), the one done")
        XCTAssertTrue(element("exercise.lastTime", in: app).waitForExistence(timeout: 10), "No last time of the one done")

        // The base's order, in rows that wrap inside the screen; the common ones say their name, the others
        // that they are less common.
        let order = ["machine", "isoLateralMachine", "cable", "band", "barbell", "dumbbell", "smith", "kettlebell", "plate", "bodyweight"]
        let screen = app.windows.firstMatch.frame
        let frames = order.map { app.buttons["exercise.equipment.\($0)"].frame }
        for (index, pair) in zip(frames, frames.dropFirst()).enumerated() {
            let (previous, next) = pair
            let sameLine = abs(next.minY - previous.minY) <= 1
            XCTAssertTrue(sameLine ? next.minX > previous.maxX : next.minY > previous.maxY, "\(order[index + 1]) is not after \(order[index])")
            XCTAssertLessThanOrEqual(next.maxX, screen.maxX, "\(order[index + 1]) leaves the screen")
        }
        XCTAssertEqual(app.buttons["exercise.equipment.machine"].label, "Máquina")
        XCTAssertEqual(app.buttons["exercise.equipment.band"].label, "Elástico")
        XCTAssertEqual(app.buttons["exercise.equipment.kettlebell"].label, "Kettlebell, menos comum")
        XCTAssertEqual(app.buttons["exercise.equipment.barbell"].label, "Barra, menos comum")
        XCTAssertEqual(closed.label, "Fechada")
        XCTAssertTrue(app.buttons["exercise.addToWorkout"].exists, "No Adicionar a um treino")
        attachScreenshot(named: "127-exercise-detail-grip", of: app)

        // Another grip: the same equipment, and that combination's own history (never done).
        closed.tap()
        XCTAssertTrue(waitForSelected(closed), "Fechada not chosen")
        XCTAssertTrue(cable.isSelected, "The equipment changed with the grip")
        XCTAssertFalse(open.isSelected, "Aberta still chosen")
        XCTAssertTrue(element("exercise.neverDone", in: app).waitForExistence(timeout: 10), "Puxada Alta Fechada (Polia) shows another's history")
        XCTAssertEqual(element("exercise.title", in: app).label, "Puxada Alta")

        // Another equipment keeps the grip.
        let machine = app.buttons["exercise.equipment.machine"]
        machine.tap()
        XCTAssertTrue(waitForSelected(machine), "Máquina not chosen")
        XCTAssertTrue(closed.isSelected, "The grip changed with the equipment")

        // Back to the one done: its history again.
        chooseCombination(equipment: "cable", variation: "Aberta", in: app)
        XCTAssertTrue(element("exercise.lastTime", in: app).waitForExistence(timeout: 10), "The history of the one done did not come back")

        // "Criar minha versão" copies the combination chosen.
        app.buttons["exercise.menu"].tap()
        let copy = app.buttons["Criar minha versão"]
        XCTAssertTrue(copy.waitForExistence(timeout: 10), "No Criar minha versão")
        copy.tap()
        let name = app.textFields["exerciseForm.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15), "No form")
        XCTAssertEqual(name.value as? String, "Puxada Alta Aberta (Polia) 2")
    }

    @MainActor
    func testBarraWRightAfterBarra() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", seed: ["prototype-history"], extraArguments: prototypeToday)
        openBase("Rosca Direta", search: "rosca direta", in: app)
        XCTAssertEqual(element("exercise.subtitle", in: app).label, "Bíceps")

        let barbell = app.buttons["exercise.equipment.barbell"]
        let ezBar = app.buttons["exercise.equipment.ezBar"]
        XCTAssertTrue(ezBar.waitForExistence(timeout: 10), "No Barra W")
        XCTAssertTrue(barbell.isSelected, "Not on Rosca Direta (Barra), the one done")
        XCTAssertEqual(ezBar.label, "Barra W")
        XCTAssertTrue(abs(ezBar.frame.minY - barbell.frame.minY) <= 1 && ezBar.frame.minX > barbell.frame.maxX, "Barra W is not right after Barra")

        ezBar.tap()
        XCTAssertTrue(waitForSelected(ezBar), "Barra W not chosen")
        XCTAssertTrue(app.buttons["exercise.variation.Normal"].isSelected, "The variation changed with the equipment")
        XCTAssertTrue(element("exercise.neverDone", in: app).waitForExistence(timeout: 10), "Rosca Direta (Barra W) shows another's history")
        attachScreenshot(named: "128-exercise-detail-ez-bar", of: app)

        // Another variation keeps Barra W.
        let alternate = app.buttons["exercise.variation.Alternada"]
        alternate.tap()
        XCTAssertTrue(waitForSelected(alternate), "Alternada not chosen")
        XCTAssertTrue(ezBar.isSelected, "The equipment changed with the variation")
    }

    @MainActor
    func testLargeTextKeepsTheRowsOnTheScreen() throws {
        continueAfterFailure = false
        let app = launchOnTab(
            "Exercícios",
            seed: ["prototype-history"],
            extraArguments: prototypeToday + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )
        openBase("Puxada Alta", search: "puxada alta", in: app)
        let screen = app.windows.firstMatch.frame
        let buttons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "exercise.equipment.")).allElementsBoundByIndex
            + app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "exercise.variation.")).allElementsBoundByIndex
        XCTAssertEqual(buttons.count, 16, "Not the 10 equipment and the 6 grips")
        for button in buttons {
            XCTAssertTrue(button.frame.minX >= screen.minX && button.frame.maxX <= screen.maxX, "\(button.identifier) leaves the screen: \(button.frame)")
        }
        let add = app.buttons["exercise.addToWorkout"]
        XCTAssertTrue(add.exists && add.frame.maxX <= screen.maxX, "Adicionar a um treino leaves the screen")
    }

    // MARK: - The choice sheet

    @MainActor
    func testChoiceSheetChoosesAndTheFilterChoosesAtOnce() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: workouts + ["prototype-history"], extraArguments: prototypeToday)
        openWorkout(named: "Push", in: app)
        scrollToBottom(in: app)
        app.buttons["workout.addExercises"].tap()
        let add = app.buttons["picker.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "No picker")
        XCTAssertFalse(add.isEnabled, "Adicionar enabled with nothing chosen")

        // A base whose combination done last is in the workout: its sheet opens on it, which cannot be chosen.
        searchPicker(for: "supino reto", in: app)
        let card = pickerCard("Supino Reto", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No Supino Reto")
        XCTAssertTrue(card.label.hasSuffix("no treino: Barra"), "Card: \(card.label)")
        card.tap()
        let already = app.buttons["choice.inWorkout"]
        XCTAssertTrue(already.waitForExistence(timeout: 10), "No Já está no treino")
        XCTAssertFalse(already.isEnabled, "Já está no treino can be tapped")
        XCTAssertTrue(app.buttons["choice.equipment.barbell"].isSelected, "Not on Barra")
        let shown = element("choice.shown", in: app)
        XCTAssertTrue(shown.label.hasPrefix("Barra") && shown.label.contains("Última vez: 09/10"), "Shown: \(shown.label)")
        attachScreenshot(named: "129-choice-sheet", of: app)

        // Another equipment, never done: Escolher, tapped twice, chooses it once and closes the sheet.
        chooseCombination(equipment: "dumbbell", prefix: "choice", in: app)
        XCTAssertTrue(waitForLabel(of: shown, containing: "Nunca feito"), "Shown: \(shown.label)")
        app.buttons["choice.choose"].doubleTap()
        XCTAssertTrue(app.buttons["choice.close"].waitForNonExistence(timeout: 10), "The sheet did not close")
        XCTAssertTrue(waitForSelected(card), "Supino Reto not shown as chosen")
        XCTAssertTrue(card.label.contains("escolhido: Halteres"), "Card: \(card.label)")
        XCTAssertEqual(add.label, "Adicionar (1)")

        // Again: on the one chosen, with Desmarcar; another one chosen says the first.
        card.tap()
        let unchoose = app.buttons["choice.unchoose"]
        XCTAssertTrue(unchoose.waitForExistence(timeout: 10), "Not on the one chosen")
        XCTAssertTrue(app.buttons["choice.equipment.dumbbell"].isSelected, "Not on Halteres")
        chooseCombination(equipment: "cable", prefix: "choice", in: app)
        XCTAssertEqual(element("choice.also", in: app).label, "Também escolhido: Halteres")
        app.buttons["choice.choose"].tap()
        XCTAssertTrue(app.buttons["choice.close"].waitForNonExistence(timeout: 10), "The sheet did not close")
        XCTAssertEqual(add.label, "Adicionar (2)")

        // Desmarcar keeps the sheet open, on the same combination, to be chosen again.
        card.tap()
        XCTAssertTrue(unchoose.waitForExistence(timeout: 10), "Not on the one chosen last")
        XCTAssertTrue(app.buttons["choice.equipment.cable"].isSelected, "Not on Polia, the one chosen last")
        unchoose.tap()
        XCTAssertTrue(app.buttons["choice.choose"].waitForExistence(timeout: 10), "Desmarcar closed the sheet")
        app.buttons["choice.close"].tap()
        XCTAssertTrue(app.buttons["choice.close"].waitForNonExistence(timeout: 10), "The sheet did not close")
        XCTAssertEqual(add.label, "Adicionar (1)")

        // With the equipment filter on, a base without a second row and one common combination of it is
        // chosen at once, and unchosen the same way.
        let cableFilter = app.buttons["picker.equipment.cable"]
        XCTAssertTrue(cableFilter.waitForExistence(timeout: 10), "No Polia filter")
        cableFilter.tap()
        XCTAssertTrue(waitForSelected(cableFilter), "Polia filter not on")
        searchPicker(for: "supino inclinado", in: app)
        let inclined = pickerCard("Supino Inclinado", in: app)
        XCTAssertTrue(inclined.waitForExistence(timeout: 10), "No Supino Inclinado")
        inclined.tap()
        XCTAssertTrue(waitForSelected(inclined), "Supino Inclinado not chosen at once")
        XCTAssertFalse(app.buttons["choice.close"].exists, "A sheet opened")
        XCTAssertEqual(add.label, "Adicionar (2)")
        inclined.tap()
        XCTAssertTrue(waitForSelected(inclined, false), "Supino Inclinado not unchosen")
        XCTAssertEqual(add.label, "Adicionar (1)")
        inclined.tap()
        XCTAssertTrue(waitForSelected(inclined), "Supino Inclinado not chosen again")

        // A base with a grip opens its sheet, on that equipment.
        searchPicker(for: "puxada alta", in: app)
        let pulldown = pickerCard("Puxada Alta", in: app)
        XCTAssertTrue(pulldown.waitForExistence(timeout: 10), "No Puxada Alta")
        pulldown.tap()
        XCTAssertTrue(app.buttons["choice.close"].waitForExistence(timeout: 10), "No sheet for a base with a grip")
        XCTAssertTrue(app.buttons["choice.equipment.cable"].isSelected && app.buttons["choice.variation.Aberta"].isSelected, "Not on Polia · Aberta")
        app.buttons["choice.close"].tap()
        XCTAssertTrue(app.buttons["choice.close"].waitForNonExistence(timeout: 10), "The sheet did not close")

        // Adicionar: the two combinations at the end of the workout.
        add.tap()
        waitForEditor(of: "Push", in: app)
        let headers = app.descendants(matching: .any).matching(identifier: "workout.exercise")
        XCTAssertTrue(waitForLabel(of: element("workout.summary", in: app), toBe: "6 exercícios · 18 séries"), "Summary: \(element("workout.summary", in: app).label)")
        XCTAssertTrue(headers.element(boundBy: 4).label.hasPrefix("Supino Reto (Halter),"), "Fifth: \(headers.element(boundBy: 4).label)")
        XCTAssertTrue(headers.element(boundBy: 5).label.hasPrefix("Supino Inclinado (Polia),"), "Sixth: \(headers.element(boundBy: 5).label)")
    }

    // MARK: - Adicionar a um treino

    @MainActor
    func testAddToAWorkoutFromTheExerciseScreen() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", seed: workouts + ["prototype-history"], extraArguments: prototypeToday + longToastArguments)
        openBase("Supino Reto", search: "supino reto barra", in: app)
        XCTAssertTrue(app.buttons["exercise.equipment.barbell"].isSelected, "Not on Supino Reto (Barra)")

        // "Criar treino novo" first, then the workouts in the order of the Treinos tab; Push has it.
        let addButton = app.buttons["exercise.addToWorkout"]
        addButton.tap()
        let new = app.buttons["addToWorkout.new"]
        XCTAssertTrue(new.waitForExistence(timeout: 10), "Adicionar a um treino not shown")
        XCTAssertTrue(new.label.hasPrefix("Criar treino novo, Começa com este exercício"), "New: \(new.label)")
        let rows = workoutRows(in: app)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.element(boundBy: 0).label, "Push, Já está neste treino")
        XCTAssertFalse(rows.element(boundBy: 0).isEnabled, "Push, which has it, can be chosen")
        XCTAssertTrue(rows.element(boundBy: 1).label.hasPrefix("Pull, ") && rows.element(boundBy: 1).label.hasSuffix(", adicionar"), "Pull: \(rows.element(boundBy: 1).label)")
        XCTAssertTrue(rows.element(boundBy: 2).label.hasPrefix("Pernas, "), "Pernas: \(rows.element(boundBy: 2).label)")
        attachScreenshot(named: "130-add-to-workout", of: app)

        // Pull, tapped twice, gets it once; the screen stays.
        rows.element(boundBy: 1).doubleTap()
        XCTAssertTrue(waitForToast("Adicionado a “Pull”", in: app), "No Adicionado a “Pull”")
        XCTAssertTrue(new.waitForNonExistence(timeout: 10), "The sheet did not close")
        XCTAssertTrue(element("exercise.screen", in: app).exists, "The exercise screen closed")
        addButton.tap()
        XCTAssertTrue(new.waitForExistence(timeout: 10), "Adicionar a um treino not shown again")
        XCTAssertEqual(rows.element(boundBy: 1).label, "Pull, Já está neste treino")
        app.buttons["addToWorkout.cancel"].tap()
        XCTAssertTrue(new.waitForNonExistence(timeout: 10), "Cancelar did not close the sheet")

        // Another combination in a new workout: its name, and its editor on the Treinos tab.
        chooseCombination(equipment: "dumbbell", in: app)
        addButton.tap()
        XCTAssertTrue(new.waitForExistence(timeout: 10), "Adicionar a um treino not shown")
        new.tap()
        let field = app.textFields["workout.name.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No name sheet")
        field.tap()
        field.typeText("Peito")
        app.buttons["workout.name.save"].tap()
        waitForEditor(of: "Peito", in: app)
        XCTAssertTrue(waitForToast("Treino criado com 1 exercício", in: app), "No Treino criado com 1 exercício")
        let headers = app.descendants(matching: .any).matching(identifier: "workout.exercise")
        XCTAssertEqual(headers.count, 1)
        XCTAssertTrue(headers.firstMatch.label.hasPrefix("Supino Reto (Halter),"), "Exercise: \(headers.firstMatch.label)")
        goBackFromEditor(in: app)
        XCTAssertTrue(app.buttons["workouts.add"].waitForExistence(timeout: 10), "Not on the Treinos list")
        XCTAssertTrue(app.tabBars.buttons["Treinos"].isSelected, "Not on the Treinos tab")
        XCTAssertTrue(element(labelStartingWith: "Peito", in: app).exists, "No Peito on the list")

        // Pull has it at its end.
        openWorkout(named: "Pull", in: app)
        XCTAssertTrue(waitForLabel(of: element("workout.summary", in: app), toBe: "3 exercícios · 9 séries"), "Summary: \(element("workout.summary", in: app).label)")
    }

    @MainActor
    func testBuildAWorkoutFromTheExercisesTab() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", seed: workouts, extraArguments: longToastArguments)
        let build = app.buttons["exercises.build"]
        XCTAssertTrue(build.waitForExistence(timeout: 10), "No Montar treino")
        build.tap()
        let title = element("picker.title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 10), "No picker")
        XCTAssertEqual(title.label, "Montar treino")
        let add = app.buttons["picker.add"]
        XCTAssertEqual(add.label, "Continuar")
        XCTAssertFalse(add.isEnabled, "Continuar enabled with nothing chosen")
        attachScreenshot(named: "131-build-workout-picker", of: app)

        // Nothing is in a workout yet: Supino Reto (Barra), which Push has, can be chosen.
        searchPicker(for: "supino reto", in: app)
        chooseInPicker("Supino Reto", equipment: "barbell", in: app)
        searchPicker(for: "crucifixo", in: app)
        chooseInPicker("Crucifixo", in: app)
        XCTAssertEqual(add.label, "Continuar (2)")

        // Continuar, tapped twice, opens one sheet; Push has one of them.
        add.doubleTap()
        let new = app.buttons["addToWorkout.new"]
        XCTAssertTrue(new.waitForExistence(timeout: 10), "Adicionar a um treino not shown")
        XCTAssertTrue(new.label.hasPrefix("Criar treino novo, Começa com estes 2 exercícios"), "New: \(new.label)")
        let rows = workoutRows(in: app)
        XCTAssertEqual(rows.element(boundBy: 0).label, "Push, 1 já está neste treino · entra 1, adicionar")

        // Cancelar: back on the picker, with both still chosen.
        app.buttons["addToWorkout.cancel"].tap()
        XCTAssertTrue(new.waitForNonExistence(timeout: 10), "Cancelar did not close the sheet")
        XCTAssertEqual(add.label, "Continuar (2)")

        // Push gets only the one it lacks; both screens close.
        add.tap()
        XCTAssertTrue(new.waitForExistence(timeout: 10), "Adicionar a um treino not shown again")
        rows.element(boundBy: 0).tap()
        XCTAssertTrue(waitForToast("Adicionado a “Push”", in: app), "No Adicionado a “Push”")
        XCTAssertTrue(title.waitForNonExistence(timeout: 10), "The picker did not close")
        XCTAssertTrue(element("exercises.total", in: app).exists, "Not back on the Exercícios tab")
        openTab("Treinos", in: app)
        openWorkout(named: "Push", in: app)
        let headers = app.descendants(matching: .any).matching(identifier: "workout.exercise")
        XCTAssertTrue(waitForLabel(of: element("workout.summary", in: app), toBe: "5 exercícios · 15 séries"), "Summary: \(element("workout.summary", in: app).label)")
        XCTAssertTrue(headers.element(boundBy: 4).label.hasPrefix("Crucifixo (Halter),"), "Fifth: \(headers.element(boundBy: 4).label)")
        goBackFromEditor(in: app)

        // A new workout with one: its editor opens.
        openTab("Exercícios", in: app)
        build.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10), "No picker")
        searchPicker(for: "remada curvada", in: app)
        chooseInPicker("Remada Curvada", in: app)
        add.tap()
        XCTAssertTrue(new.waitForExistence(timeout: 10), "Adicionar a um treino not shown")
        new.tap()
        let field = app.textFields["workout.name.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No name sheet")
        field.tap()
        field.typeText("Costas")
        app.buttons["workout.name.save"].tap()
        waitForEditor(of: "Costas", in: app)
        XCTAssertTrue(waitForToast("Treino criado com 1 exercício", in: app), "No Treino criado com 1 exercício")
        XCTAssertTrue(headers.firstMatch.label.hasPrefix("Remada Curvada (Barra),"), "Exercise: \(headers.firstMatch.label)")
    }
}
