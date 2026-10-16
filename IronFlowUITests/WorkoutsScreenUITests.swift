import XCTest

/// The Treinos tab: the grid of workouts with ▶ and ⋮, the free workout and the three latest finished
/// sessions. Runs on an in-memory store with the built-in library.
final class WorkoutsScreenUITests: XCTestCase {
    @MainActor
    private func launchOnWorkoutsTab(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extraArguments
        app.launch()
        let tab = app.tabBars.buttons["Treinos"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Tab 'Treinos' not found")
        tab.tap()
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func element(labelStartingWith prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Creates a workout, with one exercise (three planned sets of 8–12) when `exercise` is given, and
    /// goes back to the list, where the workout's ▶ button ("Iniciar <nome>") is waited for.
    @MainActor
    private func createWorkout(named name: String, exercise: String?, in app: XCUIApplication) {
        let add = app.buttons["workouts.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Add workout button not found")
        add.tap()
        let field = app.textFields["workout.name.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Name field not found")
        field.tap()
        field.typeText(name)
        app.buttons["workout.name.save"].tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 10), "Editor of '\(name)' did not open")

        if let exercise {
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
        }

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Iniciar \(name)"].waitForExistence(timeout: 10), "Workout '\(name)' not in the list")
    }

    /// Starts `workout` from its ▶ button, completes the first set and finishes the session.
    @MainActor
    private func startAndFinishSession(of workout: String, in app: XCUIApplication) {
        let start = app.buttons["Iniciar \(workout)"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "No ▶ for '\(workout)'")
        start.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
        app.buttons.matching(identifier: "session.set.check").element(boundBy: 0).tap()
        app.buttons["session.finish"].tap()
        let confirm = app.buttons["Concluir treino"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Finish confirmation not shown")
        confirm.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
    }

    /// Discards the session in progress, from the session screen.
    @MainActor
    private func discardSession(in app: XCUIApplication) {
        app.buttons["session.discard"].tap()
        let discard = app.buttons["Descartar"]
        XCTAssertTrue(discard.waitForExistence(timeout: 10), "Discard confirmation not shown")
        discard.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
    }

    /// Closes the confirmation dialog without confirming: with the system layout it has a "Cancelar"
    /// button or is dismissed by tapping outside it.
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

    @MainActor
    private func waitForLabel(of element: XCUIElement, containing text: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }

    @MainActor
    private func scrollToBottom(in app: XCUIApplication) {
        for _ in 0..<3 {
            app.swipeUp()
        }
    }

    @MainActor
    private func scrollToTop(in app: XCUIApplication) {
        for _ in 0..<3 {
            app.swipeDown()
        }
    }

    @MainActor
    private func attachScreenshot(named name: String, of app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testStartFromTheCardAndFreeWorkout() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab()

        // No workouts: the header counts none, the empty card is shown, and a free workout is still offered.
        XCTAssertTrue(element("workouts.empty", in: app).waitForExistence(timeout: 10), "Empty card not shown")
        XCTAssertTrue(app.staticTexts["0 treinos no plano"].exists, "Subtitle without workouts")
        XCTAssertTrue(app.buttons["workouts.empty.create"].exists, "No Criar treino in the empty card")
        XCTAssertTrue(app.buttons["workouts.free"].exists, "No free workout card")
        XCTAssertFalse(app.buttons["workouts.recent"].exists, "Recent sessions shown without finished sessions")
        XCTAssertFalse(app.buttons["workouts.plan"].exists, "Weekly plan row shown without workouts")

        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)
        createWorkout(named: "Pull", exercise: nil, in: app)

        XCTAssertTrue(app.staticTexts["2 treinos no plano"].exists, "Subtitle with two workouts")
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
        app.buttons["Iniciar Push"].tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
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
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)

        // Rename.
        app.buttons["Opções de Push"].tap()
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
        let app = launchOnWorkoutsTab()
        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)
        createWorkout(named: "Pull", exercise: nil, in: app)

        for _ in 1...4 {
            startAndFinishSession(of: "Push", in: app)
        }

        // Four sessions were finished, three are shown.
        let recents = app.buttons.matching(identifier: "workouts.recent")
        XCTAssertTrue(recents.firstMatch.waitForExistence(timeout: 10), "No recent sessions")
        XCTAssertEqual(recents.count, 3, "The recent sessions are not limited to three")
        attachScreenshot(named: "43-workouts-light", of: app)
        scrollToBottom(in: app)
        // The screenshot shows the list scrolled up: the header is out of the screen.
        XCTAssertLessThan(app.buttons["workouts.add"].frame.minY, 0, "The list did not scroll")
        attachScreenshot(named: "44-workouts-recent-light", of: app)

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

    @MainActor
    func testDarkAppearance() throws {
        continueAfterFailure = false
        let app = launchOnWorkoutsTab(extraArguments: ["-ui-dark-appearance"])
        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)
        createWorkout(named: "Pull", exercise: nil, in: app)
        startAndFinishSession(of: "Push", in: app)

        XCTAssertTrue(app.buttons["workouts.recent"].waitForExistence(timeout: 10), "No recent session")
        attachScreenshot(named: "45-workouts-dark", of: app)
        scrollToBottom(in: app)
        attachScreenshot(named: "46-workouts-recent-dark", of: app)
    }
}
