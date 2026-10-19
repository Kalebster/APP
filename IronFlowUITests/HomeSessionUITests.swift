import XCTest

/// The Home "Treino de hoje" actions: starting a free workout, choosing a workout to start, and
/// continuing the session in progress. Runs on an in-memory store with the built-in library; the
/// workouts the tests choose from come ready (`-ui-seed`).
final class HomeSessionUITests: IronFlowUITestCase {
    @MainActor
    func testFreeWorkoutFromHome() throws {
        continueAfterFailure = false
        let app = launchOnHome()

        // Without workouts there is nothing to choose: only the free workout is offered.
        let startFree = app.buttons["home.startFree"]
        XCTAssertTrue(startFree.waitForExistence(timeout: 10), "No Iniciar treino livre")
        XCTAssertFalse(app.buttons["home.chooseWorkout"].exists, "Escolher um treino shown without workouts")
        attachScreenshot(named: "30-home-actions-no-workouts", of: app)

        startFree.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
        XCTAssertEqual(element("session.name", in: app).label, "Treino livre")
        XCTAssertTrue(element("session.empty", in: app).exists, "Free session not empty")

        app.buttons["session.addExercise"].tap()
        pickExercise("Barra Fixa", in: app)
        let reps = app.textFields.matching(identifier: "session.set.reps").element(boundBy: 0)
        XCTAssertTrue(reps.waitForExistence(timeout: 10), "Added exercise has no set")
        reps.tap()
        reps.typeText("10")
        app.buttons.matching(identifier: "session.set.check").element(boundBy: 0).tap()

        app.buttons["session.finish"].tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
        XCTAssertTrue(startFree.waitForExistence(timeout: 10), "Home actions not back after finishing")

        openTab("Histórico", in: app)
        let finished = element("history.session", in: app)
        XCTAssertTrue(finished.waitForExistence(timeout: 10), "Free workout not in the history")
        XCTAssertTrue(finished.label.contains("Treino livre"), "History: \(finished.label)")
    }

    @MainActor
    func testChooseWorkoutThenContinueTheSameSession() throws {
        continueAfterFailure = false
        let app = launchOnHome(seed: ["workout:Push:Barra Fixa"])

        let choose = app.buttons["home.chooseWorkout"]
        XCTAssertTrue(choose.waitForExistence(timeout: 10), "No Escolher um treino")
        XCTAssertTrue(app.buttons["home.startFree"].exists, "No Iniciar treino livre")
        attachScreenshot(named: "31-home-actions", of: app)

        choose.tap()
        let workout = app.buttons.matching(identifier: "workoutPicker.workout").firstMatch
        XCTAssertTrue(workout.waitForExistence(timeout: 10), "Workout picker not shown")
        XCTAssertTrue(workout.label.contains("Push"), "Picker row: \(workout.label)")
        attachScreenshot(named: "32-workout-picker", of: app)
        workout.tap()

        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
        XCTAssertEqual(element("session.name", in: app).label, "Push")
        let firstCheck = app.buttons.matching(identifier: "session.set.check").element(boundBy: 0)
        firstCheck.tap()
        XCTAssertTrue(firstCheck.isSelected, "First set not checked")
        app.buttons["session.minimize"].tap()

        // In progress, the card only continues; the bar is not shown on the Home but is on the other tabs.
        let resume = app.buttons["home.continue"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "No Continuar")
        XCTAssertFalse(app.buttons["home.chooseWorkout"].exists, "Escolher um treino shown during a session")
        XCTAssertFalse(app.buttons["home.startFree"].exists, "Iniciar treino livre shown during a session")
        XCTAssertFalse(app.buttons["session.bar"].exists, "Session bar shown on the Home")
        attachScreenshot(named: "51-home-in-progress", of: app)
        openTab("Treinos", in: app)
        XCTAssertTrue(app.buttons["session.bar"].waitForExistence(timeout: 10), "Session bar not shown on Treinos")
        openTab("Início", in: app)

        resume.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session not continued")
        XCTAssertEqual(element("session.name", in: app).label, "Push")
        XCTAssertTrue(firstCheck.isSelected, "Continued a different session")
    }

    @MainActor
    func testPickerShowsEmptyWorkoutUnavailableAndCancels() throws {
        continueAfterFailure = false
        let app = launchOnHome(seed: ["workout:Vazio"])

        let choose = app.buttons["home.chooseWorkout"]
        XCTAssertTrue(choose.waitForExistence(timeout: 10), "No Escolher um treino")
        choose.tap()
        let workout = app.buttons.matching(identifier: "workoutPicker.workout").firstMatch
        XCTAssertTrue(workout.waitForExistence(timeout: 10), "Workout picker not shown")
        XCTAssertFalse(workout.isEnabled, "A workout without exercises can be started")

        app.buttons["workoutPicker.cancel"].tap()
        XCTAssertTrue(workout.waitForNonExistence(timeout: 10), "Picker not closed")
        XCTAssertFalse(element("session.name", in: app).exists, "A session was started")
        XCTAssertTrue(app.buttons["home.chooseWorkout"].exists, "Home actions changed after cancelling")
    }
}
