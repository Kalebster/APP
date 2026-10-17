import XCTest

/// The session in progress: starting from a workout, checking sets, minimizing and continuing from
/// the "Treino em andamento" bar, finishing (then the history) and discarding.
/// Runs on an in-memory store with the built-in library; the workout the tests start comes ready
/// (`-ui-seed`).
final class SessionUITests: IronFlowUITestCase {
    @MainActor
    private func checks(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "session.set.check")
    }

    @MainActor
    private func repsFields(in app: XCUIApplication) -> XCUIElementQuery {
        app.textFields.matching(identifier: "session.set.reps")
    }

    @MainActor
    private func weightFields(in app: XCUIApplication) -> XCUIElementQuery {
        app.textFields.matching(identifier: "session.set.weight")
    }

    @MainActor
    func testStartCheckMinimizeContinueAndFinish() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa"])
        startWorkout(named: "Push", in: app)

        XCTAssertEqual(element("session.name", in: app).label, "Push")
        XCTAssertEqual(checks(in: app).count, 3, "The session should copy the three planned sets")

        // Empty repetitions take the target (8–12 → 12): the set is checked here, and its stored
        // repetitions are proven after the session is opened again (below).
        checks(in: app).element(boundBy: 0).tap()
        XCTAssertTrue(checks(in: app).element(boundBy: 0).isSelected, "First set not checked")

        // Typed load and repetitions are recorded (they are read back in the history, below).
        weightFields(in: app).element(boundBy: 1).tap()
        weightFields(in: app).element(boundBy: 1).typeText("20")
        repsFields(in: app).element(boundBy: 1).tap()
        repsFields(in: app).element(boundBy: 1).typeText("10")
        checks(in: app).element(boundBy: 1).tap()
        XCTAssertEqual(repsFields(in: app).element(boundBy: 1).value as? String, "10")
        XCTAssertTrue(checks(in: app).element(boundBy: 1).isSelected, "Second set not checked")

        // A set added during the session copies the last one.
        app.buttons["session.addSet"].tap()
        XCTAssertTrue(checks(in: app).element(boundBy: 3).waitForExistence(timeout: 10), "Set not added")
        attachScreenshot(named: "25-session", of: app)

        // Minimized, the bar is shown on the other tabs and opens the session again; the Home
        // offers "Continuar" in its card instead of the bar.
        app.buttons["session.minimize"].tap()
        let bar = app.buttons["session.bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Session bar not shown")
        attachScreenshot(named: "26-session-bar", of: app)
        openTab("Início", in: app)
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 10), "No Continuar on the Home")
        XCTAssertFalse(bar.exists, "Session bar shown on the Home")
        openTab("Exercícios", in: app)
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Session bar not shown on Exercícios")
        bar.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session not opened from the bar")
        XCTAssertTrue(checks(in: app).element(boundBy: 0).isSelected, "Checked set lost after minimizing")

        // The session screen was created again, so the field shows the stored repetitions. Its
        // empty hint is also "12", so the value alone proves nothing: typing one digit must give
        // three characters (1, 2 and 3, wherever the caret is), which only happens when the field
        // really holds "12"; an empty field would show "3". The digit is then deleted again.
        let firstReps = repsFields(in: app).element(boundBy: 0)
        firstReps.tap()
        firstReps.typeText("3")
        let typed = try XCTUnwrap(firstReps.value as? String)
        XCTAssertEqual(typed.count, 3, "The checked set does not hold 12 repetitions: \(typed)")
        XCTAssertEqual(Set(typed), ["1", "2", "3"], "The checked set does not hold 12 repetitions: \(typed)")
        firstReps.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual(firstReps.value as? String, "12")

        // Finishing with sets not done asks first; they stay recorded as not done.
        app.buttons["session.finish"].tap()
        let confirm = app.buttons["Concluir treino"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Finish confirmation not shown")
        confirm.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
        XCTAssertTrue(bar.waitForNonExistence(timeout: 10), "Session bar still shown after finishing")

        openTab("Histórico", in: app)
        let finished = element("history.session", in: app)
        XCTAssertTrue(finished.waitForExistence(timeout: 10), "Finished session not in the history")
        XCTAssertTrue(finished.label.contains("Push"), "History: \(finished.label)")
        XCTAssertTrue(finished.label.contains("1 exercício · 2 séries"), "History: \(finished.label)")
        attachScreenshot(named: "27-history", of: app)

        // What was typed is in the record: the load and repetitions of the second set.
        finished.tap()
        let secondSet = element("history.detail", in: app).descendants(matching: .any).matching(identifier: "history.detail.set").element(boundBy: 1)
        XCTAssertTrue(secondSet.waitForExistence(timeout: 10), "Session detail not opened")
        XCTAssertEqual(secondSet.label, "Série 2, Meta: 8–12, Carga: 20 kg, 10 repetições, Concluída")
    }

    @MainActor
    func testFinishNeedsACompletedSetAndDiscardKeepsThePlan() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Pull:Barra Fixa"])
        startWorkout(named: "Pull", in: app)

        app.buttons["session.finish"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "No message when finishing without sets")
        XCTAssertTrue(alert.staticTexts["Conclua pelo menos uma série ou descarte o treino."].exists)
        alert.buttons["OK"].tap()

        discardSession(in: app)
        XCTAssertFalse(app.buttons["session.bar"].exists, "Session bar still shown after discarding")

        // The planned workout is kept; nothing reaches the history.
        XCTAssertTrue(app.buttons["workouts.start"].waitForExistence(timeout: 10), "Workout lost after discarding")
        openTab("Histórico", in: app)
        XCTAssertTrue(element("history.empty", in: app).waitForExistence(timeout: 10), "Discarded session in the history")
    }

    @MainActor
    func testSecondStartOffersTheCurrentSession() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Legs:Barra Fixa"])
        startWorkout(named: "Legs", in: app)
        app.buttons["session.minimize"].tap()
        XCTAssertTrue(app.buttons["session.bar"].waitForExistence(timeout: 10), "Session bar not shown")

        app.buttons["workouts.start"].firstMatch.tap()
        let resume = app.buttons["Continuar treino atual"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "No notice about the session in progress")
        resume.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Current session not opened")
        XCTAssertEqual(element("session.name", in: app).label, "Legs")
    }
}
