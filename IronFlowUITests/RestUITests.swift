import XCTest

/// The rest between sets (S4-F): each exercise's rest in the editor, the app's offer of the end-of-rest
/// notice at the first rest (with the iPhone's permission simulated: `-ui-notifications` and
/// `-ui-notification-answer`), "Opções do treino", the end of the rest on the session screen and on
/// another screen, and a session that survives the app being closed and opened again.
final class RestUITests: IronFlowUITestCase {
    /// Push with four exercises of the built-in library, like the model, the first with the sets of the
    /// editor's model (5 sets).
    private let push = "workout:Push:Supino Reto (Barra)|Supino Inclinado (Halter)|Desenvolvimento (Halter)|Tríceps Corda (Polia)"
    private let setTypes = "set-types:Push"

    @MainActor
    private func checks(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "session.set.check")
    }

    @MainActor
    private func restCapsules(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "workout.rest")
    }

    /// The seconds the rest bar shows ("Descanso, 1:24" → 84).
    @MainActor
    private func restSeconds(_ element: XCUIElement) -> Int? {
        guard let match = element.label.firstMatch(of: /(\d+):(\d{2})/),
              let minutes = Int(match.1),
              let seconds = Int(match.2) else { return nil }
        return minutes * 60 + seconds
    }

    /// Launches on Treinos with the simulated permission and starts Push.
    @MainActor
    private func startPush(
        seed: [String] = [],
        notifications: String? = nil,
        answer: String? = nil,
        readySeconds: Int? = nil,
        longToasts: Bool = false
    ) -> XCUIApplication {
        var arguments: [String] = longToasts ? longToastArguments : []
        if let readySeconds {
            arguments += ["-ui-rest-ready-seconds", "\(readySeconds)"]
        }
        if let notifications {
            arguments += ["-ui-notifications", notifications]
        }
        if let answer {
            arguments += ["-ui-notification-answer", answer]
        }
        let app = launchOnTab("Treinos", seed: [push, setTypes] + seed, extraArguments: arguments)
        startWorkout(named: "Push", in: app)
        return app
    }

    /// Waits until the switch or field holds `value`.
    @MainActor
    private func waitForValue(of element: XCUIElement, toBe value: String) -> Bool {
        let holds = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [holds], timeout: 10) == .completed
    }

    // MARK: - Editor

    @MainActor
    func testRestOfEachExerciseInTheEditor() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: [push, setTypes])
        openWorkout(named: "Push", in: app)

        let first = restCapsules(in: app).element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 10), "No rest in the editor")
        XCTAssertEqual(first.label, "Descanso entre séries: 1 min 30 s")
        XCTAssertGreaterThanOrEqual(first.frame.height, 44, "The rest answers on less than 44 points")

        // 2:00 for the first exercise: the sheet closes and the capsule shows it.
        first.tap()
        let two = app.buttons["rest.option.120"]
        XCTAssertTrue(two.waitForExistence(timeout: 10), "Descanso entre séries not shown")
        XCTAssertTrue(element("rest.explanation", in: app).label.hasPrefix("Supino Reto (Barra). O timer começa"), "Explanation: \(element("rest.explanation", in: app).label)")
        XCTAssertTrue(app.buttons["rest.option.90"].isSelected, "1:30 is not the one chosen")
        XCTAssertEqual(app.buttons["rest.option.90"].label, "1 min 30 s, padrão")
        two.tap()
        XCTAssertTrue(two.waitForNonExistence(timeout: 10), "The sheet did not close")
        XCTAssertTrue(waitForLabel(of: first, toBe: "Descanso entre séries: 2 min"), "Rest: \(first.label)")
        attachScreenshot(named: "95-editor-rest", of: app)

        // The second exercise keeps 1:30; "Sem timer" stores no rest.
        let second = restCapsules(in: app).element(boundBy: 1)
        XCTAssertEqual(second.label, "Descanso entre séries: 1 min 30 s")
        second.tap()
        let none = app.buttons["rest.option.0"]
        XCTAssertTrue(none.waitForExistence(timeout: 10), "Descanso entre séries not shown for the second exercise")
        XCTAssertTrue(element("rest.explanation", in: app).label.hasPrefix("Supino Inclinado (Halter)."), "Explanation: \(element("rest.explanation", in: app).label)")
        attachScreenshot(named: "96-rest-sheet", of: app)
        none.tap()
        XCTAssertTrue(waitForLabel(of: second, toBe: "Descanso entre séries: Sem timer"), "Rest: \(second.label)")

        // Cancelar changes nothing.
        first.tap()
        XCTAssertTrue(app.buttons["rest.cancel"].waitForExistence(timeout: 10), "No Cancelar")
        app.buttons["rest.cancel"].tap()
        XCTAssertTrue(app.buttons["rest.cancel"].waitForNonExistence(timeout: 10), "Cancelar did not close the sheet")
        XCTAssertEqual(first.label, "Descanso entre séries: 2 min")

        // Kept: the editor opened again shows the same rests.
        goBackFromEditor(in: app)
        openWorkout(named: "Push", in: app)
        XCTAssertTrue(waitForLabel(of: restCapsules(in: app).element(boundBy: 0), toBe: "Descanso entre séries: 2 min"), "2:00 not kept")
        XCTAssertEqual(restCapsules(in: app).element(boundBy: 1).label, "Descanso entre séries: Sem timer")
    }

    // MARK: - The app's offer

    @MainActor
    func testFirstRestOffersTheNoticeAndAllowing() throws {
        continueAfterFailure = false
        let app = startPush(notifications: "notDetermined", answer: "allow")

        checks(in: app).element(boundBy: 0).tap()
        let accept = app.buttons["restAlert.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "Avisar quando o descanso acabar? not shown at the first rest")
        XCTAssertTrue(app.staticTexts["Avisar quando o descanso acabar?"].exists, "No title")
        XCTAssertTrue(app.buttons["restAlert.decline"].exists, "No Agora não")
        attachScreenshot(named: "97-rest-alert-offer", of: app)

        accept.tap()
        XCTAssertTrue(waitForToast("Aviso do descanso ligado", in: app), "No notice after allowing")
        XCTAssertTrue(element("session.rest", in: app).exists, "The rest stopped")
        attachScreenshot(named: "98-rest-running", of: app)

        // The options show the notice on; the screen option is off until turned on.
        app.buttons["session.more"].tap()
        let alert = app.switches["options.restAlert"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "Opções do treino not shown")
        XCTAssertEqual(alert.value as? String, "1", "The notice is not on")
        XCTAssertTrue(app.staticTexts["Avisa a próxima série mesmo com o celular bloqueado"].exists, "Not the text of the notice on")
        let screen = app.switches["options.keepScreenOn"]
        XCTAssertEqual(screen.value as? String, "0", "Manter a tela ligada is on at first")
        XCTAssertTrue(app.buttons["session.discard"].exists, "No Descartar treino")
        attachScreenshot(named: "99-session-options", of: app)

        screen.tap()
        XCTAssertTrue(waitForValue(of: screen, toBe: "1"), "Manter a tela ligada did not turn on")
        alert.tap()
        XCTAssertTrue(waitForValue(of: alert, toBe: "0"), "The notice did not turn off")
        XCTAssertTrue(app.staticTexts["Desligado: o descanso só aparece na tela"].waitForExistence(timeout: 5), "Not the text of the notice off")
        app.buttons["options.cancel"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 10), "Cancelar did not close the options")

        // The choices are kept; the offer never comes back.
        checks(in: app).element(boundBy: 1).tap()
        XCTAssertTrue(element("session.rest", in: app).waitForExistence(timeout: 10), "No rest after the second set")
        XCTAssertFalse(accept.waitForExistence(timeout: 2), "The offer came back")
        app.buttons["session.more"].tap()
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Opções do treino not shown again")
        XCTAssertEqual(screen.value as? String, "1", "Manter a tela ligada not kept")
        XCTAssertEqual(alert.value as? String, "0", "The notice turned off not kept")
        app.buttons["options.cancel"].tap()
    }

    @MainActor
    func testRefusingTheNoticeAtTheIPhoneQuestion() throws {
        continueAfterFailure = false
        let app = startPush(notifications: "notDetermined", answer: "deny")

        checks(in: app).element(boundBy: 0).tap()
        let accept = app.buttons["restAlert.accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "Avisar quando o descanso acabar? not shown")
        accept.tap()
        XCTAssertTrue(waitForToast("Sem aviso: o descanso continua aparecendo na tela", in: app), "No notice after refusing")
        XCTAssertTrue(element("session.rest", in: app).exists, "The rest stopped")
        attachScreenshot(named: "101-rest-alert-refused", of: app)

        // Refused: no switch, but the way to the iPhone's Settings.
        app.buttons["session.more"].tap()
        let settings = app.buttons["options.alertSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "No Ajustes after refusing")
        XCTAssertFalse(app.switches["options.restAlert"].exists, "The switch is still there")
        XCTAssertTrue(app.staticTexts["Desligado nos Ajustes do iPhone"].exists, "Not the text of the notice refused")
        // The sheet, which does not take the whole screen, is drawn at the scale iOS 26 gives it (about
        // 0,957): "Descartar treino" spans the screen minus the margins of 16, at that scale. The 44 points
        // of Ajustes are measured at the same scale.
        let discard = app.buttons["session.discard"]
        let scale = discard.frame.width / (app.windows.firstMatch.frame.width - 32)
        XCTAssertTrue((0.94...1.0).contains(scale), "Unexpected sheet scale \(scale): \(discard.frame)")
        XCTAssertGreaterThanOrEqual(settings.frame.height, 44 * scale - 0.5, "Ajustes answers on less than 44 points (scale \(scale))")
        attachScreenshot(named: "102-session-options-refused", of: app)
        app.buttons["options.cancel"].tap()
    }

    @MainActor
    func testNotNowAndTurningTheNoticeOnLater() throws {
        continueAfterFailure = false
        let app = startPush(notifications: "notDetermined", answer: "allow", longToasts: true)

        checks(in: app).element(boundBy: 0).tap()
        let decline = app.buttons["restAlert.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 10), "Avisar quando o descanso acabar? not shown")
        decline.tap()
        XCTAssertTrue(waitForToast("Dá para ligar depois no ⋯ do treino", in: app), "No notice after Agora não")

        // Off until turned on in the options, which asks the iPhone's question then.
        app.buttons["session.more"].tap()
        let alert = app.switches["options.restAlert"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "Opções do treino not shown")
        XCTAssertEqual(alert.value as? String, "0", "The notice is on before it was allowed")
        XCTAssertTrue(app.staticTexts["Desligado: o descanso só aparece na tela"].exists, "Not the text of the notice off")
        alert.tap()
        XCTAssertTrue(waitForValue(of: alert, toBe: "1"), "Allowing did not turn the notice on")
        app.buttons["options.cancel"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 10), "Cancelar did not close the options")

        // The offer does not come back.
        checks(in: app).element(boundBy: 1).tap()
        XCTAssertTrue(element("session.rest", in: app).waitForExistence(timeout: 10), "No rest after the second set")
        XCTAssertFalse(decline.waitForExistence(timeout: 2), "The offer came back")
    }

    // MARK: - The end of the rest

    @MainActor
    func testRestEndsOnTheSessionScreenAndOnAnotherScreen() throws {
        continueAfterFailure = false
        // Rests of 30 s, taken to 15 by −15, so the test waits as little as it can.
        // "Pronto" stays 20 s instead of 2,5 s (a test hook): one reading of the screen has taken 8 s in CI.
        // The notice at the end stays 15 s (longToastArguments); screenshot 103 shows it, taken right away.
        let app = startPush(seed: ["rest:Push:30"], readySeconds: 20, longToasts: true)

        checks(in: app).element(boundBy: 0).tap()
        let time = element("session.rest.time", in: app)
        XCTAssertTrue(time.waitForExistence(timeout: 10), "No rest after checking a set")
        let started = try XCTUnwrap(restSeconds(time), "Rest: \(time.label)")
        XCTAssertTrue((20...30).contains(started), "Not the exercise's rest of 30 s: \(time.label)")
        XCTAssertEqual(app.buttons["session.rest.minus"].label, "Menos 15 segundos")
        XCTAssertEqual(app.buttons["session.rest.plus"].label, "Mais 15 segundos")
        XCTAssertEqual(app.buttons["session.rest.skip"].label, "Pular descanso")
        app.buttons["session.rest.minus"].tap()

        // At zero: "Próxima série", "Pronto", then the bar goes.
        // Up to 15 s left after −15, with room to spare.
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Pronto"), object: time)
        XCTAssertEqual(XCTWaiter().wait(for: [ready], timeout: 25), .completed, "No Pronto at the end")
        let readyLabel = time.label
        XCTAssertTrue(readyLabel.contains("Próxima série"), "Rest: \(readyLabel)")
        attachScreenshot(named: "100-rest-ready", of: app)
        XCTAssertTrue(time.waitForNonExistence(timeout: 30), "Pronto did not go")

        // Minimized, the end is a notice at the top, and the bar shows the sets again.
        checks(in: app).element(boundBy: 1).tap()
        XCTAssertTrue(time.waitForExistence(timeout: 10), "No rest after the second set")
        app.buttons["session.rest.minus"].tap()
        app.buttons["session.minimize"].tap()
        let bar = app.buttons["session.bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Session bar not shown")
        XCTAssertTrue(
            waitForToast("Descanso acabou. Próxima: Supino Reto (Barra) · série 3 de 5", in: app, timeout: 30),
            "No notice at the end of the rest on another screen"
        )
        attachScreenshot(named: "103-rest-ended-elsewhere", of: app)
        XCTAssertTrue(waitForLabel(of: bar, containing: "2 de 14 séries"), "Session bar: \(bar.label)")
        XCTAssertFalse(bar.label.contains("Descanso"), "Session bar: \(bar.label)")
    }

    @MainActor
    func testNoRestWithSemTimer() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: ["workout:Curto:Rosca Direta (Barra)", "rest:Curto:0"])
        startWorkout(named: "Curto", in: app)
        checks(in: app).element(boundBy: 0).tap()
        XCTAssertTrue(checks(in: app).element(boundBy: 0).isSelected, "First set not checked")
        XCTAssertFalse(element("session.rest", in: app).waitForExistence(timeout: 2), "A rest started with Sem timer")
    }

    // MARK: - Closed and opened again

    @MainActor
    func testSessionSurvivesTheAppBeingClosed() throws {
        continueAfterFailure = false
        let store = "reopen-\(UUID().uuidString.prefix(8))"
        let app = launchApp(seed: [push], extraArguments: ["-ui-store", store, "-ui-store-new"])
        openTab("Treinos", in: app)
        startWorkout(named: "Push", in: app)

        let weights = app.textFields.matching(identifier: "session.set.weight")
        let reps = app.textFields.matching(identifier: "session.set.reps")
        weights.element(boundBy: 0).tapAndWaitForKeyboardFocus()
        weights.element(boundBy: 0).typeText("42")
        reps.element(boundBy: 0).tapAndWaitForKeyboardFocus()
        reps.element(boundBy: 0).typeText("11")
        checks(in: app).element(boundBy: 0).tap()
        XCTAssertTrue(checks(in: app).element(boundBy: 0).isSelected, "First set not checked")

        // Typed in the second set, not checked, then the app leaves and is closed.
        weights.element(boundBy: 1).tapAndWaitForKeyboardFocus()
        weights.element(boundBy: 1).typeText("52")
        reps.element(boundBy: 1).tapAndWaitForKeyboardFocus()
        reps.element(boundBy: 1).typeText("7")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10), "The app did not go to the background")
        app.terminate()

        // Opened again on the same store (without the seed or -ui-store-new).
        app.launchArguments = ["-ui-testing", "-ui-store", store]
        app.launch()
        openTab("Treinos", in: app)
        let bar = app.buttons["session.bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "The session in progress was lost")
        bar.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
        XCTAssertTrue(checks(in: app).element(boundBy: 0).isSelected, "The set done was lost")
        XCTAssertTrue(weights.element(boundBy: 0).waitForValue("42"), "Weight of set 1: \(String(describing: weights.element(boundBy: 0).value))")
        XCTAssertEqual(reps.element(boundBy: 0).value as? String, "11")
        XCTAssertEqual(weights.element(boundBy: 1).value as? String, "52", "The typed weight of set 2 was lost")
        XCTAssertEqual(reps.element(boundBy: 1).value as? String, "7", "The typed reps of set 2 were lost")
        XCTAssertFalse(checks(in: app).element(boundBy: 1).isSelected, "Set 2 got checked")

        // The rest goes on with the time really left.
        let time = element("session.rest.time", in: app)
        XCTAssertTrue(time.waitForExistence(timeout: 10), "The rest was lost")
        let left = try XCTUnwrap(restSeconds(time), "Rest: \(time.label)")
        XCTAssertTrue((1...89).contains(left), "Not the time left: \(time.label)")
    }
}
