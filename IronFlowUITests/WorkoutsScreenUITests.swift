import XCTest

/// The Treinos tab: the grid of workouts with ▶ and ⋮ (today's workout highlighted), the weekly plan
/// row, the free workout and the three latest finished sessions with "Ver tudo", also with large text.
/// Runs on an in-memory store with the built-in library; the workouts and finished sessions the tests
/// look at come ready (`-ui-seed`). Creating a workout through the screens is checked by
/// `WorkoutUITests`, and finishing a session through the screens by `SessionUITests`.
final class WorkoutsScreenUITests: IronFlowUITestCase {
    /// Push, Pull and Pernas with exercises of the built-in library, like the model.
    private let workouts = [
        "workout:Push:Supino Reto com Barra|Supino Inclinado com Halteres|Desenvolvimento com Halteres|Tríceps na Polia com Corda",
        "workout:Pull:Barra Fixa Pronada|Rosca Direta com Barra",
        "workout:Pernas:Agachamento Livre com Barra|Cadeira Extensora|Stiff com Barra|Mesa Flexora|Panturrilha Sentado",
    ]

    @MainActor
    func testEmptyStateOffersCreatingAndTheFreeWorkout() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos")

        // No workouts: the header counts none, the empty card is shown, and a free workout is still offered.
        XCTAssertTrue(element("workouts.empty", in: app).waitForExistence(timeout: 10), "Empty card not shown")
        XCTAssertTrue(app.staticTexts["0 treinos no plano"].exists, "Subtitle without workouts")
        XCTAssertTrue(app.buttons["workouts.empty.create"].exists, "No Criar treino in the empty card")
        XCTAssertTrue(app.buttons["workouts.free"].exists, "No free workout card")
        XCTAssertFalse(app.buttons["workouts.recent"].exists, "Recent sessions shown without finished sessions")
        XCTAssertFalse(app.buttons["workouts.plan"].exists, "Weekly plan row shown without workouts")
        attachScreenshot(named: "57-workouts-empty", of: app)
    }

    @MainActor
    func testWorkoutsWithPlanAndRecentSessions() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: workouts + [
            "plan:Push:1|4", "plan:Pull:2|5", "finished:Pernas:1", "finished:Pull:1", "finished:Push:1",
        ])

        XCTAssertTrue(app.staticTexts["3 treinos no plano"].waitForExistence(timeout: 10), "Subtitle with three workouts")
        // The plan row reads the planned days; its letters are drawn only.
        let plan = app.buttons["workouts.plan"]
        XCTAssertTrue(plan.exists, "No weekly plan row")
        XCTAssertTrue(plan.label.hasSuffix("4 dias programados"), "Plan row: \(plan.label)")

        // Each card says its exercises, sets and muscle groups, without repeating a group.
        let cards = app.buttons.matching(identifier: "workouts.card")
        XCTAssertEqual(cards.count, 3)
        XCTAssertTrue(cards.element(boundBy: 0).label.hasSuffix("4 exercícios · 12 séries, Peito · Ombros · Tríceps"), "Push: \(cards.element(boundBy: 0).label)")
        XCTAssertTrue(cards.element(boundBy: 1).label.hasSuffix("2 exercícios · 6 séries, Costas · Bíceps"), "Pull: \(cards.element(boundBy: 1).label)")
        XCTAssertTrue(cards.element(boundBy: 2).label.hasSuffix("Quadríceps · Posteriores de coxa · Panturrilhas"), "Pernas: \(cards.element(boundBy: 2).label)")
        // The cards of a row share its height.
        XCTAssertEqual(cards.element(boundBy: 0).frame.height, cards.element(boundBy: 1).frame.height, accuracy: 1)
        XCTAssertEqual(app.buttons.matching(identifier: "workouts.recent").count, 3)
        attachScreenshot(named: "56-workouts", of: app)
    }

    @MainActor
    func testTodaysWorkoutIsHighlighted() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: workouts + ["plan-today:Push"])

        let cards = app.buttons.matching(identifier: "workouts.card")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10), "No workout cards")
        XCTAssertTrue(cards.element(boundBy: 0).label.hasPrefix("Push, programado para hoje, "), "Push: \(cards.element(boundBy: 0).label)")
        XCTAssertFalse(cards.element(boundBy: 1).label.contains("programado para hoje"), "Pull: \(cards.element(boundBy: 1).label)")
        XCTAssertTrue(app.buttons["Iniciar Push"].isEnabled, "▶ of today's workout disabled")
        attachScreenshot(named: "58-workouts-today", of: app)
    }

    @MainActor
    func testLargeTextKeepsTheWorkoutsOnScreen() throws {
        continueAfterFailure = false
        let seed = workouts + ["plan-today:Push", "finished:Pull:1"]

        for (size, name) in [("UICTContentSizeCategoryXXXL", "60-workouts-xxxl"), ("UICTContentSizeCategoryAccessibilityXXXL", "62-workouts-accessibility")] {
            let app = launchOnTab("Treinos", seed: seed, extraArguments: ["-UIPreferredContentSizeCategoryName", size])
            let add = app.buttons["workouts.add"]
            XCTAssertTrue(add.waitForExistence(timeout: 10), "No Criar treino with \(size)")
            let screen = app.windows.firstMatch.frame
            let cards = app.buttons.matching(identifier: "workouts.card")
            for element in [add, cards.element(boundBy: 0), cards.element(boundBy: 1), app.buttons["Iniciar Push"]] {
                XCTAssertTrue(
                    element.frame.minX >= screen.minX && element.frame.maxX <= screen.maxX,
                    "\(element.label) is not on the screen with \(size): \(element.frame) on \(screen)"
                )
            }
            attachScreenshot(named: name, of: app)
            app.terminate()
        }
    }

    @MainActor
    func testStartFromTheCardAndFreeWorkout() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa Pronada", "workout:Pull"])

        XCTAssertTrue(app.staticTexts["2 treinos no plano"].waitForExistence(timeout: 10), "Subtitle with two workouts")
        XCTAssertFalse(element("workouts.empty", in: app).exists, "Empty card shown with workouts")
        let cards = app.buttons.matching(identifier: "workouts.card")
        XCTAssertEqual(cards.count, 2)
        XCTAssertTrue(cards.element(boundBy: 0).label.contains("Push"), "Card: \(cards.element(boundBy: 0).label)")
        XCTAssertTrue(cards.element(boundBy: 0).label.contains("1 exercício · 3 séries"), "Card: \(cards.element(boundBy: 0).label)")
        XCTAssertTrue(cards.element(boundBy: 1).label.contains("Pull"), "Card: \(cards.element(boundBy: 1).label)")
        XCTAssertTrue(cards.element(boundBy: 1).label.contains("Nenhum exercício"), "Card: \(cards.element(boundBy: 1).label)")

        // ▶ is unavailable for a workout without exercises.
        XCTAssertTrue(app.buttons["Iniciar Push"].isEnabled, "▶ of Push disabled")
        XCTAssertFalse(app.buttons["Iniciar Pull"].isEnabled, "▶ of a workout without exercises is enabled")

        // ▶ starts a session of that workout.
        startWorkout(named: "Push", in: app)
        XCTAssertEqual(element("session.name", in: app).label, "Push")
        discardSession(in: app)

        // The free workout card starts a session without a planned workout.
        app.buttons["workouts.free"].tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Free session screen not shown")
        XCTAssertEqual(element("session.name", in: app).label, "Treino livre")
        discardSession(in: app)
        XCTAssertFalse(app.buttons["workouts.recent"].exists, "A discarded session is a recent session")
    }

    @MainActor
    func testRenameAndDeleteFromTheMenu() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa Pronada"])

        // Rename.
        let options = app.buttons["Opções de Push"]
        XCTAssertTrue(options.waitForExistence(timeout: 10), "Workout menu not shown")
        options.tap()
        let rename = app.buttons["Renomear"]
        XCTAssertTrue(rename.waitForExistence(timeout: 10), "Rename option not found")
        rename.tap()
        let field = app.textFields["workout.name.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Name field not found")
        XCTAssertEqual(field.value as? String, "Push")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Push".count))
        field.typeText("Pull")
        app.buttons["workout.name.save"].tap()
        XCTAssertTrue(waitForToast("Nome salvo", in: app), "No notice after renaming")
        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "Name sheet did not close")
        let card = app.buttons["workouts.card"]
        XCTAssertTrue(waitForLabel(of: card, containing: "Pull"), "Card not renamed: \(card.label)")
        XCTAssertTrue(app.buttons["Iniciar Pull"].exists, "▶ not renamed")
        XCTAssertFalse(element("workout.title", in: app).exists, "Renaming opened the editor")

        // "Editar treino" opens the editor.
        app.buttons["Opções de Pull"].tap()
        let edit = app.buttons["Editar treino"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Edit option not found")
        edit.tap()
        XCTAssertTrue(waitForLabel(of: element("workout.title", in: app), toBe: "Pull"), "Editor not opened from the menu")
        goBackFromEditor(in: app)

        // Delete: cancelling keeps the workout.
        app.buttons["Opções de Pull"].tap()
        let delete = app.buttons["Excluir"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "Delete option not found")
        delete.tap()
        XCTAssertTrue(element(labelStartingWith: "Excluir “Pull”", in: app).waitForExistence(timeout: 10), "Delete confirmation not shown")
        cancelDialog(confirmLabel: "Excluir", in: app)
        XCTAssertTrue(app.buttons["workouts.card"].exists, "Cancel deleted the workout")
        XCTAssertTrue(app.staticTexts["1 treino no plano"].exists, "Subtitle after cancelling")

        // Delete: confirming removes it and shows the empty card.
        let menuFrame = app.buttons["Opções de Pull"].frame
        app.buttons["Opções de Pull"].tap()
        XCTAssertTrue(app.buttons["Excluir"].waitForExistence(timeout: 10), "Delete option not found")
        app.buttons["Excluir"].tap()
        XCTAssertTrue(element(labelStartingWith: "Excluir “Pull”", in: app).waitForExistence(timeout: 10), "Delete confirmation not shown")
        let confirm = app.buttons["Excluir"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Confirm button not shown")
        // The confirmation points to the card's ⋮ it came from: it opens right below it.
        XCTAssertGreaterThan(confirm.frame.minY, menuFrame.maxY, "Confirmation not below the ⋮ \(menuFrame): \(confirm.frame)")
        XCTAssertLessThan(confirm.frame.minY, menuFrame.maxY + 300, "Confirmation far from the ⋮ \(menuFrame): \(confirm.frame)")
        attachScreenshot(named: "82-workouts-delete-confirmation", of: app)
        confirm.tap()
        XCTAssertTrue(waitForToast("Treino excluído", in: app), "No notice after deleting")
        XCTAssertTrue(element("workouts.empty", in: app).waitForExistence(timeout: 10), "Empty card not shown after deleting")
        XCTAssertFalse(app.buttons["workouts.card"].exists, "Deleted workout still listed")
        XCTAssertTrue(app.staticTexts["0 treinos no plano"].exists, "Subtitle after deleting")
    }

    @MainActor
    func testRecentWorkoutsShowOnlyTheLastThree() throws {
        continueAfterFailure = false
        // Four finished sessions of Push, two hours apart, each lasting 40 minutes.
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa Pronada", "workout:Pull", "finished:Push:4"])

        // Four sessions were finished, three are shown.
        let recents = app.buttons.matching(identifier: "workouts.recent")
        XCTAssertTrue(recents.firstMatch.waitForExistence(timeout: 10), "No recent sessions")
        XCTAssertEqual(recents.count, 3, "The recent sessions are not limited to three")
        attachScreenshot(named: "43-workouts", of: app)
        scrollToBottom(in: app)
        // The screenshot shows the end of the list: the last recent session above the tab bar.
        XCTAssertLessThanOrEqual(
            recents.element(boundBy: 2).frame.maxY,
            app.tabBars.firstMatch.frame.minY,
            "The last recent session is under the tab bar"
        )
        attachScreenshot(named: "44-workouts-recent", of: app)

        // Each one is read as a sentence: name, date, time and duration.
        let first = recents.element(boundBy: 0)
        XCTAssertTrue(first.label.hasPrefix("Push, "), "Recent session: \(first.label)")
        XCTAssertTrue(first.label.hasSuffix(" min"), "Recent session without a duration: \(first.label)")

        // Tapping one opens the read-only detail of that session.
        XCTAssertTrue(first.isHittable, "The first recent session cannot be tapped")
        first.tap()
        XCTAssertTrue(element("history.detail", in: app).waitForExistence(timeout: 10), "Session detail not opened")
        XCTAssertTrue(app.navigationBars["Push"].exists, "The detail does not show the session's name")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "history.detail.exercise").count, 1)

        // Back to the list: the same three.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(recents.firstMatch.waitForExistence(timeout: 10), "Recent sessions not shown after going back")
        XCTAssertEqual(recents.count, 3)
        scrollToTop(in: app)
        XCTAssertTrue(app.buttons["workouts.add"].waitForExistence(timeout: 10), "Header not shown after scrolling up")

        // "Ver tudo" opens the Histórico, with all four sessions.
        scrollToBottom(in: app)
        app.buttons["workouts.recent.all"].tap()
        let history = app.tabBars.buttons["Histórico"]
        XCTAssertTrue(waitForSelection(of: history), "Ver tudo did not open the Histórico")
        let sessions = app.descendants(matching: .any).matching(identifier: "history.session")
        XCTAssertTrue(sessions.firstMatch.waitForExistence(timeout: 10), "History not shown")
        XCTAssertEqual(sessions.count, 4)
    }

    /// Waits until the tab is the selected one.
    @MainActor
    private func waitForSelection(of tab: XCUIElement) -> Bool {
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: tab)
        return XCTWaiter().wait(for: [selected], timeout: 10) == .completed
    }
}
