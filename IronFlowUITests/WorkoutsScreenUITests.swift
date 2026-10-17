import XCTest

/// The Treinos tab: the grid of workouts with ▶ and ⋮, the free workout and the three latest finished
/// sessions. Runs on an in-memory store with the built-in library; the workouts and finished sessions
/// the tests look at come ready (`-ui-seed`). Creating a workout through the screens is checked by
/// `WorkoutUITests`, and finishing a session through the screens by `SessionUITests`.
final class WorkoutsScreenUITests: IronFlowUITestCase {
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
    }

    @MainActor
    func testStartFromTheCardAndFreeWorkout() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa", "workout:Pull"])

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
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa"])

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
        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "Name sheet did not close")
        let card = app.buttons["workouts.card"]
        XCTAssertTrue(waitForLabel(of: card, containing: "Pull"), "Card not renamed: \(card.label)")
        XCTAssertTrue(app.buttons["Iniciar Pull"].exists, "▶ not renamed")
        XCTAssertFalse(app.navigationBars["Pull"].exists, "Renaming opened the editor")

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
        app.buttons["Opções de Pull"].tap()
        XCTAssertTrue(app.buttons["Excluir"].waitForExistence(timeout: 10), "Delete option not found")
        app.buttons["Excluir"].tap()
        XCTAssertTrue(element(labelStartingWith: "Excluir “Pull”", in: app).waitForExistence(timeout: 10), "Delete confirmation not shown")
        let confirm = app.buttons["Excluir"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Confirm button not shown")
        confirm.tap()
        XCTAssertTrue(element("workouts.empty", in: app).waitForExistence(timeout: 10), "Empty card not shown after deleting")
        XCTAssertFalse(app.buttons["workouts.card"].exists, "Deleted workout still listed")
        XCTAssertTrue(app.staticTexts["0 treinos no plano"].exists, "Subtitle after deleting")
    }

    @MainActor
    func testRecentWorkoutsShowOnlyTheLastThree() throws {
        continueAfterFailure = false
        // Four finished sessions of Push, two hours apart, each lasting 40 minutes.
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa", "workout:Pull", "finished:Push:4"])

        // Four sessions were finished, three are shown.
        let recents = app.buttons.matching(identifier: "workouts.recent")
        XCTAssertTrue(recents.firstMatch.waitForExistence(timeout: 10), "No recent sessions")
        XCTAssertEqual(recents.count, 3, "The recent sessions are not limited to three")
        attachScreenshot(named: "43-workouts", of: app)
        scrollToBottom(in: app)
        // The screenshot shows the list scrolled up: the header is out of the screen.
        XCTAssertLessThan(app.buttons["workouts.add"].frame.minY, 0, "The list did not scroll")
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
    }
}
