import XCTest

/// The Home "Sua semana" card: marking today as trained outside the app, unmarking it after a
/// confirmation, and a workout finished in the app. Works on any day of the week: the tests only use
/// today. Runs on an in-memory store with the built-in library.
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

    /// Waits until the card shows `workouts` ("1 treino esta semana") and `days` ("1/7 dias").
    @MainActor
    private func expectCounts(_ workouts: String, _ days: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let count = app.staticTexts["home.week.count"]
        let trainedDays = app.staticTexts["home.week.days"]
        XCTAssertTrue(waitForLabel(of: count, toBe: workouts), "Workouts: \(count.label)", file: file, line: line)
        XCTAssertTrue(waitForLabel(of: trainedDays, toBe: days), "Days: \(trainedDays.label)", file: file, line: line)
    }

    @MainActor
    func testMarkAndUnmarkToday() throws {
        continueAfterFailure = false
        let app = launchOnWeekCard()

        // Seven days, today among them, and nothing trained yet.
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "home.week.day").count, 6)
        XCTAssertTrue(today(in: app).exists, "Today not shown")
        XCTAssertTrue(today(in: app).label.contains("hoje, sem treino"), "Today: \(today(in: app).label)")
        expectCounts("0 treinos esta semana", "0/7 dias", in: app)

        // Marking today counts one workout on one day.
        today(in: app).tap()
        expectCounts("1 treino esta semana", "1/7 dias", in: app)
        XCTAssertTrue(today(in: app).label.contains("hoje, marcado manualmente"), "Today: \(today(in: app).label)")
        attachScreenshot(named: "38-home-week", of: app)

        // Unmarking asks first; cancelling keeps the marking.
        today(in: app).tap()
        let question = app.staticTexts["Desmarcar este dia?"]
        XCTAssertTrue(question.waitForExistence(timeout: 10), "No confirmation before unmarking")
        cancelDialog(confirmLabel: "Desmarcar", in: app)
        expectCounts("1 treino esta semana", "1/7 dias", in: app)

        today(in: app).tap()
        XCTAssertTrue(question.waitForExistence(timeout: 10), "No confirmation before unmarking")
        app.buttons["Desmarcar"].tap()
        expectCounts("0 treinos esta semana", "0/7 dias", in: app)
        XCTAssertTrue(today(in: app).label.contains("hoje, sem treino"), "Today: \(today(in: app).label)")
    }

    @MainActor
    func testWorkoutFinishedInTheAppCountsAndTodayCannotBeMarked() throws {
        continueAfterFailure = false
        let app = launchOnWeekCard()

        // A free workout with one completed set, finished.
        app.buttons["home.startFree"].tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
        app.buttons["session.addExercise"].tap()
        pickExercise("Barra Fixa", in: app)
        let reps = app.textFields.matching(identifier: "session.set.reps").element(boundBy: 0)
        XCTAssertTrue(reps.waitForExistence(timeout: 10), "Added exercise has no set")
        reps.tap()
        reps.typeText("10")
        app.buttons.matching(identifier: "session.set.check").element(boundBy: 0).tap()
        app.buttons["session.finish"].tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")

        expectCounts("1 treino esta semana", "1/7 dias", in: app)
        XCTAssertTrue(today(in: app).label.contains("hoje, treinou no app"), "Today: \(today(in: app).label)")
        attachScreenshot(named: "39-home-week-app", of: app)

        // A day trained in the app is not marked by hand: tapping it does nothing.
        today(in: app).tap()
        XCTAssertFalse(app.staticTexts["Desmarcar este dia?"].waitForExistence(timeout: 2), "Today offered to unmark")
        expectCounts("1 treino esta semana", "1/7 dias", in: app)
        XCTAssertFalse(today(in: app).label.contains("marcado manualmente"), "Today: \(today(in: app).label)")
    }
}
