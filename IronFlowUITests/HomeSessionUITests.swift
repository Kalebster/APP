import XCTest

/// The Home "Treino de hoje" actions: starting a free workout, choosing a workout to start, and
/// continuing the session in progress. Runs on an in-memory store with the built-in library.
final class HomeSessionUITests: XCTestCase {
    @MainActor
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extraArguments
        app.launch()
        XCTAssertTrue(element("home.today", in: app).waitForExistence(timeout: 10), "Home not shown")
        return app
    }

    @MainActor
    private func openTab(_ label: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Tab '\(label)' not found")
        tab.tap()
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Adds one exercise through the exercise picker (the one of a workout or of a session).
    @MainActor
    private func pickExercise(_ name: String, in app: XCUIApplication) {
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "Picker search field not found")
        search.tap()
        search.typeText(name)
        let row = app.buttons[name]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Exercise '\(name)' not found in the picker")
        row.tap()
        app.buttons["picker.add"].tap()
    }

    /// Creates a workout on the Treinos tab (with one exercise, or none) and goes back to the Home.
    @MainActor
    private func createWorkout(named name: String, exercise: String?, in app: XCUIApplication) {
        openTab("Treinos", in: app)
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
            pickExercise(exercise, in: app)
            XCTAssertTrue(element("workout.exercise", in: app).waitForExistence(timeout: 10), "Exercise not added")
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["workouts.start"].firstMatch.waitForExistence(timeout: 10), "Workout list not shown")
        openTab("Início", in: app)
    }

    @MainActor
    private func attachScreenshot(named name: String, of app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testFreeWorkoutFromHome() throws {
        continueAfterFailure = false
        let app = launch()

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
        let app = launch()
        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)

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
        attachScreenshot(named: "33-home-continue", of: app)
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
        let app = launch()
        createWorkout(named: "Vazio", exercise: nil, in: app)

        app.buttons["home.chooseWorkout"].tap()
        let workout = app.buttons.matching(identifier: "workoutPicker.workout").firstMatch
        XCTAssertTrue(workout.waitForExistence(timeout: 10), "Workout picker not shown")
        XCTAssertFalse(workout.isEnabled, "A workout without exercises can be started")

        app.buttons["workoutPicker.cancel"].tap()
        XCTAssertTrue(workout.waitForNonExistence(timeout: 10), "Picker not closed")
        XCTAssertFalse(element("session.name", in: app).exists, "A session was started")
        XCTAssertTrue(app.buttons["home.chooseWorkout"].exists, "Home actions changed after cancelling")
    }

    @MainActor
    func testDarkAppearance() throws {
        continueAfterFailure = false
        let app = launch(extraArguments: ["-ui-dark-appearance"])
        createWorkout(named: "Push", exercise: "Barra Fixa", in: app)
        XCTAssertTrue(app.buttons["home.chooseWorkout"].waitForExistence(timeout: 10))
        attachScreenshot(named: "34-home-actions-dark", of: app)

        app.buttons["home.chooseWorkout"].tap()
        let workout = app.buttons.matching(identifier: "workoutPicker.workout").firstMatch
        XCTAssertTrue(workout.waitForExistence(timeout: 10), "Workout picker not shown")
        attachScreenshot(named: "35-workout-picker-dark", of: app)
        workout.tap()

        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
        app.buttons["session.minimize"].tap()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 10), "No Continuar")
        attachScreenshot(named: "36-home-continue-dark", of: app)
    }
}
