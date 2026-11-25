import XCTest

/// The exercise screen ("Detalhe do exercício e Mapa dos músculos"): opened from the Exercícios tab and
/// from "Ver exercício" in the workout editor and in the session; the muscles, the kind of machine and its
/// sheet; the evolution with its periods and metrics; the history; the states never done, done once and
/// Graviton. The screenshots 108 to 112 use the prototype's history and its "today", 16 October 2026.
final class ExerciseDetailUITests: IronFlowUITestCase {
    /// The prototype's history and its "today".
    private let prototype = ["prototype-history"]
    private let prototypeToday = ["-ui-today", "2026-10-16"]

    // MARK: - Helpers

    /// On the Exercícios tab: searches `search`, lets the keyboard go and opens the exercise `name`.
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
        card.tap()
        waitForExerciseScreen(of: name, in: app)
    }

    /// Waits for the exercise screen of `name`, its title read by one query.
    @MainActor
    private func waitForExerciseScreen(of name: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let title = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label == %@", "exercise.title", name))
            .firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 20), "Exercise screen of \(name) not shown", file: file, line: line)
    }

    @MainActor
    private func launchOnExercises() -> XCUIApplication {
        launchOnTab("Exercícios", seed: prototype, extraArguments: prototypeToday)
    }

    // MARK: - From the Exercícios tab

    @MainActor
    func testOpenFromTheListBackAndTheTab() throws {
        continueAfterFailure = false
        let app = launchOnExercises()
        // The row ends with the › of a row that opens something.
        XCTAssertTrue(element("exercises.total", in: app).waitForExistence(timeout: 10), "Exercícios not shown")
        openExercise("Supino Reto (Barra)", search: "supino reto barra", in: app)

        XCTAssertEqual(element("exercise.subtitle", in: app).label, "Peito · Barra")
        XCTAssertEqual(app.buttons["exercise.back"].label, "Exercícios")
        // The tab bar stays, with Exercícios chosen.
        let tab = app.tabBars.buttons["Exercícios"]
        XCTAssertTrue(tab.exists && tab.isHittable, "No tab bar on the exercise screen")
        XCTAssertTrue(tab.isSelected, "Exercícios is not the tab chosen")

        XCTAssertEqual(element("exercise.muscles", in: app).label, "Músculos principais: Peitoral. Secundários: Tríceps, Deltoide anterior.")
        XCTAssertEqual(element("exercise.muscles", in: app).value as? String, "Foco: Peitoral médio")
        XCTAssertFalse(element("exercise.machine", in: app).exists, "A kind of machine for a barbell exercise")
        XCTAssertEqual(element("exercise.lastTime", in: app).value as? String, "62 kg × 10, sex, 9 out")
        XCTAssertEqual(element("exercise.bestSet", in: app).value as? String, "62 kg × 10, sex, 9 out")
        XCTAssertEqual(element("exercise.chart.value", in: app).label, "62 kg")
        XCTAssertEqual(element("exercise.chart.date", in: app).label, "Maior carga · sex, 9 out")
        XCTAssertEqual(element("exercise.chart.change", in: app).label, "▲ 6 kg nos últimos 3 meses")
        XCTAssertEqual(element("exercise.chart.plot", in: app).label, "Maior carga: de 56 kg em qui, 23 jul a 62 kg em sex, 9 out")
        attachScreenshot(named: "108-exercise-detail", of: app)

        // Back to the list with "‹ Exercícios".
        app.buttons["exercise.back"].tap()
        XCTAssertTrue(element("exercises.total", in: app).waitForExistence(timeout: 10), "Exercícios not shown after ‹")

        // Opened again, the tab takes it back to the list.
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "exercises.card", "Supino Reto (Barra), "))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The search was not kept")
        card.tap()
        waitForExerciseScreen(of: "Supino Reto (Barra)", in: app)
        tab.tap()
        XCTAssertTrue(element("exercises.total", in: app).waitForExistence(timeout: 10), "The tab did not go back to the list")
        XCTAssertFalse(element("exercise.screen", in: app).exists, "The exercise screen is still open")
    }

    @MainActor
    func testPeriodMetricChartHistoryAndShowMore() throws {
        continueAfterFailure = false
        let app = launchOnExercises()
        openExercise("Supino Reto (Barra)", search: "supino reto barra", in: app)
        let change = element("exercise.chart.change", in: app)
        let date = element("exercise.chart.date", in: app)

        // The period menu of iOS, with a ✓ on the one chosen.
        let period = app.buttons["exercise.chart.period"]
        XCTAssertEqual(period.label, "Período: 3 meses")
        period.tap()
        let year = app.buttons["1 ano"]
        XCTAssertTrue(year.waitForExistence(timeout: 10), "Period menu not shown")
        XCTAssertTrue(app.buttons["3 meses"].isSelected, "3 meses is not marked")
        year.tap()
        XCTAssertTrue(waitForLabel(of: change, toBe: "▲ 12 kg no último ano"), "Change: \(change.label)")
        period.tap()
        let all = app.buttons["Tudo"]
        XCTAssertTrue(all.waitForExistence(timeout: 10), "Period menu not shown")
        all.tap()
        XCTAssertTrue(waitForLabel(of: change, toBe: "▲ 12 kg desde o primeiro treino"), "Change: \(change.label)")
        XCTAssertEqual(period.label, "Período: Tudo")

        // The metric: Volume, from the working and failure sets.
        app.buttons["exercise.chart.metric.1"].tap()
        XCTAssertTrue(waitForLabel(of: date, toBe: "Volume · sex, 9 out"), "Metric: \(date.label)")
        XCTAssertEqual(element("exercise.chart.value", in: app).label, "1.820 kg")
        XCTAssertTrue(app.buttons["exercise.chart.metric.1"].isSelected, "Volume is not marked")

        // A tap at the start of the chart chooses the first session: its value and day, without the change.
        let plot = element("exercise.chart.plot", in: app)
        plot.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap()
        XCTAssertTrue(waitForLabel(of: date, toBe: "Volume · qua, 29 abr"), "Chosen: \(date.label)")
        XCTAssertFalse(change.exists, "The change is shown with an older session chosen")
        attachScreenshot(named: "114-exercise-detail-chart-chosen", of: app)
        // A drag along the chart to its end chooses the most recent again, and the change comes back.
        let start = plot.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: plot.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)))
        XCTAssertTrue(waitForLabel(of: date, toBe: "Volume · sex, 9 out"), "After the drag: \(date.label)")
        XCTAssertTrue(change.waitForExistence(timeout: 10), "The change did not come back")

        // An up drag that starts on the chart scrolls the screen.
        let title = element("exercise.title", in: app)
        let titleTop = title.frame.minY
        plot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            .press(forDuration: 0.05, thenDragTo: plot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1.5)))
        let deadline = Date().addingTimeInterval(10)
        while title.exists, title.frame.minY >= titleTop - 50, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(!title.exists || title.frame.minY < titleTop - 50, "The screen did not scroll from the chart")

        // The history: 24 sessions, the 5 most recent, then 10 more.
        scrollToBottom(in: app)
        XCTAssertEqual(element("exercise.history.count", in: app).label, "24 treinos")
        let sessions = app.buttons.matching(identifier: "exercise.history.session")
        XCTAssertEqual(sessions.count, 5)
        XCTAssertTrue(sessions.element(boundBy: 0).label.hasPrefix("Push, sex, 9 out. Série 1, Aquecimento: 40 kg × 15. Série 2, Preparatória: 50 kg × 6. Série 3, Válida: 62 kg × 10, melhor série"), "First session: \(sessions.element(boundBy: 0).label)")
        attachScreenshot(named: "115-exercise-detail-history", of: app)
        app.buttons["exercise.history.more"].tap()
        // The list is lazy: a card is made as it comes into sight, so the 15 are checked by scrolling down to
        // the 15th (1 July) and seeing that the 16th (25 June) is not there and that Mostrar mais still is.
        func card(_ prefix: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "exercise.history.session", prefix)).firstMatch
        }
        let fifteenth = card("Push, qua, 1 jul.")
        let more = app.buttons["exercise.history.more"]
        // Down to the end of the screen: Mostrar mais, right below the last card shown.
        var swipes = 0
        while swipes < 10, !(fifteenth.exists && more.exists && more.isHittable && more.frame.maxY < app.frame.maxY - 60) {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(fifteenth.exists && fifteenth.isHittable, "The 15th session is not shown after Mostrar mais")
        XCTAssertTrue(more.exists, "No Mostrar mais with 9 sessions left")
        XCTAssertFalse(card("Push, qui, 25 jun.").exists, "A 16th session is shown")

        // A session opens its detail, the one of the Histórico.
        fifteenth.tap()
        XCTAssertTrue(element("history.detail", in: app).waitForExistence(timeout: 10), "The session detail did not open")
    }

    // MARK: - States

    @MainActor
    func testGravitonShowsTheHelp() throws {
        continueAfterFailure = false
        let app = launchOnExercises()
        openExercise("Barra Fixa (Graviton)", search: "barra fixa graviton", in: app)

        XCTAssertEqual(element("exercise.subtitle", in: app).label, "Dorsais · Máquina")
        XCTAssertEqual(element("exercise.machine", in: app).label, "Graviton (contrapeso), Mais kg = mais ajuda. Menos kg é progresso.")
        XCTAssertEqual(element("exercise.lastTime", in: app).value as? String, "25 kg × 8, de ajuda · seg, 12 out")
        XCTAssertEqual(app.buttons["exercise.chart.metric.0"].label, "Menor ajuda")
        XCTAssertEqual(element("exercise.chart.change", in: app).label, "▲ 10 kg a menos de ajuda nos últimos 3 meses")
        XCTAssertTrue(app.staticTexts["Menos ajuda fica mais alto no gráfico."].exists, "No note on the upside-down chart")
        attachScreenshot(named: "109-exercise-detail-graviton", of: app)

        scrollToBottom(in: app)
        XCTAssertEqual(element("exercise.history.count", in: app).label, "25 treinos · kg é a ajuda")
        // "Mais repetições" is not upside down.
        scrollToTop(in: app)
        app.buttons["exercise.chart.metric.1"].tap()
        XCTAssertTrue(waitForLabel(of: element("exercise.chart.change", in: app), toBe: "▲ 2 reps nos últimos 3 meses"), "Change: \(element("exercise.chart.change", in: app).label)")
        XCTAssertFalse(app.staticTexts["Menos ajuda fica mais alto no gráfico."].exists, "The note stayed on Mais repetições")
    }

    @MainActor
    func testMachineTypeAndItsSheet() throws {
        continueAfterFailure = false
        let app = launchOnExercises()
        openExercise("Leg Press 45° (Máquina)", search: "leg press 45", in: app)

        let machine = element("exercise.machine", in: app)
        XCTAssertEqual(machine.label, "Trilho (anilhas), Tipo de máquina")
        XCTAssertEqual(element("exercise.chart.change", in: app).label, "▲ 20 kg nos últimos 3 meses")
        attachScreenshot(named: "110-exercise-detail-machine", of: app)

        machine.tap()
        let current = element("machineTypes.current", in: app)
        XCTAssertTrue(current.waitForExistence(timeout: 10), "Tipos de máquina not shown")
        XCTAssertTrue(current.label.contains("Trilho (anilhas)") && current.label.contains("ESTE"), "Current: \(current.label)")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "machineTypes.row").count, 4)
        attachScreenshot(named: "113-machine-types-sheet", of: app)
        app.buttons["machineTypes.done"].tap()
        XCTAssertTrue(current.waitForNonExistence(timeout: 10), "The sheet did not close")
    }

    @MainActor
    func testDoneOnceAndNeverDone() throws {
        continueAfterFailure = false
        let app = launchOnExercises()
        openExercise("Elevação Lateral (Halter)", search: "elevacao lateral halter", in: app)
        XCTAssertEqual(element("exercise.chart.message", in: app).label, "Faça este exercício em mais um treino para ver a evolução.")
        XCTAssertFalse(app.buttons["exercise.chart.period"].exists, "A period menu with one session")
        XCTAssertEqual(element("exercise.lastTime", in: app).value as? String, "10 kg × 12, sex, 9 out")
        attachScreenshot(named: "111-exercise-detail-once", of: app)
        scrollToBottom(in: app)
        XCTAssertEqual(element("exercise.history.count", in: app).label, "1 treino")
        app.buttons["exercise.back"].tap()

        // Cleared, the search finds the exercise never done.
        let clear = app.buttons["exercises.search.clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 10), "No clear button")
        clear.tap()
        openExercise("Cadeira Flexora (Máquina)", search: "cadeira flexora maquina", in: app)
        XCTAssertTrue(element("exercise.neverDone", in: app).exists, "No card for an exercise never done")
        XCTAssertFalse(element("exercise.lastTime", in: app).exists, "Última vez without a session")
        XCTAssertFalse(element("exercise.chart", in: app).exists, "A chart without a session")
        XCTAssertFalse(element("exercise.history.count", in: app).exists, "A history without a session")
        attachScreenshot(named: "112-exercise-detail-never", of: app)
    }

    /// Two sessions of the same day are two points: a tap on the left chooses the first, one on the right
    /// the last (the change shows only with the last). With the points by day, both taps chose the first.
    @MainActor
    func testTwoSessionsOnTheSameDayAreTwoPoints() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", seed: ["workout:Push:Supino Reto (Barra)", "finished:Push:2"])
        openExercise("Supino Reto (Barra)", search: "supino reto barra", in: app)
        app.buttons["exercise.chart.period"].tap()
        let all = app.buttons["Tudo"]
        XCTAssertTrue(all.waitForExistence(timeout: 10), "Period menu not shown")
        all.tap()
        let change = element("exercise.chart.change", in: app)
        XCTAssertTrue(waitForLabel(of: change, containing: "desde o primeiro treino"), "Tudo not shown")
        let plot = element("exercise.chart.plot", in: app)
        plot.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap()
        XCTAssertTrue(change.waitForNonExistence(timeout: 10), "The first session was not chosen")
        plot.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.5)).tap()
        XCTAssertTrue(change.waitForExistence(timeout: 10), "The second session of the day cannot be chosen")
    }

    /// A session deleted since the screen read its history: the notice, and the history read again.
    @MainActor
    func testTappingADeletedSessionSaysSo() throws {
        continueAfterFailure = false
        let app = launchOnTab(
            "Exercícios",
            seed: ["workout:Push:Supino Reto (Barra)", "finished:Push:2"],
            extraArguments: ["-ui-delete-tapped-session"] + longToastArguments
        )
        openExercise("Supino Reto (Barra)", search: "supino reto barra", in: app)
        scrollToBottom(in: app)
        let count = element("exercise.history.count", in: app)
        XCTAssertEqual(count.label, "2 treinos")
        let session = app.buttons.matching(identifier: "exercise.history.session").firstMatch
        XCTAssertTrue(session.waitForExistence(timeout: 10), "No session card")
        session.tap()
        XCTAssertTrue(waitForToast("Esse treino não está mais no histórico.", in: app), "No notice for a session no longer there")
        XCTAssertFalse(element("history.detail", in: app).exists, "A deleted session opened")
        XCTAssertTrue(waitForLabel(of: element("exercise.history.count", in: app), toBe: "1 treino"), "The history was not read again")
    }

    @MainActor
    func testThreeYearsOpenWithoutHanging() throws {
        continueAfterFailure = false
        let app = launchOnTab("Exercícios", seed: ["exercise-years:Rosca Direta (Halter):3"])
        let opened = Date()
        openExercise("Rosca Direta (Halter)", search: "rosca direta halter", in: app)
        XCTAssertTrue(element("exercise.chart.plot", in: app).waitForExistence(timeout: 10), "No chart")
        recordMeasurement("Medição: abrir o detalhe com 3 anos (312 treinos)", String(format: "%.1f s da busca ao gráfico", Date().timeIntervalSince(opened)))
        app.buttons["exercise.chart.period"].tap()
        let all = app.buttons["Tudo"]
        XCTAssertTrue(all.waitForExistence(timeout: 10), "Period menu not shown")
        all.tap()
        XCTAssertTrue(waitForLabel(of: element("exercise.chart.change", in: app), containing: "desde o primeiro treino"), "Tudo not shown")
        scrollToBottom(in: app)
        XCTAssertEqual(element("exercise.history.count", in: app).label, "312 treinos")
    }

    @MainActor
    func testLargeTextKeepsTheScreenReadable() throws {
        continueAfterFailure = false
        let app = launchOnTab(
            "Exercícios",
            seed: prototype,
            extraArguments: prototypeToday + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )
        openExercise("Supino Reto (Barra)", search: "supino reto barra", in: app)
        let screen = app.windows.firstMatch.frame
        let muscles = element("exercise.muscles", in: app)
        XCTAssertTrue(muscles.exists, "No muscles")
        XCTAssertLessThanOrEqual(muscles.frame.maxX, screen.maxX, "The muscles card goes past the screen")
        attachScreenshot(named: "116-exercise-detail-large-text", of: app)
        scrollToBottom(in: app)
        let card = app.buttons.matching(identifier: "exercise.history.session").firstMatch
        XCTAssertTrue(card.exists, "No session card")
        XCTAssertLessThanOrEqual(card.frame.maxX, screen.maxX, "A session card goes past the screen")
    }

    // MARK: - From the session and the editor

    @MainActor
    func testOpenFromTheSessionWhileTheRestGoesOn() throws {
        continueAfterFailure = false
        let app = launchOnTab(
            "Treinos",
            seed: ["workout:Push:Supino Reto (Barra)|Supino Inclinado (Halter)", "rest:Push:30"],
            extraArguments: longToastArguments
        )
        startWorkout(named: "Push", in: app)
        app.buttons.matching(identifier: "session.set.check").element(boundBy: 0).tap()
        XCTAssertTrue(element("session.rest.time", in: app).waitForExistence(timeout: 10), "No rest after checking a set")
        app.buttons["session.rest.minus"].tap()

        app.buttons.matching(identifier: "session.exercise.menu").element(boundBy: 0).tap()
        let show = app.buttons["Ver exercício"]
        XCTAssertTrue(show.waitForExistence(timeout: 10), "No Ver exercício in the menu")
        show.tap()
        waitForExerciseScreen(of: "Supino Reto (Barra)", in: app)
        XCTAssertEqual(app.buttons["exercise.back"].label, "Push")
        XCTAssertTrue(waitForHiddenTabBar(in: app), "A tab bar over the session")
        // The session in progress never counts: the set just done is not history.
        XCTAssertTrue(element("exercise.neverDone", in: app).exists, "The session in progress counted")

        // The rest goes on: its end is the notice at the top, as on the app's other screens.
        XCTAssertTrue(
            waitForToast("Descanso acabou. Próxima: Supino Reto (Barra) · série 2 de 3", in: app, timeout: 30),
            "No notice at the end of the rest on the exercise screen"
        )
        attachScreenshot(named: "117-exercise-detail-from-session", of: app)

        app.buttons["exercise.back"].tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Not back to the session")
        XCTAssertTrue(app.buttons.matching(identifier: "session.set.check").element(boundBy: 0).isSelected, "The set done was lost")
    }

    @MainActor
    func testOpenFromTheEditorAndBack() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Push:Supino Reto (Barra)|Supino Inclinado (Halter)"])
        openWorkout(named: "Push", in: app)
        app.buttons.matching(identifier: "workout.exercise.menu").element(boundBy: 1).tap()
        let show = app.buttons["Ver exercício"]
        XCTAssertTrue(show.waitForExistence(timeout: 10), "No Ver exercício in the menu")
        show.tap()
        waitForExerciseScreen(of: "Supino Inclinado (Halter)", in: app)
        XCTAssertEqual(app.buttons["exercise.back"].label, "Push")
        XCTAssertTrue(waitForHiddenTabBar(in: app), "A tab bar on the exercise screen opened from the editor")

        app.buttons["exercise.back"].tap()
        waitForEditor(of: "Push", in: app)
        XCTAssertTrue(waitForHiddenTabBar(in: app), "A tab bar on the editor")
    }

    // MARK: - Kg lifted

    @MainActor
    func testGravitonSetsStayOutOfTheKgLifted() throws {
        continueAfterFailure = false
        // Last time: the Graviton with 60 kg of help and the row with 22 kg, as suggestions now.
        let app = launchOnTab(
            "Treinos",
            seed: ["workout:Costas:Barra Fixa (Graviton)|Remada Curvada (Barra)", "last-time:Costas"],
            extraArguments: longToastArguments
        )
        startWorkout(named: "Costas", in: app)
        let checks = app.buttons.matching(identifier: "session.set.check")
        let volume = element("session.volume", in: app)

        checks.element(boundBy: 0).tap()
        XCTAssertTrue(checks.element(boundBy: 0).isSelected, "Graviton set not checked")
        XCTAssertEqual(volume.label, "0 kg levantados")
        let rest = element("session.rest.time", in: app)
        if rest.waitForExistence(timeout: 5) {
            app.buttons["session.rest.skip"].tap()
        }
        checks.element(boundBy: 3).tap()
        XCTAssertTrue(waitForLabel(of: volume, toBe: "220 kg levantados"), "Volume: \(volume.label)")

        app.buttons["session.finish"].tap()
        let finishVolume = element("finish.volume", in: app)
        XCTAssertTrue(finishVolume.waitForExistence(timeout: 10), "Concluir treino? not shown")
        XCTAssertEqual(finishVolume.label, "220 kg levantados")
        app.buttons["finish.save"].tap()
        XCTAssertTrue(waitForToast("Treino salvo · 2 séries · 220 kg", in: app), "No Treino salvo with the kg without Graviton")
    }
}
