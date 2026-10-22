import XCTest

/// The Exercícios tab in the approved model: one alphabetical list with a search, the group filters
/// ("Todos", "Meus" and the groups), the equipment of the chosen group and "Limpar filtros".
/// Runs on an in-memory store where the 157 built-in exercises are installed at launch.
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

    /// Taps a chip of a row that scrolls sideways, first dragging the row until the chip is on the
    /// screen: the test does not scroll a SwiftUI row by itself.
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
        chip.tap()
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
        XCTAssertEqual(element("exercises.total", in: app).label, "157 exercícios")
        let all = groupChip("all", in: app)
        XCTAssertTrue(all.isSelected, "Todos is not selected at first")
        XCTAssertFalse(groupChip("mine", in: app).exists, "Meus shown without a custom exercise")
        XCTAssertFalse(groupChip("other", in: app).exists, "A group without exercises is offered")
        XCTAssertTrue(equipmentChip("plate", in: app).exists, "Not every equipment is offered for Todos")
        XCTAssertFalse(element("exercises.count", in: app).exists, "Count row shown without a filter")
        // Alphabetical, as in the model; each card is read as one item.
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Abdominal Bicicleta, Abdômen, Oblíquos, Peso do corpo")
        XCTAssertEqual(cards(in: app).element(boundBy: 1).label, "Abdominal com Anilha, Abdômen, Reto abdominal (parte superior), Anilha")
        attachScreenshot(named: "70-exercises-all", of: app)

        let chest = groupChip("chest", in: app)
        chest.tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "21 exercícios"), "Chest count not shown")
        XCTAssertTrue(chest.isSelected, "Peito is not selected")
        XCTAssertFalse(all.isSelected, "Todos is still selected")
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Crossover na Polia Alta, Peito, Peitoral inferior, Polia")
    }

    @MainActor
    func testEquipmentFollowsTheGroup() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")
        let chest = groupChip("chest", in: app)
        XCTAssertTrue(chest.waitForExistence(timeout: 10), "Peito not shown")
        chest.tap()

        // Only the equipment of the chest exercises.
        for key in ["barbell", "dumbbell", "machine", "cable", "smith", "bodyweight"] {
            XCTAssertTrue(equipmentChip(key, in: app).exists, "No \(key) for Peito")
        }
        for key in ["kettlebell", "band", "plate"] {
            XCTAssertFalse(equipmentChip(key, in: app).exists, "\(key) offered for Peito")
        }

        let dumbbell = equipmentChip("dumbbell", in: app)
        dumbbell.tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "6 exercícios"), "Peito + Halteres count")
        XCTAssertTrue(dumbbell.isSelected, "Halteres is not selected")
        XCTAssertEqual(cards(in: app).count, 6)
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Crucifixo Inclinado com Halteres, Peito, Peitoral superior, Halteres")
        attachScreenshot(named: "71-exercises-chest-dumbbells", of: app)

        // A second tap unselects it.
        dumbbell.tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "21 exercícios"), "Halteres not unselected")
        XCTAssertFalse(dumbbell.isSelected, "Halteres still selected")

        // Elástico exists only in Glúteos; choosing Peito unselects it, and it stays unselected.
        tapChip(groupChip("glutes", in: app), in: app)
        let band = equipmentChip("band", in: app)
        XCTAssertTrue(band.waitForExistence(timeout: 10), "No Elástico for Glúteos")
        tapChip(band, in: app)
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "2 exercícios"), "Glúteos + Elástico count")
        tapChip(groupChip("chest", in: app), in: app)
        XCTAssertTrue(band.waitForNonExistence(timeout: 10), "Elástico offered for Peito")
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "21 exercícios"), "The equipment kept filtering Peito")
        tapChip(groupChip("glutes", in: app), in: app)
        XCTAssertTrue(band.waitForExistence(timeout: 10), "No Elástico for Glúteos")
        XCTAssertFalse(band.isSelected, "Elástico selected again")
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "13 exercícios"), "Glúteos count")
    }

    @MainActor
    func testClearFiltersKeepsTheSearch() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")
        search("supino", in: app)
        groupChip("chest", in: app).tap()
        equipmentChip("barbell", in: app).tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "3 exercícios"), "Peito + Barra + supino count")

        app.buttons["exercises.clearFilters"].tap()

        XCTAssertTrue(element("exercises.count", in: app).waitForNonExistence(timeout: 10), "Count row still shown")
        XCTAssertTrue(groupChip("all", in: app).isSelected, "Todos not selected again")
        XCTAssertFalse(equipmentChip("barbell", in: app).isSelected, "Barra still selected")
        XCTAssertEqual(searchField(in: app).value as? String, "supino", "Limpar filtros cleared the search")
        // Every "supino" of every group again: the first is Supino Articulado.
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Supino Articulado, Peito, Peitoral médio, Máquina")
    }

    @MainActor
    func testSearchWithoutAccentsAndWithoutResults() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios")

        search("pelvica", in: app)
        XCTAssertTrue(waitForLabel(of: cards(in: app).element(boundBy: 0), toBe: "Elevação Pélvica com Barra, Glúteos, Glúteo máximo, Barra"))
        XCTAssertEqual(cards(in: app).count, 3)

        let clear = app.buttons["exercises.search.clear"]
        XCTAssertTrue(clear.exists, "No clear button with text")
        clear.tap()
        XCTAssertTrue(clear.waitForNonExistence(timeout: 10), "Clear button shown without text")
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Abdominal Bicicleta, Abdômen, Oblíquos, Peso do corpo")

        search("supino xyz", in: app)
        let empty = element("exercises.empty", in: app)
        XCTAssertTrue(empty.waitForExistence(timeout: 10), "No message without results")
        XCTAssertTrue(empty.label.contains("Nenhum exercício encontrado"), "Message: \(empty.label)")
        XCTAssertEqual(cards(in: app).count, 0)
        attachScreenshot(named: "72-exercises-no-results", of: app)
    }

    @MainActor
    func testMineShowsTheCustomExercise() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", seed: ["custom-exercise:Meu Supino:chest"])

        XCTAssertTrue(element("exercises.total", in: app).waitForExistence(timeout: 10), "Header not shown")
        XCTAssertEqual(element("exercises.total", in: app).label, "158 exercícios")
        let mine = groupChip("mine", in: app)
        XCTAssertTrue(mine.exists, "No Meus with a custom exercise")
        mine.tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "1 exercício"), "Meus count")
        XCTAssertTrue(mine.isSelected, "Meus is not selected")
        XCTAssertEqual(cards(in: app).count, 1)
        XCTAssertEqual(cards(in: app).element(boundBy: 0).label, "Meu Supino, Peito, Meu exercício")
        // A custom exercise has no equipment to choose.
        XCTAssertFalse(equipmentChip("barbell", in: app).exists, "Equipment offered for Meus")
        attachScreenshot(named: "73-exercises-mine", of: app)

        // With an equipment chosen, the custom exercise is not shown.
        groupChip("chest", in: app).tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "22 exercícios"), "Peito count with the custom exercise")
        equipmentChip("dumbbell", in: app).tap()
        XCTAssertTrue(waitForLabel(of: element("exercises.count", in: app), toBe: "6 exercícios"), "The custom exercise counted with Halteres")
        search("meu", in: app)
        XCTAssertTrue(element("exercises.empty", in: app).waitForExistence(timeout: 10), "The custom exercise shown with Halteres")
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
