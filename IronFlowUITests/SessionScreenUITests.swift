import XCTest

/// The session screen in the approved model: "Última vez" and the values it suggests, checking a set
/// without typing, the rest timer, a finished exercise closing and opening, removing sets and
/// exercises, typed values kept when their row leaves the screen, the keyboard, a set done without a
/// load, and large text.
/// The flows already covered elsewhere (finishing, minimizing, discarding from the ⋯ menu) are in
/// `SessionUITests`.
final class SessionScreenUITests: IronFlowUITestCase {
    /// Push with four exercises of the built-in library, like the model: 12 sets.
    private let push = "workout:Push:Supino Reto com Barra|Supino Inclinado com Halteres|Desenvolvimento com Halteres|Tríceps na Polia com Corda"

    @MainActor
    private func checks(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "session.set.check")
    }

    @MainActor
    private func weightFields(in app: XCUIApplication) -> XCUIElementQuery {
        app.textFields.matching(identifier: "session.set.weight")
    }

    @MainActor
    private func repsFields(in app: XCUIApplication) -> XCUIElementQuery {
        app.textFields.matching(identifier: "session.set.reps")
    }

    @MainActor
    private func previousTexts(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "session.set.previous")
    }

    /// The seconds the rest bar shows ("Descanso, 1:24" → 84).
    @MainActor
    private func restSeconds(_ element: XCUIElement) -> Int? {
        guard let match = element.label.firstMatch(of: /(\d+):(\d{2})/),
              let minutes = Int(match.1),
              let seconds = Int(match.2) else { return nil }
        return minutes * 60 + seconds
    }

    /// Drags the list up by what is visible between the header and the keyboard (with its OK bar), the
    /// rest bar or the bottom of the screen: a drag of the list itself, which a swipe over the whole app
    /// may not be.
    @MainActor
    private func dragListUp(in app: XCUIApplication) {
        let top = element("session.progress", in: app).frame.maxY + 30
        var bottom = app.windows.firstMatch.frame.maxY - 60
        let rest = element("session.rest", in: app)
        if rest.exists {
            bottom = min(bottom, rest.frame.minY - 30)
        }
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists {
            bottom = min(bottom, keyboard.frame.minY - 30)
        }
        let ok = app.buttons["OK"]
        if ok.exists {
            bottom = min(bottom, ok.frame.minY - 30)
        }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = app.windows.firstMatch.frame.midX
        origin.withOffset(CGVector(dx: x, dy: bottom))
            .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: x, dy: top)))
    }

    /// Waits until the query finds `count` elements.
    @MainActor
    private func waitForCount(_ query: XCUIElementQuery, _ count: Int, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if query.count == count {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return query.count == count
    }

    @MainActor
    func testLastTimeSuggestionsAndTheRestTimer() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: [push, "last-time:Push"])
        startWorkout(named: "Push", in: app)

        // "Última vez", set by set, and its values in gray in the empty fields.
        let firstPrevious = previousTexts(in: app).element(boundBy: 0)
        XCTAssertTrue(firstPrevious.waitForExistence(timeout: 10), "No ÚLTIMA column")
        XCTAssertEqual(firstPrevious.label, "Última vez: 60 kg, 10 repetições")
        XCTAssertEqual(previousTexts(in: app).element(boundBy: 2).label, "Última vez: 60 kg, 9 repetições")
        XCTAssertEqual(weightFields(in: app).element(boundBy: 0).placeholderValue, "60")
        XCTAssertEqual(repsFields(in: app).element(boundBy: 2).placeholderValue, "9")
        XCTAssertEqual(element("session.volume", in: app).label, "0 kg levantados")
        XCTAssertEqual(element("session.progress", in: app).label, "0 de 12 séries, Exercício 1 de 4")
        XCTAssertTrue(app.buttons["Série 1, atual"].exists, "The first set is not the current one")
        // VoiceOver says "selected" only for a set done.
        XCTAssertFalse(checks(in: app).element(boundBy: 0).isSelected, "Set 1, not done, reads as selected")
        XCTAssertFalse(checks(in: app).element(boundBy: 1).isSelected, "Set 2, not done, reads as selected")
        attachScreenshot(named: "65-session-current-set", of: app)

        // ✓ without typing records the values in gray, and starts the rest.
        checks(in: app).element(boundBy: 0).tap()
        XCTAssertTrue(checks(in: app).element(boundBy: 0).isSelected, "First set not checked")
        XCTAssertFalse(checks(in: app).element(boundBy: 1).isSelected, "Set 2, not done, reads as selected")
        XCTAssertTrue(waitForLabel(of: element("session.volume", in: app), containing: "600 kg levantados"), "The suggestion was not recorded")
        XCTAssertEqual(element("session.progress", in: app).label, "1 de 12 séries, Exercício 1 de 4")
        XCTAssertTrue(app.buttons["Série 2, atual"].exists, "The second set is not the current one")

        let rest = element("session.rest.time", in: app)
        XCTAssertTrue(rest.waitForExistence(timeout: 10), "No rest after checking a set")
        let started = try XCTUnwrap(restSeconds(rest), "Rest: \(rest.label)")
        XCTAssertTrue((75...90).contains(started), "Rest: \(rest.label)")
        app.buttons["session.rest.plus"].tap()
        let longer = try XCTUnwrap(restSeconds(rest), "Rest: \(rest.label)")
        XCTAssertGreaterThan(longer, started + 5, "+15 did not add time")
        attachScreenshot(named: "63-session-last-time-rest", of: app)
        app.buttons["session.rest.skip"].tap()
        XCTAssertTrue(rest.waitForNonExistence(timeout: 10), "Pular did not end the rest")

        // Checking another set starts the rest again; −15 takes it to zero and no further, which ends it.
        checks(in: app).element(boundBy: 1).tap()
        XCTAssertTrue(rest.waitForExistence(timeout: 10), "No rest after checking the second set")
        let minus = app.buttons["session.rest.minus"]
        var taps = 0
        while let seconds = restSeconds(rest), seconds > 15, taps < 8 {
            minus.tap()
            taps += 1
        }
        minus.tap()
        XCTAssertTrue(rest.waitForNonExistence(timeout: 10), "The rest did not end at zero")
    }

    @MainActor
    func testFinishedExerciseClosesAndOpens() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: [push, "last-time:Push"])
        startWorkout(named: "Push", in: app)

        for index in 0..<3 {
            checks(in: app).element(boundBy: index).tap()
        }
        let done = app.buttons["session.exercise.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The finished exercise did not close")
        XCTAssertEqual(done.label, "Supino Reto com Barra, concluído: 3 de 3 séries, 60 kg × 10 · 10 · 9")
        XCTAssertFalse(done.isSelected, "The finished exercise reads as selected")
        XCTAssertEqual(element("session.progress", in: app).label, "3 de 12 séries, Exercício 2 de 4")
        XCTAssertTrue(app.buttons["Série 1, atual"].exists, "The next exercise's first set is not the current one")
        attachScreenshot(named: "64-session-exercise-done", of: app)

        // Tapping opens it; a set unchecked keeps it open, and checking it again closes it.
        done.tap()
        let close = app.buttons["session.exercise.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), "The finished exercise did not open")
        let third = checks(in: app).element(boundBy: 2)
        XCTAssertTrue(third.isSelected, "Opened with a set not done")
        third.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10), "Still finished after unchecking a set")
        XCTAssertFalse(checks(in: app).element(boundBy: 2).isSelected, "The set unchecked still reads as selected")
        XCTAssertFalse(done.exists, "Closed with a set not done")
        checks(in: app).element(boundBy: 2).tap()
        XCTAssertTrue(done.waitForExistence(timeout: 10), "Did not close again once finished")

        // Opened, it closes from its chevron.
        done.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 10), "The finished exercise did not open again")
        close.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The chevron did not close it")

        // With the rest bar on screen, the end of the list stays above it: neither the last set nor
        // "+ Adicionar exercício" is covered.
        let rest = element("session.rest", in: app)
        XCTAssertTrue(rest.exists, "No rest bar")
        for _ in 0..<5 {
            dragListUp(in: app)
        }
        let addExercise = app.buttons["session.addExercise"]
        XCTAssertTrue(addExercise.waitForExistence(timeout: 10), "No + Adicionar exercício at the end of the list")
        let lastCheck = try XCTUnwrap(checks(in: app).allElementsBoundByIndex.last, "No set at the end of the list")
        let lastSet = lastCheck.frame
        let restTop = rest.frame.minY
        recordMeasurement(
            "Medição: fim da lista com o descanso",
            "última série \(Int(lastSet.minY))–\(Int(lastSet.maxY)), Adicionar exercício \(Int(addExercise.frame.minY))–\(Int(addExercise.frame.maxY)), barra de descanso a partir de \(Int(restTop))"
        )
        XCTAssertLessThanOrEqual(lastSet.maxY, restTop, "The rest bar covers the last set")
        XCTAssertLessThanOrEqual(addExercise.frame.maxY, restTop, "The rest bar covers + Adicionar exercício")
        attachScreenshot(named: "68-session-end-of-list-rest", of: app)
    }

    @MainActor
    func testRemovingSetsAndExercises() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Pull:Barra Fixa Pronada|Rosca Direta com Barra"])
        startWorkout(named: "Pull", in: app)
        XCTAssertTrue(waitForCount(checks(in: app), 6), "The session should have 6 sets")

        // A set not done goes with the second tap, on the button the swipe shows.
        let firstRow = app.descendants(matching: .any).matching(identifier: "session.set").element(boundBy: 0)
        let remove = app.buttons["Remover"]
        firstRow.swipeLeft()
        XCTAssertTrue(remove.waitForExistence(timeout: 10), "No Remover after swiping")
        remove.tap()
        XCTAssertTrue(waitForCount(checks(in: app), 5), "Set not removed")

        // A set done asks first.
        checks(in: app).element(boundBy: 0).tap()
        firstRow.swipeLeft()
        XCTAssertTrue(remove.waitForExistence(timeout: 10), "No Remover after swiping a set done")
        remove.tap()
        let confirmSet = app.buttons["Remover série"]
        XCTAssertTrue(confirmSet.waitForExistence(timeout: 10), "No confirmation for a set done")
        confirmSet.tap()
        XCTAssertTrue(waitForCount(checks(in: app), 4), "Set done not removed")

        // An exercise without sets done goes at once.
        app.buttons["Opções de Barra Fixa Pronada"].tap()
        let removeExercise = app.buttons["Remover exercício"]
        XCTAssertTrue(removeExercise.waitForExistence(timeout: 10), "No Remover exercício in the ⋯ menu")
        removeExercise.tap()
        XCTAssertTrue(app.buttons["Opções de Barra Fixa Pronada"].waitForNonExistence(timeout: 10), "Exercise not removed")
        XCTAssertTrue(waitForCount(checks(in: app), 3), "The other exercise lost sets")

        // One with a set done asks first.
        checks(in: app).element(boundBy: 0).tap()
        app.buttons["Opções de Rosca Direta com Barra"].tap()
        XCTAssertTrue(removeExercise.waitForExistence(timeout: 10), "No Remover exercício in the ⋯ menu")
        removeExercise.tap()
        XCTAssertTrue(app.staticTexts["Remover este exercício?"].waitForExistence(timeout: 10), "No confirmation for an exercise with sets done")
        app.buttons["Remover exercício"].tap()
        XCTAssertTrue(element("session.empty", in: app).waitForExistence(timeout: 10), "Exercise with sets done not removed")
        XCTAssertEqual(element("session.progress", in: app).label, "0 de 0 séries")
    }

    @MainActor
    func testTypedLoadIsKeptWhenItsRowLeavesTheScreenAndTheKeyboardLeavesTheFieldInSight() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: [push])
        startWorkout(named: "Push", in: app)

        // A load typed in the first set, which then scrolls out of sight with the keyboard still up:
        // its row is gone, or under the header.
        let weight = weightFields(in: app).element(boundBy: 0)
        XCTAssertTrue(weight.waitForExistence(timeout: 10), "No load field")
        weight.tap()
        weight.typeText("42")
        XCTAssertFalse(checks(in: app).element(boundBy: 0).isSelected, "Set 1, not done, reads as selected")
        let firstSet = app.buttons["Série 1, atual"]
        let headerBottom = element("session.progress", in: app).frame.maxY
        var positions: [String] = []
        while firstSet.exists, firstSet.frame.maxY > headerBottom, positions.count < 5 {
            dragListUp(in: app)
            positions.append(firstSet.exists ? "\(Int(firstSet.frame.minY))" : "fora")
        }
        recordMeasurement(
            "Medição: série 1 ao rolar com o teclado",
            "cabeçalho até \(Int(headerBottom)); série 1 depois de cada arrasto: \(positions.joined(separator: ", "))"
        )
        XCTAssertFalse(firstSet.exists && firstSet.frame.maxY > headerBottom, "The first set did not leave the screen: \(positions)")

        // Minimized and opened again, the screen is built anew from what was saved.
        app.buttons["session.minimize"].tap()
        let bar = app.buttons["session.bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Session bar not shown")
        bar.tap()
        XCTAssertTrue(weightFields(in: app).element(boundBy: 0).waitForExistence(timeout: 10), "Session not opened again")
        XCTAssertEqual(weightFields(in: app).element(boundBy: 0).value as? String, "42", "The typed load was lost")

        // A field near the end of the list stays above the keyboard while typing.
        for _ in 0..<4 {
            dragListUp(in: app)
        }
        let lastReps = repsFields(in: app).allElementsBoundByIndex.last
        let target = try XCTUnwrap(lastReps, "No repetition field at the end of the list")
        let before = target.frame
        target.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10), "No keyboard")
        // The list moves to keep the field in sight, which changes the order of its rows: the field is
        // found again by its focus, not by its place in the list.
        let field = app.textFields.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No field with the focus")
        XCTAssertEqual(field.identifier, "session.set.reps")
        XCTAssertEqual(field.label, "Repetições da série 3")
        field.typeText("8")
        // Nothing of the keyboard, not even the OK of its bar, reaches the field.
        let ok = app.buttons["OK"]
        let covered = min(keyboard.frame.minY, ok.exists ? ok.frame.minY : keyboard.frame.minY)
        let okText = ok.exists ? "\(ok.frame)" : "nenhum"
        recordMeasurement(
            "Medição: campo perto do fim com o teclado",
            "campo em \(Int(before.minY))–\(Int(before.maxY)) antes do teclado, \(Int(field.frame.minY))–\(Int(field.frame.maxY)) depois; teclado a partir de \(Int(keyboard.frame.minY)), OK em \(okText)"
        )
        XCTAssertLessThanOrEqual(field.frame.maxY, covered, "The keyboard hides the field: \(field.frame), keyboard from \(covered)")
        XCTAssertEqual(field.value as? String, "8")
    }

    @MainActor
    func testSetDoneWithoutALoadShowsADashAndTakesOne() throws {
        continueAfterFailure = false
        // The session left open has its first set done with 10 repetitions and no load; the last time
        // suggests 60 kg for the sets still to do.
        let app = launchOnTab("Treinos", seed: [push, "last-time:Push", "open-session:Push"])
        let bar = app.buttons["session.bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Session bar not shown")
        bar.tap()
        let weight = weightFields(in: app).element(boundBy: 0)
        XCTAssertTrue(weight.waitForExistence(timeout: 10), "Session not opened from the bar")
        XCTAssertTrue(checks(in: app).element(boundBy: 0).isSelected, "Set 1 is not done")

        // Done without a load: "—" on screen and "Sem carga" for VoiceOver, never the suggestion.
        XCTAssertEqual(weight.placeholderValue, "—")
        XCTAssertEqual(weight.value as? String, "Sem carga")
        XCTAssertEqual(weightFields(in: app).element(boundBy: 1).placeholderValue, "60", "A set to do lost its suggestion")
        XCTAssertEqual(element("session.volume", in: app).label, "0 kg levantados")
        attachScreenshot(named: "69-session-done-without-load", of: app)

        // A load typed in it is recorded and counted, and the set stays done.
        weight.tap()
        weight.typeText("50")
        app.buttons["OK"].tap()
        XCTAssertTrue(waitForLabel(of: element("session.volume", in: app), toBe: "500 kg levantados"), "Volume: \(element("session.volume", in: app).label)")
        XCTAssertEqual(weight.value as? String, "50")
        XCTAssertTrue(checks(in: app).element(boundBy: 0).isSelected, "Set 1 is no longer done")

        // Minimized and opened again, the screen shows what was saved.
        app.buttons["session.minimize"].tap()
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Session bar not shown")
        bar.tap()
        XCTAssertTrue(weightFields(in: app).element(boundBy: 0).waitForExistence(timeout: 10), "Session not opened again")
        XCTAssertEqual(weightFields(in: app).element(boundBy: 0).value as? String, "50", "The load typed was lost")
        XCTAssertEqual(element("session.volume", in: app).label, "500 kg levantados")
    }

    @MainActor
    func testLargeTextKeepsTheSessionOnScreen() throws {
        continueAfterFailure = false
        // A session already open, and the last time of its workout.
        let seed = [push, "last-time:Push", "open-session:Push"]

        for (size, name) in [("UICTContentSizeCategoryXXXL", "66-session-xxxl"), ("UICTContentSizeCategoryAccessibilityXXXL", "67-session-accessibility")] {
            let app = launchOnTab("Treinos", seed: seed, extraArguments: ["-UIPreferredContentSizeCategoryName", size])
            let bar = app.buttons["session.bar"]
            XCTAssertTrue(bar.waitForExistence(timeout: 10), "Session bar not shown with \(size)")
            bar.tap()
            XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session not opened with \(size)")
            // With the largest sizes a set takes two lines: the second one may be just below the screen.
            let second = checks(in: app).element(boundBy: 1)
            if !second.waitForExistence(timeout: 3) {
                dragListUp(in: app)
            }
            XCTAssertTrue(second.waitForExistence(timeout: 10), "No second set with \(size)")
            second.tap()
            let rest = element("session.rest", in: app)
            XCTAssertTrue(app.buttons["session.rest.skip"].waitForExistence(timeout: 10), "No rest bar with \(size)")

            // The header and the rest bar, which stay in place, leave the sets at least a third of the screen.
            let screen = app.windows.firstMatch.frame
            let headerBottom = element("session.progress", in: app).frame.maxY
            let room = rest.frame.minY - headerBottom
            recordMeasurement(
                "Medição: espaço das séries com \(size)",
                "cabeçalho até \(Int(headerBottom)), barra de descanso de \(Int(rest.frame.minY)) a \(Int(rest.frame.maxY)), espaço \(Int(room)) de \(Int(screen.height)) pt"
            )
            XCTAssertGreaterThanOrEqual(room, screen.height / 3, "The header and the rest bar leave the sets \(room) pt with \(size)")
            let elements = [
                ("finish", app.buttons["session.finish"]),
                ("minimize", app.buttons["session.minimize"]),
                ("menu", app.buttons["session.more"]),
                ("load", weightFields(in: app).element(boundBy: 1)),
                ("repetitions", repsFields(in: app).element(boundBy: 1)),
                ("mark", checks(in: app).element(boundBy: 1)),
                ("skip", app.buttons["session.rest.skip"]),
            ]
            for (label, element) in elements {
                XCTAssertTrue(element.exists, "No \(label) with \(size)")
                XCTAssertTrue(
                    element.frame.minX >= screen.minX && element.frame.maxX <= screen.maxX,
                    "The \(label) is not on the screen with \(size): \(element.frame) on \(screen)"
                )
            }
            attachScreenshot(named: name, of: app)
            app.terminate()
        }
    }
}
