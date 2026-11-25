import XCTest

/// The exercises of the user's own ("Exercícios próprios"): the form from "+ Novo", from the search that
/// finds nothing and from the exercise picker; the names taken; the muscles; editing, duplicating and the
/// user's version of a library exercise; archiving, restoring and deleting; Graviton; and the form with
/// large text. The screenshots 118 to 126 are those of the prototype's states (`ci/prototype-references.json`).
final class CustomExerciseUITests: IronFlowUITestCase {
    /// The prototype's exercise of the user's own, with its muscles, and its other one.
    private let puxada = "own-exercise:Puxada na Máquina Articulada:back:machine:lever:lats:biceps|upperBack"
    private let pendulo = "own-exercise:Agachamento Pêndulo:quadriceps:machine:lever:quadriceps:glutes|adductors"
    private let prototypeToday = ["-ui-today", "2026-10-16"]

    // MARK: - Helpers

    @MainActor
    private func waitForForm(titled title: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let header = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "exerciseForm.title", title)).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 15), "Form “\(title)” not shown", file: file, line: line)
    }

    @MainActor
    private func waitForExerciseScreen(of name: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(exerciseTitle(name, in: app).waitForExistence(timeout: 20), "Exercise screen of \(name) not shown", file: file, line: line)
    }

    /// The title of the exercise screen of `name`, read by one query.
    @MainActor
    private func exerciseTitle(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label == %@", "exercise.title", name))
            .firstMatch
    }

    /// Taps a card of the Exercícios tab and waits for the exercise screen. A tap on a slow machine can be
    /// lost, as on the tabs (run 45661838939: 19,5 s from the launch to the automation, and the card still
    /// on the list 20 s after the tap), so when the screen has not opened in 5 s and the card can still be
    /// tapped, it is tapped once more. Nothing waits when the first tap works.
    @MainActor
    private func openCard(_ card: XCUIElement, of name: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        card.tap()
        if !exerciseTitle(name, in: app).waitForExistence(timeout: 5), card.exists, card.isHittable {
            XCTContext.runActivity(named: "Tap lost: tapping the card once more") { _ in
                card.tap()
            }
        }
        waitForExerciseScreen(of: name, in: app, file: file, line: line)
    }

    /// Types `name` in the form's name field, after what it holds.
    @MainActor
    private func typeName(_ name: String, in app: XCUIApplication) {
        let field = app.textFields["exerciseForm.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No name field")
        field.tapAndWaitForKeyboardFocus()
        field.typeText(name)
        field.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Keyboard still shown")
    }

    /// Clears the form's name field and types `name`.
    @MainActor
    private func replaceName(with name: String, in app: XCUIApplication) {
        let field = app.textFields["exerciseForm.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No name field")
        field.tapAndWaitForKeyboardFocus()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        field.typeText(name)
        XCTAssertTrue(field.waitForValue(name), "The name holds \(String(describing: field.value))")
        field.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Keyboard still shown")
    }

    /// Taps a chip of the form, bringing it above the bottom bar first.
    @MainActor
    private func tapChip(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let chip = app.buttons[identifier]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No chip \(identifier)", file: file, line: line)
        bringAboveTheBar(chip, in: app)
        chip.tap()
        XCTAssertTrue(waitForSelected(chip), "Chip \(identifier) not chosen", file: file, line: line)
    }

    /// Scrolls the form until `element` is above the bottom bar, which covers the end of the form.
    @MainActor
    private func bringAboveTheBar(_ element: XCUIElement, in app: XCUIApplication) {
        let save = app.buttons["exerciseForm.save"]
        var swipes = 0
        while swipes < 6, element.frame.maxY > save.frame.minY - 60 {
            app.swipeUp(velocity: .slow)
            _ = waitUntilSettled(element)
            swipes += 1
        }
    }

    @MainActor
    private func waitForSelected(_ element: XCUIElement) -> Bool {
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: element)
        return XCTWaiter().wait(for: [selected], timeout: 10) == .completed
    }

    /// Opens the sheet of the main or secondary muscles.
    @MainActor
    private func openMuscles(_ kind: String, in app: XCUIApplication) {
        let row = app.buttons["exerciseForm.\(kind)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No muscles row \(kind)")
        bringAboveTheBar(row, in: app)
        row.tap()
        XCTAssertTrue(app.buttons["muscles.done"].waitForExistence(timeout: 10), "The muscles sheet did not open")
    }

    @MainActor
    private func closeMuscles(in app: XCUIApplication) {
        app.buttons["muscles.done"].tap()
        XCTAssertTrue(app.buttons["muscles.done"].waitForNonExistence(timeout: 10), "The muscles sheet did not close")
    }

    /// Saves the form and waits for it to close.
    @MainActor
    private func save(_ title: String, in app: XCUIApplication) {
        let save = app.buttons["exerciseForm.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "No save button")
        XCTAssertEqual(save.label, title)
        XCTAssertTrue(save.isEnabled, "\(title) is not enabled")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 15), "The form did not close")
    }

    /// Closes the question of "Cancelar" without discarding. iOS 26 shows it with "Descartar" only (no
    /// "Continuar editando" button, run 45544972877): it closes by tapping outside it, on the title of the
    /// form. If the system shows the button, it is tapped.
    @MainActor
    private func keepEditing(in app: XCUIApplication) {
        let discard = app.buttons["Descartar"]
        XCTAssertTrue(discard.waitForExistence(timeout: 10), "No Descartar in the question")
        let keep = app.buttons["Continuar editando"]
        if keep.exists {
            keep.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        XCTAssertTrue(discard.waitForNonExistence(timeout: 10), "The question did not close")
        XCTAssertTrue(app.buttons["exerciseForm.save"].exists, "The form closed")
    }

    @MainActor
    private func openMenuItem(_ label: String, in app: XCUIApplication) {
        let menu = app.buttons["exercise.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "No ⋯ on the exercise screen")
        menu.tap()
        // The menu item, not a button of the screen with the same name ("Restaurar" of the archived card).
        let item = app.buttons.matching(NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH %@)", label, "exercise.")).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10), "No “\(label)” in the menu")
        item.tap()
    }

    /// On the Exercícios tab: searches and opens the exercise.
    @MainActor
    private func openExercise(_ name: String, search: String, in app: XCUIApplication) {
        let field = app.textFields["exercises.search"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Search field not found")
        field.tapAndWaitForKeyboardFocus()
        field.typeText(search)
        XCTAssertTrue(field.waitForValue(search), "The search field holds \(String(describing: field.value))")
        field.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Keyboard still shown")
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "exercises.card", "\(name), "))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No card for \(name)")
        openCard(card, of: name, in: app)
    }

    @MainActor
    private func openMine(in app: XCUIApplication) {
        let mine = app.buttons["exercises.filter.mine"]
        XCTAssertTrue(mine.waitForExistence(timeout: 10), "No Meus")
        tapFilter(mine, changing: element("exercises.count", in: app))
        XCTAssertTrue(waitForSelected(mine), "Meus not chosen")
    }

    // MARK: - Creating

    @MainActor
    func testCreateFromTheTabOnAMachine() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", extraArguments: longToastArguments)
        app.buttons["exercises.new"].tap()
        waitForForm(titled: "Novo exercício", in: app)
        XCTAssertEqual(element("exerciseForm.missing", in: app).label, "Falta: nome, grupo e equipamento.")
        XCTAssertFalse(app.buttons["exerciseForm.save"].isEnabled, "Criar exercício enabled with nothing filled")
        XCTAssertFalse(element("exerciseForm.machine.unknown", in: app).exists, "TIPO DE MÁQUINA without the machine")
        attachScreenshot(named: "118-new-exercise", of: app)

        typeName("Remada Cavalinho (Smart Fit)", in: app)
        tapChip("exerciseForm.group.upperBack", in: app)
        XCTAssertEqual(element("exerciseForm.missing", in: app).label, "Falta: equipamento.")
        tapChip("exerciseForm.equipment.machine", in: app)
        XCTAssertFalse(element("exerciseForm.missing", in: app).exists, "Something still missing")
        // The kind of machine, with "Não sei" chosen, and Graviton's hint only with Graviton.
        XCTAssertTrue(waitForSelected(app.buttons["exerciseForm.machine.unknown"]), "Não sei not chosen")
        tapChip("exerciseForm.machine.graviton", in: app)
        XCTAssertTrue(element("exerciseForm.gravitonHint", in: app).waitForExistence(timeout: 10), "No hint of the Graviton")
        tapChip("exerciseForm.machine.lever", in: app)
        XCTAssertTrue(element("exerciseForm.gravitonHint", in: app).waitForNonExistence(timeout: 10), "Graviton's hint with another kind")
        // "O que é cada tipo" says to choose, with ESTE on the kind chosen.
        let info = app.buttons["exerciseForm.machineInfo"]
        bringAboveTheBar(info, in: app)
        info.tap()
        XCTAssertTrue(element("machineTypes.explanation", in: app).waitForExistence(timeout: 10), "No Tipos de máquina")
        XCTAssertEqual(element("machineTypes.explanation", in: app).label, "Escolha o tipo da máquina que você usa. Se não souber, deixe “Não sei”.")
        XCTAssertTrue(element("machineTypes.current", in: app).label.hasPrefix("Articulada (anilhas)"), "ESTE not on Articulada")
        app.buttons["machineTypes.done"].tap()
        XCTAssertTrue(app.buttons["machineTypes.done"].waitForNonExistence(timeout: 10), "Tipos de máquina did not close")

        // The main muscles come from the group; Dorsais and Bíceps become the secondary ones.
        XCTAssertTrue(app.buttons["exerciseForm.primary"].label.hasSuffix("Costas superiores"), "Main muscles: \(app.buttons["exerciseForm.primary"].label)")
        XCTAssertTrue(element("exerciseForm.groupHint", in: app).exists, "No hint that the group filled the muscles")
        openMuscles("secondary", in: app)
        XCTAssertFalse(app.buttons["muscles.chip.upperBack"].isEnabled, "A main muscle can be chosen as secondary")
        app.buttons["muscles.chip.lats"].tap()
        app.buttons["muscles.chip.biceps"].tap()
        XCTAssertTrue(waitForSelected(app.buttons["muscles.chip.biceps"]), "Bíceps not chosen")
        attachScreenshot(named: "120-muscles-sheet", of: app)
        closeMuscles(in: app)
        XCTAssertTrue(app.buttons["exerciseForm.secondary"].label.hasSuffix("Dorsais, Bíceps"), "Secondary: \(app.buttons["exerciseForm.secondary"].label)")
        XCTAssertFalse(element("exerciseForm.groupHint", in: app).exists, "The hint stays after changing the muscles")
        scrollToTop(in: app)
        attachScreenshot(named: "119-new-exercise-machine", of: app)

        save("Criar exercício", in: app)
        waitForExerciseScreen(of: "Remada Cavalinho (Smart Fit)", in: app)
        XCTAssertTrue(waitForToast("Exercício criado", in: app), "No Exercício criado")
        XCTAssertEqual(element("exercise.subtitle", in: app).label, "Costas superiores · Máquina")
        XCTAssertEqual(element("exercise.badge", in: app).label, "MEU")
        XCTAssertTrue(element("exercise.machine", in: app).label.hasPrefix("Articulada (anilhas)"), "The kind of machine chosen is not shown")
        XCTAssertTrue(element("exercise.muscles", in: app).label.hasPrefix("Músculos principais: Costas superiores. Secundários: Dorsais, Bíceps."),
                      "Muscles: \(element("exercise.muscles", in: app).label)")

        // Back on the list: the count has it, and it is found by its equipment.
        app.buttons["exercise.back"].tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.total", in: app), toBe: "421 exercícios"), "Count without the new exercise")
    }

    @MainActor
    func testCreateWithTheFiltersAndFromTheEmptySearch() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", extraArguments: longToastArguments)
        tapFilter(app.buttons["exercises.filter.chest"], changing: element("exercises.count", in: app))
        let dumbbells = app.buttons["exercises.equipment.dumbbell"]
        XCTAssertTrue(dumbbells.waitForExistence(timeout: 10), "No Halteres")
        tapFilter(dumbbells, changing: element("exercises.count", in: app))

        // "+ Novo" brings the filters chosen; leaving without a change asks nothing.
        app.buttons["exercises.new"].tap()
        waitForForm(titled: "Novo exercício", in: app)
        XCTAssertTrue(app.buttons["exerciseForm.group.chest"].isSelected, "Peito not chosen from the filter")
        XCTAssertTrue(app.buttons["exerciseForm.equipment.dumbbell"].isSelected, "Halteres not chosen from the filter")
        XCTAssertEqual(element("exerciseForm.missing", in: app).label, "Falta: nome.")
        app.buttons["exerciseForm.cancel"].tap()
        XCTAssertTrue(app.buttons["exerciseForm.save"].waitForNonExistence(timeout: 10), "Cancelar without a change asked something")

        // The search that finds nothing offers to create it, with the name and the filters.
        let field = app.textFields["exercises.search"]
        field.tapAndWaitForKeyboardFocus()
        field.typeText("Crucifixo Sentado Livre")
        XCTAssertTrue(field.waitForValue("Crucifixo Sentado Livre"), "Search not typed")
        field.typeText("\n")
        let create = app.buttons["exercises.empty.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No + Criar in the empty search")
        XCTAssertEqual(create.label, "+ Criar \"Crucifixo Sentado Livre\"")
        create.tap()
        waitForForm(titled: "Novo exercício", in: app)
        XCTAssertEqual(app.textFields["exerciseForm.name"].value as? String, "Crucifixo Sentado Livre")
        XCTAssertTrue(app.buttons["exerciseForm.group.chest"].isSelected, "Peito not chosen")
        save("Criar exercício", in: app)
        waitForExerciseScreen(of: "Crucifixo Sentado Livre", in: app)
        XCTAssertEqual(element("exercise.subtitle", in: app).label, "Peito · Halteres")
        XCTAssertTrue(element("exercise.muscles", in: app).label.hasPrefix("Músculos principais: Peitoral."), "Muscles: \(element("exercise.muscles", in: app).label)")
    }

    @MainActor
    func testCreateFromThePickerComesBackChosen() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Supino Reto (Barra)"], extraArguments: longToastArguments)
        openWorkout(named: "Push", in: app)
        let add = app.buttons["workout.addExercises"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "No Adicionar exercícios")
        add.tap()
        // Meus is not offered without an exercise of the user's own.
        XCTAssertTrue(app.textFields["picker.search"].waitForExistence(timeout: 10), "No picker")
        XCTAssertFalse(app.buttons["picker.filter.mine"].exists, "Meus without an exercise of the user's own")
        searchPicker(for: "Remada Smart", in: app)
        let create = app.buttons["picker.empty.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No + Criar in the picker")
        create.tap()
        waitForForm(titled: "Novo exercício", in: app)
        tapChip("exerciseForm.group.upperBack", in: app)
        tapChip("exerciseForm.equipment.other", in: app)
        save("Criar exercício", in: app)

        // Back on the picker: the search with its name, the filters off and the new exercise chosen.
        XCTAssertTrue(waitForToast("Exercício criado e marcado", in: app), "No Exercício criado e marcado")
        let search = app.textFields["picker.search"]
        XCTAssertEqual(search.value as? String, "Remada Smart")
        XCTAssertTrue(app.buttons["picker.filter.all"].isSelected, "The filters are not Todos")
        let card = pickerCard("Remada Smart", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The new exercise is not in the picker")
        XCTAssertTrue(card.isSelected, "The new exercise is not chosen")
        XCTAssertEqual(app.buttons["picker.add"].label, "Adicionar (1)")
        app.buttons["picker.add"].tap()
        let added = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Remada Smart")).firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: 10), "The new exercise is not in the workout")
    }

    @MainActor
    func testNamesTakenAndCancel() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", seed: [puxada + ":archived"])
        app.buttons["exercises.new"].tap()
        waitForForm(titled: "Novo exercício", in: app)

        typeName("supino reto (BARRA)", in: app)
        let error = element("exerciseForm.nameError", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 10), "No message for a name taken")
        XCTAssertEqual(error.label, "Já existe um exercício com esse nome.")
        tapChip("exerciseForm.group.chest", in: app)
        tapChip("exerciseForm.equipment.barbell", in: app)
        XCTAssertFalse(app.buttons["exerciseForm.save"].isEnabled, "Criar exercício enabled with a name taken")

        replaceName(with: "puxada na maquina articulada", in: app)
        XCTAssertTrue(waitForLabel(of: error, toBe: "Você já tem “Puxada na Máquina Articulada” arquivado. Restaure em Exercícios › Meus ou use outro nome."),
                      "Message for an archived name: \(error.label)")
        XCTAssertFalse(app.buttons["exerciseForm.save"].isEnabled, "Criar exercício enabled with an archived name")

        replaceName(with: "Puxada Nova", in: app)
        XCTAssertTrue(error.waitForNonExistence(timeout: 10), "The message stays with a free name")
        XCTAssertTrue(app.buttons["exerciseForm.save"].isEnabled, "Criar exercício not enabled")

        // Cancelar with changes asks; closing the question stays, "Descartar" leaves.
        app.buttons["exerciseForm.cancel"].tap()
        XCTAssertTrue(element(labelStartingWith: "Descartar exercício?", in: app).waitForExistence(timeout: 10), "No question before discarding")
        XCTAssertTrue(app.staticTexts["O exercício não será criado."].exists, "No message of the question")
        keepEditing(in: app)
        XCTAssertEqual(app.textFields["exerciseForm.name"].value as? String, "Puxada Nova")
        app.buttons["exerciseForm.cancel"].tap()
        confirmationButton("Descartar", title: "Descartar exercício?", in: app).tap()
        XCTAssertTrue(app.buttons["exerciseForm.save"].waitForNonExistence(timeout: 10), "The form did not close")
        XCTAssertEqual(element("exercises.total", in: app).label, "420 exercícios")
    }

    @MainActor
    func testMusclesFollowTheGroupUntilChanged() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")
        app.buttons["exercises.new"].tap()
        waitForForm(titled: "Novo exercício", in: app)
        typeName("Elevação Frontal Livre", in: app)
        tapChip("exerciseForm.group.shoulders", in: app)
        XCTAssertTrue(app.buttons["exerciseForm.primary"].label.hasSuffix("Deltoide anterior, Deltoide lateral, Deltoide posterior"),
                      "Main muscles: \(app.buttons["exerciseForm.primary"].label)")
        tapChip("exerciseForm.group.chest", in: app)
        XCTAssertTrue(app.buttons["exerciseForm.primary"].label.hasSuffix("Peitoral"), "The main muscles did not follow the group")

        // Changing them by hand: the group no longer changes them.
        openMuscles("primary", in: app)
        app.buttons["muscles.chip.chest"].tap()
        app.buttons["muscles.chip.frontDelts"].tap()
        closeMuscles(in: app)
        XCTAssertTrue(app.buttons["exerciseForm.primary"].label.hasSuffix("Deltoide anterior"), "Main: \(app.buttons["exerciseForm.primary"].label)")
        tapChip("exerciseForm.group.shoulders", in: app)
        XCTAssertTrue(app.buttons["exerciseForm.primary"].label.hasSuffix("Deltoide anterior"), "Changing the group changed muscles chosen by hand")

        // A main muscle is blocked in the secondary ones, and back.
        openMuscles("secondary", in: app)
        let blocked = app.buttons["muscles.chip.frontDelts"]
        XCTAssertFalse(blocked.isEnabled, "A main muscle can be secondary")
        XCTAssertTrue(blocked.label.contains("principal"), "The blocked muscle does not say principal: \(blocked.label)")
        app.buttons["muscles.chip.triceps"].tap()
        closeMuscles(in: app)
        openMuscles("primary", in: app)
        XCTAssertFalse(app.buttons["muscles.chip.triceps"].isEnabled, "A secondary muscle can be main")
        XCTAssertTrue(app.buttons["muscles.chip.triceps"].label.contains("secundário"), "The blocked muscle does not say secundário")
        // Without a main muscle, it is missing.
        app.buttons["muscles.chip.frontDelts"].tap()
        closeMuscles(in: app)
        tapChip("exerciseForm.equipment.dumbbell", in: app)
        XCTAssertEqual(element("exerciseForm.missing", in: app).label, "Falta: músculo principal.")
        XCTAssertFalse(app.buttons["exerciseForm.save"].isEnabled, "Criar exercício enabled without a main muscle")
    }

    @MainActor
    func testDoubleTapCreatesOneExercise() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")
        app.buttons["exercises.new"].tap()
        waitForForm(titled: "Novo exercício", in: app)
        typeName("Toque Duplo", in: app)
        tapChip("exerciseForm.group.abs", in: app)
        tapChip("exerciseForm.equipment.other", in: app)
        let save = app.buttons["exerciseForm.save"]
        XCTAssertTrue(save.isEnabled, "Criar exercício not enabled")
        save.doubleTap()
        waitForExerciseScreen(of: "Toque Duplo", in: app)
        app.buttons["exercise.back"].tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.total", in: app), toBe: "421 exercícios"), "Not exactly one exercise created: \(element("exercises.total", in: app).label)")
        openMine(in: app)
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "1 exercício"), "Meus: \(element("exercises.count", in: app).label)")
    }

    @MainActor
    func testLargeTextKeepsTheFormReadable() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let new = app.buttons["exercises.new"]
        XCTAssertTrue(new.waitForExistence(timeout: 10), "No + Novo")
        new.tap()
        waitForForm(titled: "Novo exercício", in: app)
        let screen = app.windows.firstMatch.frame
        let elements = [
            ("cancel", app.buttons["exerciseForm.cancel"]),
            ("name", app.textFields["exerciseForm.name"]),
            ("first group", app.buttons["exerciseForm.group.chest"]),
            ("save", app.buttons["exerciseForm.save"]),
        ]
        for (name, element) in elements {
            XCTAssertTrue(element.exists, "No \(name)")
            XCTAssertTrue(element.frame.minX >= screen.minX && element.frame.maxX <= screen.maxX, "The \(name) is not on the screen: \(element.frame)")
        }
        XCTAssertLessThan(app.textFields["exerciseForm.name"].frame.maxY, app.buttons["exerciseForm.group.chest"].frame.minY, "The name and the chips overlap")
        attachScreenshot(named: "126-new-exercise-large-text", of: app)
    }

    // MARK: - Editing and copies

    @MainActor
    func testEditDuplicateAndMyVersion() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", seed: [puxada, "workout:Pull:Puxada na Máquina Articulada"], extraArguments: longToastArguments)
        openExercise("Puxada na Máquina Articulada", search: "puxada articulada", in: app)
        XCTAssertEqual(element("exercise.subtitle", in: app).label, "Dorsais · Máquina")

        // Editar: the form of the exercise, "Salvar" only after a change.
        openMenuItem("Editar", in: app)
        waitForForm(titled: "Editar exercício", in: app)
        XCTAssertTrue(app.buttons["exerciseForm.machine.lever"].isSelected, "Articulada not chosen")
        XCTAssertTrue(app.buttons["exerciseForm.secondary"].label.hasSuffix("Bíceps, Costas superiores"), "Secondary: \(app.buttons["exerciseForm.secondary"].label)")
        XCTAssertFalse(app.buttons["exerciseForm.save"].isEnabled, "Salvar enabled without a change")
        attachScreenshot(named: "122-edit-exercise", of: app)
        // Leaving with a change asks to discard the changes.
        replaceName(with: "Puxada Articulada (Smart Fit)", in: app)
        app.buttons["exerciseForm.cancel"].tap()
        XCTAssertTrue(element(labelStartingWith: "Descartar alterações?", in: app).waitForExistence(timeout: 10), "No question before discarding the changes")
        XCTAssertTrue(app.staticTexts["As mudanças não serão salvas."].exists, "No message of the question")
        keepEditing(in: app)
        save("Salvar", in: app)
        waitForExerciseScreen(of: "Puxada Articulada (Smart Fit)", in: app)
        XCTAssertTrue(waitForToast("Exercício salvo", in: app), "No Exercício salvo")

        // Duplicar: the copy with " 2", a note, and its own screen in the place of this one.
        openMenuItem("Duplicar", in: app)
        waitForForm(titled: "Duplicar exercício", in: app)
        XCTAssertEqual(app.textFields["exerciseForm.name"].value as? String, "Puxada Articulada (Smart Fit) 2")
        XCTAssertTrue(element("exerciseForm.copyNote", in: app).label.hasPrefix("Cópia de Puxada Articulada (Smart Fit)"), "Note: \(element("exerciseForm.copyNote", in: app).label)")
        save("Criar cópia", in: app)
        waitForExerciseScreen(of: "Puxada Articulada (Smart Fit) 2", in: app)
        XCTAssertTrue(waitForToast("Cópia criada", in: app), "No Cópia criada")
        XCTAssertTrue(element("exercise.neverDone", in: app).waitForExistence(timeout: 10), "The copy has a history")
        XCTAssertEqual(app.buttons["exercise.back"].label, "Exercícios")
        app.buttons["exercise.back"].tap()

        // The planned workout shows the new name.
        openTab("Treinos", in: app)
        openWorkout(named: "Pull", in: app)
        XCTAssertTrue(element(labelStartingWith: "Puxada Articulada (Smart Fit)", in: app).waitForExistence(timeout: 10), "The workout does not show the new name")
        goBackFromEditor(in: app)

        // Criar minha versão of a library exercise.
        openTab("Exercícios", in: app)
        let clear = app.buttons["exercises.search.clear"]
        if clear.exists {
            clear.tap()
        }
        openExercise("Leg Press 45° (Máquina)", search: "leg press 45", in: app)
        openMenuItem("Criar minha versão", in: app)
        waitForForm(titled: "Minha versão", in: app)
        XCTAssertEqual(app.textFields["exerciseForm.name"].value as? String, "Leg Press 45° (Máquina) 2")
        XCTAssertTrue(app.buttons["exerciseForm.machine.track"].isSelected, "Trilho not copied")
        XCTAssertTrue(element("exerciseForm.copyNote", in: app).label.hasPrefix("Sua versão de Leg Press 45° (Máquina)"), "Note: \(element("exerciseForm.copyNote", in: app).label)")
        attachScreenshot(named: "121-my-version", of: app)
        save("Criar minha versão", in: app)
        waitForExerciseScreen(of: "Leg Press 45° (Máquina) 2", in: app)
        XCTAssertTrue(waitForToast("Sua versão foi criada", in: app), "No Sua versão foi criada")
        XCTAssertEqual(element("exercise.badge", in: app).label, "MEU")
    }

    // MARK: - Archiving, restoring and deleting

    @MainActor
    func testArchiveLeavesTheWorkoutAndRestore() throws {
        continueAfterFailure = false
        let app = launchOnTab(
            "Exercícios",
            seed: [puxada, pendulo, "prototype-history-own", "workout:Costas:Puxada na Máquina Articulada|Remada Curvada (Barra)"],
            extraArguments: prototypeToday + longToastArguments
        )
        openExercise("Puxada na Máquina Articulada", search: "puxada articulada", in: app)
        XCTAssertEqual(element("exercise.badge", in: app).label, "MEU")
        XCTAssertEqual(element("exercise.history.count", in: app).label, "6 treinos")
        attachScreenshot(named: "123-exercise-mine", of: app)

        // With history: Arquivar, and the workout it leaves.
        openMenuItem("Arquivar exercício", in: app)
        XCTAssertTrue(element(labelStartingWith: "Ele sai da lista de exercícios e do treino Costas. O histórico e os recordes continuam guardados", in: app)
            .waitForExistence(timeout: 10), "The question does not say what happens")
        confirmationButton("Arquivar exercício", title: "Arquivar “Puxada na Máquina Articulada”?", in: app).tap()
        XCTAssertTrue(element("exercise.archived", in: app).waitForExistence(timeout: 10), "No Exercício arquivado")
        XCTAssertTrue(waitForToast("Exercício arquivado", in: app), "No Exercício arquivado notice")
        XCTAssertEqual(element("exercise.badge", in: app).label, "ARQUIVADO")
        XCTAssertEqual(element("exercise.history.count", in: app).label, "6 treinos")
        XCTAssertTrue(waitForToastToLeave(in: app), "The notice did not leave")
        attachScreenshot(named: "124-exercise-archived", of: app)

        // Meus: it is at the end, under ARQUIVADOS, and out of the count.
        app.buttons["exercise.back"].tap()
        let clear = app.buttons["exercises.search.clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 10), "No clear button")
        clear.tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.total", in: app), toBe: "421 exercícios"), "The archived exercise counted")
        openMine(in: app)
        XCTAssertTrue(element("exercises.archived.title", in: app).waitForExistence(timeout: 10), "No ARQUIVADOS")
        XCTAssertEqual(element("exercises.count", in: app).label, "1 exercício")
        let archivedCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "exercises.card", "Puxada na Máquina Articulada, "))
            .firstMatch
        XCTAssertTrue(archivedCard.label.hasSuffix("Exercício arquivado"), "Archived card: \(archivedCard.label)")
        attachScreenshot(named: "125-exercises-mine-archived", of: app)

        // It left the workout.
        openTab("Treinos", in: app)
        openWorkout(named: "Costas", in: app)
        XCTAssertTrue(element(labelStartingWith: "Remada Curvada (Barra)", in: app).waitForExistence(timeout: 10), "The other exercise left too")
        XCTAssertFalse(element(labelStartingWith: "Puxada na Máquina Articulada", in: app).exists, "The archived exercise is still in the workout")
        goBackFromEditor(in: app)

        // Restaurar: back in the list, not in the workout.
        openTab("Exercícios", in: app)
        openCard(archivedCard, of: "Puxada na Máquina Articulada", in: app)
        app.buttons["exercise.restore"].tap()
        XCTAssertTrue(waitForToast("Exercício restaurado", in: app), "No Exercício restaurado")
        XCTAssertTrue(element("exercise.archived", in: app).waitForNonExistence(timeout: 10), "Still archived")
        XCTAssertEqual(element("exercise.badge", in: app).label, "MEU")
        app.buttons["exercise.back"].tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.total", in: app), toBe: "422 exercícios"), "The restored exercise is not counted")
    }

    @MainActor
    func testArchivedExerciseMenuAndNameRules() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", seed: ["own-exercise:Meu Supino:chest:barbell::chest::archived"], extraArguments: longToastArguments)
        // Only archived: "Meus" is offered and shows it alone, under ARQUIVADOS, without a count.
        openMine(in: app)
        XCTAssertTrue(element("exercises.archived.title", in: app).waitForExistence(timeout: 10), "No ARQUIVADOS")
        XCTAssertFalse(element("exercises.count", in: app).exists, "A count with only archived exercises")
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "exercises.card", "Meu Supino, "))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No archived card")
        openCard(card, of: "Meu Supino", in: app)
        XCTAssertEqual(element("exercise.badge", in: app).label, "ARQUIVADO")

        // The menu of an archived exercise: Restaurar, Editar and Duplicar, and nothing that removes it.
        app.buttons["exercise.menu"].tap()
        XCTAssertTrue(app.buttons["Restaurar"].waitForExistence(timeout: 10), "No Restaurar")
        XCTAssertTrue(app.buttons["Editar"].exists && app.buttons["Duplicar"].exists, "No Editar or Duplicar")
        XCTAssertFalse(app.buttons["Arquivar exercício"].exists || app.buttons["Apagar exercício"].exists, "Removing offered again")
        // An archived exercise cannot take a name already used.
        app.buttons["Editar"].tap()
        waitForForm(titled: "Editar exercício", in: app)
        replaceName(with: "Supino Reto (Barra)", in: app)
        XCTAssertTrue(element("exerciseForm.nameError", in: app).waitForExistence(timeout: 10), "An archived exercise takes a library name")
        XCTAssertFalse(app.buttons["exerciseForm.save"].isEnabled, "Salvar enabled with a name taken")
        app.buttons["exerciseForm.cancel"].tap()
        confirmationButton("Descartar", title: "Descartar alterações?", in: app).tap()
        XCTAssertTrue(app.buttons["exerciseForm.save"].waitForNonExistence(timeout: 10), "The form did not close")

        // Restaurar from the menu, once.
        openMenuItem("Restaurar", in: app)
        XCTAssertTrue(waitForToast("Exercício restaurado", in: app), "No Exercício restaurado")
        XCTAssertTrue(element("exercise.archived", in: app).waitForNonExistence(timeout: 10), "Still archived")
        app.buttons["exercise.back"].tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.total", in: app), toBe: "421 exercícios"), "The restored exercise is not counted")
        XCTAssertFalse(element("exercises.archived.title", in: app).exists, "ARQUIVADOS without an archived exercise")
    }

    @MainActor
    func testDeleteWithoutHistoryGoesBack() throws {
        continueAfterFailure = false
        let app = launchOnTab(
            "Exercícios",
            seed: [pendulo, "workout:Pernas:Agachamento Livre (Barra)|Agachamento Pêndulo|Cadeira Extensora (Máquina)"],
            extraArguments: longToastArguments
        )
        openExercise("Agachamento Pêndulo", search: "pendulo", in: app)
        openMenuItem("Apagar exercício", in: app)
        XCTAssertTrue(element(labelStartingWith: "Ele sai do treino Pernas e é apagado. Não dá para desfazer.", in: app).waitForExistence(timeout: 10),
                      "The question does not say what happens")
        confirmationButton("Apagar exercício", title: "Apagar “Agachamento Pêndulo”?", in: app).tap()

        // Back where it opened from, without it.
        XCTAssertTrue(app.textFields["exercises.search"].waitForExistence(timeout: 15), "Not back on the list")
        XCTAssertTrue(waitForToast("Exercício apagado", in: app), "No Exercício apagado")
        let clear = app.buttons["exercises.search.clear"]
        if clear.exists {
            clear.tap()
        }
        XCTAssertTrue(waitForLabel(of: element("exercises.total", in: app), toBe: "420 exercícios"), "Still counted")
        XCTAssertFalse(app.buttons["exercises.filter.mine"].exists, "Meus without an exercise of the user's own")

        // It left the workout, whose other exercises keep their order.
        openTab("Treinos", in: app)
        openWorkout(named: "Pernas", in: app)
        let exercises = app.descendants(matching: .any).matching(identifier: "workout.exercise")
        XCTAssertTrue(exercises.firstMatch.waitForExistence(timeout: 10), "No exercises in the workout")
        let labels = exercises.allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(labels.count, 2, "Exercises: \(labels)")
        XCTAssertTrue(labels[0].hasPrefix("Agachamento Livre (Barra)") && labels[1].hasPrefix("Cadeira Extensora (Máquina)"), "Exercises: \(labels)")
    }

    // MARK: - Graviton

    @MainActor
    func testCustomGravitonInTheDetail() throws {
        continueAfterFailure = false
        let app = launchOnTab(
            "Exercícios",
            seed: [
                "own-exercise:Minha Barra Graviton:back:machine:graviton:lats:biceps",
                "workout:Pull:Minha Barra Graviton",
                "finished:Pull:2",
            ],
            extraArguments: longToastArguments
        )
        openExercise("Minha Barra Graviton", search: "graviton minha", in: app)
        XCTAssertTrue(element("exercise.machine", in: app).label.hasPrefix("Graviton (contrapeso)"), "No Graviton row")
        XCTAssertTrue(element("exercise.history.count", in: app).label.hasSuffix("kg é a ajuda"), "History: \(element("exercise.history.count", in: app).label)")
        XCTAssertEqual(app.buttons["exercise.chart.metric.0"].label, "Menor ajuda")

        // Another kind of machine with the screen open: the metrics change.
        openMenuItem("Editar", in: app)
        waitForForm(titled: "Editar exercício", in: app)
        tapChip("exerciseForm.machine.plates", in: app)
        save("Salvar", in: app)
        XCTAssertTrue(waitForToast("Exercício salvo", in: app), "No Exercício salvo")
        XCTAssertTrue(waitForLabel(of: app.buttons["exercise.chart.metric.0"], toBe: "Mais repetições"), "Metrics did not change: \(app.buttons["exercise.chart.metric.0"].label)")
        XCTAssertFalse(element("exercise.history.count", in: app).label.contains("ajuda"), "Still the help")
    }
}
