import XCTest

/// The Home "Sua semana" card without a weekly plan: marking today as trained outside the app,
/// unmarking it after a confirmation, and a workout finished in the app. Works on any day of the week:
/// the tests only use today. Runs on an in-memory store with the built-in library. The ring of a week
/// with a plan is checked by `HomeScreenUITests`.
final class HomeWeekUITests: IronFlowUITestCase {
    @MainActor
    private func launchOnWeekCard() -> XCUIApplication {
        let app = launchOnHome()
        XCTAssertTrue(element("home.week", in: app).waitForExistence(timeout: 10), "Week card not shown")
        return app
    }

    @MainActor
    private func today(in app: XCUIApplication) -> XCUIElement {
        element("home.week.today", in: app)
    }

    /// Waits until the card shows `workouts` ("1 treino esta semana").
    @MainActor
    private func expectCount(_ workouts: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let count = app.staticTexts["home.week.count"]
        XCTAssertTrue(waitForLabel(of: count, toBe: workouts), "Workouts: \(count.label)", file: file, line: line)
    }

    @MainActor
    func testMarkAndUnmarkToday() throws {
        continueAfterFailure = false
        let app = launchOnWeekCard()

        // Seven days, today among them, and nothing trained yet.
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "home.week.day").count, 6)
        XCTAssertTrue(today(in: app).exists, "Today not shown")
        XCTAssertTrue(today(in: app).label.contains("hoje, sem treino"), "Today: \(today(in: app).label)")
        expectCount("0 treinos esta semana", in: app)

        // Marking today counts one workout on one day, with a notice.
        let dayNumber = Calendar(identifier: .gregorian).component(.day, from: .now)
        today(in: app).tap()
        XCTAssertTrue(
            waitForToast("Dia \(dayNumber) marcado como treinado", in: app),
            "No notice after marking: \(app.staticTexts["toast"].label)"
        )
        expectCount("1 treino esta semana", in: app)
        XCTAssertTrue(today(in: app).label.contains("hoje, marcado como feito fora do app"), "Today: \(today(in: app).label)")
        attachScreenshot(named: "38-home-week", of: app)

        // Unmarking asks first; cancelling keeps the marking.
        today(in: app).tap()
        let question = app.staticTexts["Desmarcar este dia?"]
        XCTAssertTrue(question.waitForExistence(timeout: 10), "No confirmation before unmarking")
        cancelDialog(confirmLabel: "Desmarcar", in: app)
        expectCount("1 treino esta semana", in: app)

        today(in: app).tap()
        XCTAssertTrue(question.waitForExistence(timeout: 10), "No confirmation before unmarking")
        app.buttons["Desmarcar"].tap()
        expectCount("0 treinos esta semana", in: app)
        XCTAssertTrue(today(in: app).label.contains("hoje, sem treino"), "Today: \(today(in: app).label)")
    }

    @MainActor
    func testWorkoutFinishedInTheAppCountsAndTodayCannotBeMarked() throws {
        continueAfterFailure = false
        let app = launchOnWeekCard()

        // A free workout with one completed set, finished; the other two sets of the exercise are left.
        app.buttons["home.startFree"].tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
        app.buttons["session.addExercise"].tap()
        pickExercise("Barra Fixa Pronada", in: app)
        let reps = app.textFields.matching(identifier: "session.set.reps").element(boundBy: 0)
        XCTAssertTrue(reps.waitForExistence(timeout: 10), "Added exercise has no set")
        reps.tap()
        reps.typeText("10")
        app.buttons.matching(identifier: "session.set.check").element(boundBy: 0).tap()
        saveSessionFromTheFinishSheet(in: app)

        expectCount("1 treino esta semana", in: app)
        XCTAssertTrue(today(in: app).label.contains("hoje, feito no app"), "Today: \(today(in: app).label)")
        attachScreenshot(named: "39-home-week-app", of: app)

        // A day trained in the app is not marked by hand: tapping it does nothing.
        today(in: app).tap()
        XCTAssertFalse(app.staticTexts["Desmarcar este dia?"].waitForExistence(timeout: 2), "Today offered to unmark")
        expectCount("1 treino esta semana", in: app)
        XCTAssertFalse(today(in: app).label.contains("marcado como feito fora do app"), "Today: \(today(in: app).label)")
    }
}
