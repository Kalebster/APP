import XCTest

/// The Início in the approved model: today's workout block in its states, the week's ring (with a plan,
/// past the goal and without a plan) and the screen with large text. Each state comes ready from the
/// seed (`-ui-seed`); the screenshots are compared with the model. The states reached through the
/// screens are checked by `HomeUITests` (no workouts), `HomeSessionUITests` (in progress) and
/// `WeeklyPlanUITests` (planned and finished through the plan).
final class HomeScreenUITests: IronFlowUITestCase {
    /// Push, Pull and Pernas with exercises of the built-in library, like the model.
    private let workouts = [
        "workout:Push:Supino Reto com Barra|Supino Inclinado com Halteres|Desenvolvimento com Halteres|Tríceps na Polia com Corda",
        "workout:Pull:Barra Fixa Pronada|Rosca Direta com Barra",
        "workout:Pernas:Agachamento Livre com Barra|Cadeira Extensora|Stiff com Barra|Mesa Flexora|Panturrilha Sentado",
    ]

    @MainActor
    func testScheduledWorkoutAndTheWeekRing() throws {
        continueAfterFailure = false
        // Push today and on three more weekdays; two Pull sessions finished today.
        let app = launchOnHome(seed: workouts + ["plan:Push:1|3|5", "plan-today:Push", "finished-today:Pull", "finished-today:Pull"])

        let today = element("home.today", in: app)
        XCTAssertTrue(today.waitForExistence(timeout: 10), "Today's block not shown")
        XCTAssertTrue(today.label.hasPrefix("Push, programado para hoje, 4 exercícios · 12 séries"), "Today: \(today.label)")
        XCTAssertTrue(today.label.hasSuffix("Peito · Ombros · Tríceps"), "Today: \(today.label)")
        XCTAssertEqual(app.buttons["home.startPlanned"].label, "Iniciar Push")
        XCTAssertEqual(app.buttons["home.chooseWorkout"].label, "Escolher outro treino")
        XCTAssertEqual(app.buttons["home.startFree"].label, "Iniciar treino livre")
        XCTAssertTrue(element("home.date", in: app).exists, "No date in the header")

        // The ring: the two workouts of today out of the planned days.
        let ring = element("home.week.goal", in: app)
        XCTAssertTrue(ring.exists, "No ring with a weekly plan")
        XCTAssertTrue(ring.label.hasPrefix("2 de "), "Ring: \(ring.label)")
        XCTAssertTrue(ring.label.hasSuffix(" treinos programados feitos"), "Ring: \(ring.label)")
        XCTAssertTrue(app.staticTexts["home.week.remaining"].label.hasPrefix("Falta"), "Remaining: \(app.staticTexts["home.week.remaining"].label)")
        XCTAssertTrue(element("home.week.today", in: app).label.contains("hoje, feito no app"), "Today: \(element("home.week.today", in: app).label)")
        attachScreenshot(named: "50-home-scheduled", of: app)
    }

    @MainActor
    func testFinishedTodayShowsTheDuration() throws {
        continueAfterFailure = false
        let app = launchOnHome(seed: workouts + ["plan-today:Push", "finished-today:Push"])

        let today = element("home.today", in: app)
        XCTAssertTrue(today.waitForExistence(timeout: 10), "Today's block not shown")
        XCTAssertTrue(today.label.hasPrefix("Push concluído hoje, "), "Today: \(today.label)")
        XCTAssertFalse(app.buttons["home.startPlanned"].exists, "Start offered for a workout finished today")
        XCTAssertEqual(app.buttons["home.chooseWorkout"].label, "Escolher outro treino")
        XCTAssertTrue(app.buttons["home.startFree"].exists, "No free workout")
        attachScreenshot(named: "52-home-completed", of: app)
    }

    @MainActor
    func testNothingPlannedInvitesToPlanTheWeek() throws {
        continueAfterFailure = false
        let app = launchOnHome(seed: workouts)

        let today = element("home.today", in: app)
        XCTAssertTrue(today.waitForExistence(timeout: 10), "Today's block not shown")
        XCTAssertTrue(today.label.hasPrefix("Nada programado."), "Today: \(today.label)")
        XCTAssertEqual(app.buttons["home.chooseWorkout"].label, "Escolher um treino")
        XCTAssertEqual(app.buttons["home.startFree"].label, "Iniciar treino livre")

        // Without a plan: no ring, the week's count and the invitation to plan it.
        XCTAssertFalse(element("home.week.goal", in: app).exists, "Ring shown without a weekly plan")
        XCTAssertEqual(app.staticTexts["home.week.count"].label, "0 treinos esta semana")
        let plan = app.buttons["home.week.plan"]
        XCTAssertTrue(plan.exists, "No invitation to plan the week")
        attachScreenshot(named: "54-home-nothing-planned", of: app)

        plan.tap()
        XCTAssertTrue(element("plan.screen", in: app).waitForExistence(timeout: 10), "Plan screen not opened")
    }

    @MainActor
    func testWeekPastTheGoal() throws {
        continueAfterFailure = false
        // One planned day and two workouts today: past the goal, the ring stays full.
        let app = launchOnHome(seed: workouts + ["plan-today:Push", "finished-today:Push", "finished-today:Pull"])

        let ring = element("home.week.goal", in: app)
        XCTAssertTrue(ring.waitForExistence(timeout: 10), "No ring with a weekly plan")
        XCTAssertEqual(ring.label, "2 de 1 treino programado feito")
        XCTAssertEqual(app.staticTexts["home.week.count"].label, "2 de 1 treino")
        XCTAssertEqual(app.staticTexts["home.week.remaining"].label, "Semana completa")
        attachScreenshot(named: "55-home-week-goal", of: app)
    }

    @MainActor
    func testLargeTextKeepsTheHomeOnScreen() throws {
        continueAfterFailure = false
        let seed = workouts + ["plan:Push:1|3|5", "plan-today:Push"]

        for (size, name) in [("UICTContentSizeCategoryXXXL", "59-home-xxxl"), ("UICTContentSizeCategoryAccessibilityXXXL", "61-home-accessibility")] {
            let app = launchOnHome(seed: seed, extraArguments: ["-UIPreferredContentSizeCategoryName", size])
            let start = app.buttons["home.startPlanned"]
            XCTAssertTrue(start.waitForExistence(timeout: 10), "No Iniciar Push with \(size)")
            let screen = app.windows.firstMatch.frame
            for element in [start, app.buttons["home.chooseWorkout"], app.buttons["home.startFree"]] {
                XCTAssertTrue(
                    element.frame.minX >= screen.minX && element.frame.maxX <= screen.maxX,
                    "\(element.label) is not on the screen with \(size): \(element.frame) on \(screen)"
                )
            }
            attachScreenshot(named: name, of: app)
            app.terminate()
        }
    }
}
