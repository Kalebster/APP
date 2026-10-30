import XCTest

/// The session in progress: starting from a workout, checking sets, minimizing and continuing from
/// the "Treino em andamento" bar, finishing with "Concluir treino?" (then the history), finishing a
/// session left open, "Nenhuma série marcada" and discarding; and the set row with the largest text size.
/// Runs on an in-memory store with the built-in library; the workout the tests start, and the session
/// left open, come ready (`-ui-seed`).
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
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa Pronada"])
        startWorkout(named: "Push", in: app)

        XCTAssertEqual(element("session.name", in: app).label, "Push")
        XCTAssertEqual(checks(in: app).count, 3, "The session should copy the three planned sets")

        // Empty repetitions take the target (8–12 → 12): the set is checked here, and its stored
        // repetitions are proven after the session is opened again (below).
        checks(in: app).element(boundBy: 0).tap()
        XCTAssertTrue(checks(in: app).element(boundBy: 0).isSelected, "First set not checked")

        // Typed load and repetitions are recorded (they are read back in the history, below). Each
        // field is tapped beside its text: the whole 44-point box responds.
        tapAboveTheTextAndWaitForFocus(of: weightFields(in: app).element(boundBy: 1))
        weightFields(in: app).element(boundBy: 1).typeText("20")
        tapAboveTheTextAndWaitForFocus(of: repsFields(in: app).element(boundBy: 1))
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
        // One button for VoiceOver; the rest started by the second set is still running.
        XCTAssertTrue(bar.label.hasPrefix("Treino em andamento, Push, Descanso "), "Bar: \(bar.label)")
        XCTAssertTrue(bar.label.hasSuffix(". Abrir"), "Bar: \(bar.label)")
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

        // "Concluir treino?" shows what the session did and what will not be saved, before saving.
        app.buttons["session.finish"].tap()
        let save = app.buttons["finish.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Concluir treino? not shown")
        XCTAssertTrue(app.staticTexts["Concluir treino?"].exists, "No title")
        XCTAssertEqual(element("finish.sets", in: app).label, "2 de 4 séries feitas")
        XCTAssertTrue(element("finish.duration", in: app).label.hasPrefix("duração "), "Duration: \(element("finish.duration", in: app).label)")
        XCTAssertEqual(element("finish.volume", in: app).label, "200 kg levantados")
        XCTAssertEqual(element("finish.notDone", in: app).label, "As 2 séries não marcadas não serão salvas.")
        XCTAssertTrue(app.buttons["finish.continue"].exists, "No Continuar treinando")
        attachScreenshot(named: "91-session-finish", of: app)

        // "Continuar treinando" goes back to the session; "Concluir e salvar" saves it.
        app.buttons["finish.continue"].tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10), "Concluir treino? not closed")
        XCTAssertTrue(element("session.name", in: app).exists, "Continuar treinando closed the session")
        saveSessionFromTheFinishSheet(in: app)
        // Every set done and the load of the working and failure sets.
        XCTAssertTrue(waitForToast("Treino salvo · 2 séries · 200 kg", in: app), "No notice after finishing")
        attachScreenshot(named: "93-workout-saved-notice", of: app)
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
        let app = launchOnTab("Treinos", seed: ["workout:Pull:Barra Fixa Pronada"])
        startWorkout(named: "Pull", in: app)

        // Without a set done there is nothing to save: the sheet says so.
        app.buttons["session.finish"].tap()
        let discard = app.buttons["finish.discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 10), "Nenhuma série marcada not shown")
        XCTAssertTrue(app.staticTexts["Nenhuma série marcada"].exists, "No title")
        XCTAssertTrue(app.staticTexts["Marque pelo menos uma série para salvar o treino."].exists, "No explanation")
        XCTAssertFalse(app.buttons["finish.save"].exists, "Concluir e salvar offered without a set done")
        attachScreenshot(named: "92-session-finish-nothing-done", of: app)
        app.buttons["finish.continue"].tap()
        XCTAssertTrue(discard.waitForNonExistence(timeout: 10), "Nenhuma série marcada not closed")
        XCTAssertTrue(element("session.name", in: app).exists, "Continuar treinando closed the session")

        // "Descartar treino" asks the usual question before discarding.
        app.buttons["session.finish"].tap()
        XCTAssertTrue(discard.waitForExistence(timeout: 10), "Nenhuma série marcada not shown again")
        discard.tap()
        let confirm = app.buttons["Descartar"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Discard confirmation not shown")
        XCTAssertTrue(app.staticTexts["Descartar este treino?"].exists, "Not the discard question")
        confirm.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
        XCTAssertTrue(waitForToast("Treino descartado", in: app), "No notice after discarding")
        XCTAssertFalse(app.buttons["session.bar"].exists, "Session bar still shown after discarding")

        // The planned workout is kept; nothing reaches the history.
        XCTAssertTrue(app.buttons["workouts.start"].waitForExistence(timeout: 10), "Workout lost after discarding")
        openTab("Histórico", in: app)
        XCTAssertTrue(element("history.empty", in: app).waitForExistence(timeout: 10), "Discarded session in the history")
    }

    @MainActor
    func testSecondStartOffersTheCurrentSession() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Legs:Barra Fixa Pronada"])
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

    @MainActor
    func testSessionLeftOpenOffersTheLastRecordAsTheEnd() throws {
        continueAfterFailure = false
        // Started 3 hours ago, its first set done 2 hours ago (by the seed's own clock), still open.
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa Pronada", "open-session:Push"])
        let bar = app.buttons["session.bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Session bar not shown")
        // Without a rest: the time since the start and the sets done.
        XCTAssertTrue(bar.label.hasPrefix("Treino em andamento, Push, 3:0"), "Bar: \(bar.label)")
        XCTAssertTrue(bar.label.hasSuffix(", 1 de 3 séries. Abrir"), "Bar: \(bar.label)")
        bar.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session not opened from the bar")

        // "Concluir treino?" asks for the end, the time of the last record or now, and the duration
        // follows the choice: the last record, 1 hour after the start, is chosen first.
        app.buttons["session.finish"].tap()
        let lastRecord = app.buttons["finish.end.lastRecord"]
        let now = app.buttons["finish.end.now"]
        XCTAssertTrue(lastRecord.waitForExistence(timeout: 10), "No question about the end of a session left open")
        XCTAssertEqual(now.label, "Usar agora")
        XCTAssertTrue(lastRecord.label.hasPrefix("Usar "), "Last record: \(lastRecord.label)")
        XCTAssertTrue(lastRecord.isSelected, "The last record is not chosen first")
        let time = String(lastRecord.label.dropFirst("Usar ".count))
        // The day is named only when the last record was not today (a run just after midnight).
        let question = element("finish.question", in: app)
        XCTAssertTrue(question.label.hasPrefix("Seu último registro foi"), "Question: \(question.label)")
        XCTAssertTrue(question.label.hasSuffix("às \(time). Usar esse horário como fim?"), "The question does not give the time \(time)")
        let duration = element("finish.duration", in: app)
        XCTAssertEqual(duration.label, "duração 1 hora")
        XCTAssertEqual(element("finish.notDone", in: app).label, "As 2 séries não marcadas não serão salvas.")
        attachScreenshot(named: "28-session-finish-last-record", of: app)

        // Now: the 3 hours since the start.
        now.tap()
        XCTAssertTrue(waitForLabel(of: duration, containing: "3 horas"), "Duration with now: \(duration.label)")
        XCTAssertTrue(now.isSelected, "Usar agora not chosen")

        // "Continuar treinando" does not finish.
        app.buttons["finish.continue"].tap()
        XCTAssertTrue(lastRecord.waitForNonExistence(timeout: 10), "Concluir treino? not closed")
        XCTAssertTrue(element("session.name", in: app).exists, "Continuar treinando closed the session")

        // Asked again, the last record is chosen again and becomes the end.
        app.buttons["session.finish"].tap()
        XCTAssertTrue(lastRecord.waitForExistence(timeout: 10), "Question not shown again")
        XCTAssertTrue(lastRecord.isSelected, "The last record is not chosen first again")
        app.buttons["finish.save"].tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
        XCTAssertTrue(bar.waitForNonExistence(timeout: 10), "Session bar still shown after finishing")

        // Treinos recentes and the history show that duration.
        let recent = app.buttons["workouts.recent"].firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 10), "The finished session is not a recent session")
        XCTAssertTrue(recent.label.hasSuffix(", 1 h"), "Recent session: \(recent.label)")
        openTab("Histórico", in: app)
        let finished = element("history.session", in: app)
        XCTAssertTrue(finished.waitForExistence(timeout: 10), "Finished session not in the history")
        XCTAssertTrue(finished.label.contains("1 h · 1 exercício · 1 série"), "History: \(finished.label)")
    }

    @MainActor
    func testTheSetRowFitsOnTheScreenWithTheLargestText() throws {
        continueAfterFailure = false
        let app = launchOnTab(
            "Treinos",
            seed: ["workout:Push:Barra Fixa Pronada", "open-session:Push"],
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )
        let bar = app.buttons["session.bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Session bar not shown")
        bar.tap()
        let weight = weightFields(in: app).element(boundBy: 0)
        XCTAssertTrue(weight.waitForExistence(timeout: 10), "Session not opened from the bar")

        // The load, the repetitions and the completion mark of the first set stay on the screen.
        let screen = app.windows.firstMatch.frame
        let row = [("load", weight), ("repetitions", repsFields(in: app).element(boundBy: 0)), ("mark", checks(in: app).element(boundBy: 0))]
        recordMeasurement(
            "Medição: série 1 com o maior texto (tela de \(Int(screen.width)) pt)",
            row.map { "\($0.0) \(Int($0.1.frame.minX))–\(Int($0.1.frame.maxX))" }.joined(separator: ", ")
        )
        attachScreenshot(named: "29-session-large-text", of: app)
        for (name, element) in row {
            XCTAssertTrue(
                element.frame.minX >= screen.minX && element.frame.maxX <= screen.maxX,
                "The \(name) of set 1 is not on the screen: \(element.frame) on \(screen)"
            )
        }
    }
}
