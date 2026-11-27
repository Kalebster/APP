import XCTest

/// The Exercícios tab in the approved model: one alphabetical list of the 103 base exercises (and the user's
/// own), with "Montar treino", a search, the group filters ("Todos", "Meus" and the groups), the common
/// equipment of the chosen group and "Limpar filtros". Runs on an in-memory store where the library is
/// installed at launch.
final class ExerciseListUITests: IronFlowUITestCase {
    @MainActor
    private func groupChip(_ key: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["exercises.filter.\(key)"]
    }

    @MainActor
    private func equipmentChip(_ key: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["exercises.equipment.\(key)"]
    }

    @MainActor
    private func cards(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "exercises.card")
    }

    @MainActor
    private func searchField(in app: XCUIApplication) -> XCUIElement {
        let field = app.textFields["exercises.search"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Search field not found")
        return field
    }

    /// The count of the filtered exercises, shown while a group or an equipment is chosen.
    @MainActor
    private func count(in app: XCUIApplication) -> XCUIElement {
        element("exercises.count", in: app)
    }

    /// Taps a chip of a row that scrolls sideways, first dragging the row until the chip is on the
    /// screen: the test does not scroll a SwiftUI row by itself. The tap is repeated if it is lost
    /// (`tapFilter`), so it waits for the count to change.
    @MainActor
    private func tapChip(_ chip: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "Chip not found: \(chip)")
        let screen = app.windows.firstMatch.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        var drags = 0
        while drags < 8, chip.frame.maxX > screen.maxX - 8 || chip.frame.minX < screen.minX + 8 {
            // Content moves left to bring a chip on the right, right to bring one on the left.
            let distance: CGFloat = chip.frame.maxX > screen.maxX - 8 ? -200 : 200
            let start = origin.withOffset(CGVector(dx: screen.midX, dy: chip.frame.midY))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: distance, dy: 0)))
            drags += 1
        }
        tapFilter(chip, changing: count(in: app))
    }

    /// Types in the search and waits until the field holds it, so a lost key shows as a wrong text.
    @MainActor
    private func search(_ text: String, in app: XCUIApplication) {
        let field = searchField(in: app)
        field.tapAndWaitForKeyboardFocus()
        field.typeText(text)
        XCTAssertTrue(field.waitForValue(text), "The search field holds \(String(describing: field.value)), not \(text)")
    }

    @MainActor
    func testAllExercisesAndGroupChips() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")

        XCTAssertTrue(element("exercises.total", in: app).waitForExistence(timeout: 10), "Header not shown")
        XCTAssertEqual(element("exercises.total", in: app).label, "103 exercícios")
        XCTAssertTrue(app.buttons["exercises.build"].exists, "No Montar treino")
        let all = groupChip("all", in: app)
        XCTAssertTrue(all.isSelected, "Todos is not selected at first")
        XCTAssertFalse(groupChip("mine", in: app).exists, "Meus shown without a custom exercise")
        XCTAssertFalse(groupChip("other", in: app).exists, "A group without exercises is offered")
        XCTAssertTrue(equipmentChip("plate", in: app).exists, "Not every equipment is offered for Todos")
        XCTAssertFalse(element("exercises.count", in: app).exists, "Count row shown without a filter")
        // Alphabetical, as in the model; each card is read as one item, with the base's common equipment.
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Abdominal, Abdômen, mais comum com Máquina, Polia, Anilha, Peso do corpo")
        XCTAssertEqual(cards(in: app).element(boundBy: 1).label, "Abdominal Bicicleta, Abdômen, mais comum com Peso do corpo")
        attachScreenshot(named: "70-exercises-all", of: app)

        let chest = groupChip("chest", in: app)
        tapFilter(chest, changing: count(in: app))
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "9 exercícios"), "Chest count not shown")
        XCTAssertTrue(chest.isSelected, "Peito is not selected")
        XCTAssertFalse(all.isSelected, "Todos is still selected")
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Crucifixo, Peito, mais comum com Halteres, Máquina, Polia, Elástico")
    }

    @MainActor
    func testEquipmentFollowsTheGroup() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")
        let chest = groupChip("chest", in: app)
        XCTAssertTrue(chest.waitForExistence(timeout: 10), "Peito not shown")
        tapFilter(chest, changing: count(in: app))

        // Only the common equipment of the chest bases: every one but Kettlebell, which they show in gray.
        for key in ["barbell", "dumbbell", "machine", "cable", "smith", "bodyweight", "band", "plate"] {
            XCTAssertTrue(equipmentChip(key, in: app).exists, "No \(key) for Peito")
        }
        XCTAssertFalse(equipmentChip("kettlebell", in: app).exists, "kettlebell offered for Peito")

        let dumbbell = equipmentChip("dumbbell", in: app)
        tapFilter(dumbbell, changing: count(in: app))
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "4 exercícios"), "Peito + Halteres count")
        XCTAssertTrue(dumbbell.isSelected, "Halteres is not selected")
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Crucifixo, Peito, mais comum com Halteres, Máquina, Polia, Elástico")
        XCTAssertEqual(cards(in: app).element(boundBy: 1).label, "Supino Declinado, Peito, mais comum com Barra, Halteres, Máquina, Máquina iso-lateral, Smith, Polia")
        attachScreenshot(named: "71-exercises-chest-dumbbells", of: app)

        // A second tap unselects it.
        tapFilter(dumbbell, changing: count(in: app))
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "9 exercícios"), "Halteres not unselected")
        XCTAssertFalse(dumbbell.isSelected, "Halteres still selected")

        // Kettlebell is common in Glúteos (Agachamento Sumô) and not in Peito; choosing Peito unselects it, and it
        // stays unselected.
        tapChip(groupChip("glutes", in: app), in: app)
        let kettlebell = equipmentChip("kettlebell", in: app)
        XCTAssertTrue(kettlebell.waitForExistence(timeout: 10), "No Kettlebell for Glúteos")
        tapChip(kettlebell, in: app)
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "1 exercício"), "Glúteos + Kettlebell count")
        tapChip(groupChip("chest", in: app), in: app)
        XCTAssertTrue(kettlebell.waitForNonExistence(timeout: 10), "Kettlebell offered for Peito")
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "9 exercícios"), "The equipment kept filtering Peito")
        tapChip(groupChip("glutes", in: app), in: app)
        XCTAssertTrue(kettlebell.waitForExistence(timeout: 10), "No Kettlebell for Glúteos")
        XCTAssertFalse(kettlebell.isSelected, "Kettlebell selected again")
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "6 exercícios"), "Glúteos count")
    }

    @MainActor
    func testClearFiltersKeepsTheSearch() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")
        search("supino", in: app)
        tapFilter(groupChip("chest", in: app), changing: count(in: app))
        tapFilter(equipmentChip("barbell", in: app), changing: count(in: app))
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "3 exercícios"), "Peito + Barra + supino count")

        tapFilter(app.buttons["exercises.clearFilters"], changing: count(in: app))

        XCTAssertTrue(element("exercises.count", in: app).waitForNonExistence(timeout: 10), "Count row still shown")
        XCTAssertTrue(groupChip("all", in: app).isSelected, "Todos not selected again")
        XCTAssertFalse(equipmentChip("barbell", in: app).isSelected, "Barra still selected")
        XCTAssertEqual(searchField(in: app).value as? String, "supino", "Limpar filtros cleared the search")
        // Every "supino" of every group again: the first is Supino Declinado.
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Supino Declinado, Peito, mais comum com Barra, Halteres, Máquina, Máquina iso-lateral, Smith, Polia")
    }

    @MainActor
    func testSearchWithoutAccentsAndWithoutResults() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")

        search("pelvica", in: app)
        XCTAssertTrue(waitForLabel(of: cards(in: app).element(boundBy: 0), toBe: "Elevação Pélvica, Glúteos, mais comum com Barra, Halteres, Máquina, Smith, Peso do corpo"))
        // Without the keyboard the one card of the search, and the place of more, are on the screen: the search
        // leaves only it; "Montar treino" is not shown while searching.
        searchField(in: app).typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Keyboard still shown")
        XCTAssertEqual(cards(in: app).count, 1)
        XCTAssertFalse(app.buttons["exercises.build"].exists, "Montar treino shown while searching")

        let clear = app.buttons["exercises.search.clear"]
        XCTAssertTrue(clear.exists, "No clear button with text")
        clear.tap()
        XCTAssertTrue(clear.waitForNonExistence(timeout: 10), "Clear button shown without text")
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Abdominal, Abdômen, mais comum com Máquina, Polia, Anilha, Peso do corpo")
        XCTAssertTrue(app.buttons["exercises.build"].waitForExistence(timeout: 10), "No Montar treino without a search")

        search("supino xyz", in: app)
        let empty = element("exercises.empty", in: app)
        XCTAssertTrue(empty.waitForExistence(timeout: 10), "No message without results")
        XCTAssertTrue(empty.label.contains("Nenhum exercício encontrado"), "Message: \(empty.label)")
        XCTAssertEqual(cards(in: app).count, 0)
        attachScreenshot(named: "72-exercises-no-results", of: app)

        // With a group chosen the count is shown: "0 exercícios", never "0 exercício".
        if app.keyboards.firstMatch.exists {
            searchField(in: app).typeText("\n")
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Keyboard still shown")
        }
        tapFilter(groupChip("chest", in: app), changing: count(in: app))
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "0 exercícios"), "Count without results: \(element("exercises.count", in: app).label)")
    }

    @MainActor
    func testNewGroupsAndSearchByWords() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")
        XCTAssertTrue(element("exercises.total", in: app).waitForExistence(timeout: 10), "Header not shown")

        // Every word of the search, in any order, in every group: the four "supino" bases with a common barbell,
        // Supino Fechado of Tríceps among them.
        let benchWithBarbell = [
            "Supino Declinado, Peito, mais comum com Barra, Halteres, Máquina, Máquina iso-lateral, Smith, Polia",
            "Supino Fechado, Tríceps, mais comum com Barra, Smith",
            "Supino Inclinado, Peito, mais comum com Barra, Halteres, Máquina, Máquina iso-lateral, Smith, Polia",
            "Supino Reto, Peito, mais comum com Barra, Halteres, Máquina, Máquina iso-lateral, Smith, Polia",
        ]
        let clear = app.buttons["exercises.search.clear"]
        for text in ["barra supino", "Supino  BARRA"] {
            if clear.exists {
                clear.tap()
                XCTAssertTrue(clear.waitForNonExistence(timeout: 10), "Search not cleared")
            }
            search(text, in: app)
            XCTAssertTrue(waitForLabel(of: cards(in: app).element(boundBy: 0), toBe: benchWithBarbell[0]), "Search '\(text)'")
            XCTAssertTrue(waitForLabel(of: cards(in: app).element(boundBy: 1), toBe: benchWithBarbell[1]), "Search '\(text)'")
            XCTAssertEqual((0..<benchWithBarbell.count).map { cards(in: app).element(boundBy: $0).label }, benchWithBarbell, "Search '\(text)'")
        }

        // The words and a group together: Peito leaves out Supino Fechado (Barra), of Tríceps.
        tapFilter(groupChip("chest", in: app), changing: count(in: app))
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "3 exercícios"), "Peito with the search")
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, benchWithBarbell[0])
        XCTAssertEqual(cards(in: app).element(boundBy: 1).label, benchWithBarbell[2])
        clear.tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "9 exercícios"), "Peito without the search")
        // Without the keyboard, which the search may keep after clearing it.
        if app.keyboards.firstMatch.exists {
            searchField(in: app).typeText("\n")
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "Keyboard still shown")
        }

        // Costas superiores, after Dorsais, and Adutores, near the end of the row that scrolls sideways.
        let upperBack = groupChip("upperBack", in: app)
        tapChip(upperBack, in: app)
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "8 exercícios"), "Costas superiores count")
        XCTAssertTrue(upperBack.isSelected, "Costas superiores is not selected")
        XCTAssertLessThan(groupChip("back", in: app).frame.maxX, upperBack.frame.minX, "Dorsais is not before Costas superiores")
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Remada, Costas superiores, mais comum com Halteres, Máquina, Máquina iso-lateral")

        let adductors = groupChip("adductors", in: app)
        tapChip(adductors, in: app)
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "2 exercícios"), "Adutores count")
        XCTAssertTrue(adductors.isSelected, "Adutores is not selected")
        XCTAssertEqual(cards(in: app).count, 2)
        XCTAssertEqual((0..<2).map { cards(in: app).element(boundBy: $0).label }, [
            "Adução de Quadril, Adutores, mais comum com Polia, Elástico",
            "Cadeira Adutora, Adutores, mais comum com Máquina",
        ])
        attachScreenshot(named: "104-exercises-adductors", of: app)
    }

    @MainActor
    func testMineShowsTheCustomExercise() throws {
        continueAfterFailure = false
        // The two exercises of the user's own of the prototype, on a machine.
        let app = launchOnTab("Exercícios", seed: [
            "own-exercise:Puxada na Máquina Articulada:back:machine:lever:lats:biceps|upperBack",
            "own-exercise:Agachamento Pêndulo:quadriceps:machine:lever:quadriceps:glutes|adductors",
        ])

        XCTAssertTrue(element("exercises.total", in: app).waitForExistence(timeout: 10), "Header not shown")
        XCTAssertEqual(element("exercises.total", in: app).label, "105 exercícios")
        let mine = groupChip("mine", in: app)
        XCTAssertTrue(mine.exists, "No Meus with a custom exercise")
        tapFilter(mine, changing: count(in: app))
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "2 exercícios"), "Meus count")
        XCTAssertTrue(mine.isSelected, "Meus is not selected")
        XCTAssertEqual(cards(in: app).count, 2)
        // The icon of its equipment, its group and its equipment, with MEU.
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Agachamento Pêndulo, Quadríceps, Máquina, Meu exercício")
        XCTAssertEqual(cards(in: app).element(boundBy: 1).label, "Puxada na Máquina Articulada, Dorsais, Máquina, Meu exercício")
        // Its equipment is offered, and nothing is archived.
        XCTAssertTrue(equipmentChip("machine", in: app).exists, "Máquina not offered for Meus")
        XCTAssertFalse(element("exercises.archived.title", in: app).exists, "ARQUIVADOS without an archived exercise")
        attachScreenshot(named: "73-exercises-mine", of: app)

        // With Halteres chosen in Dorsais, the exercise on a machine is not shown; with Máquina it is.
        tapFilter(groupChip("back", in: app), changing: count(in: app))
        let backCount = count(in: app).label
        tapChip(equipmentChip("machine", in: app), in: app)
        XCTAssertNotEqual(count(in: app).label, backCount)
        search("puxada articulada", in: app)
        XCTAssertTrue(cards(in: app).element(boundBy: 0).waitForExistence(timeout: 10), "The exercise of the user's own not found with Máquina")
        XCTAssertEqual(cards(in: app).count, 1)
    }

    @MainActor
    func testLargeTextKeepsTheExercisesOnScreen() throws {
        continueAfterFailure = false
        let app = launchOnTab(
            "Exercícios",
            seed: ["custom-exercise:Meu Supino:chest"],
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )
        XCTAssertTrue(element("exercises.total", in: app).waitForExistence(timeout: 10), "Header not shown")

        let screen = app.windows.firstMatch.frame
        let first = cards(in: app).element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 10), "No card")
        let elements = [
            ("total", element("exercises.total", in: app)),
            ("search", searchField(in: app)),
            ("Todos", groupChip("all", in: app)),
            ("first card", first),
        ]
        recordMeasurement(
            "Medição: Exercícios com o maior texto (tela de \(Int(screen.width)) pt)",
            elements.map { "\($0.0) \(Int($0.1.frame.minX))–\(Int($0.1.frame.maxX)) × \(Int($0.1.frame.minY))–\(Int($0.1.frame.maxY))" }.joined(separator: "; ")
        )
        for (name, element) in elements {
            XCTAssertTrue(element.exists, "No \(name)")
            XCTAssertTrue(
                element.frame.minX >= screen.minX && element.frame.maxX <= screen.maxX,
                "The \(name) is not on the screen: \(element.frame) on \(screen)"
            )
        }
        // Nothing overlaps: the search above the chips, and the cards one below the other.
        XCTAssertLessThan(searchField(in: app).frame.maxY, groupChip("all", in: app).frame.minY, "The search and the chips overlap")
        let second = cards(in: app).element(boundBy: 1)
        if second.exists {
            XCTAssertLessThanOrEqual(first.frame.maxY, second.frame.minY, "Cards overlap: \(first.frame) and \(second.frame)")
        }
        attachScreenshot(named: "74-exercises-large-text", of: app)
    }
}
