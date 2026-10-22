import XCTest

/// The history detail: a finished session opens a read-only record that keeps its original name
/// and values after the planned workout is deleted. Runs on an in-memory store with the built-in
/// library; the workout and its finished session come ready (`-ui-seed`). Finishing a session through
/// the screens, with typed values, is checked by `SessionUITests`.
final class HistoryUITests: IronFlowUITestCase {
    @MainActor
    func testFinishedSessionDetailAfterItsWorkoutIsDeleted() throws {
        continueAfterFailure = false
        // A session with two sets done (20 kg for 10 repetitions; no load for 12) and one not done.
        let app = launchOnTab("Treinos", seed: ["workout:Push:Barra Fixa Pronada", "session-detail:Push"])

        // The planned workout is deleted; the session it came from stays in the history.
        openWorkout(named: "Push", in: app)
        deleteWorkoutFromEditor(in: app)
        XCTAssertTrue(element("workouts.empty", in: app).waitForExistence(timeout: 10), "Workout not deleted")

        openTab("Histórico", in: app)
        let card = element("history.session", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Finished session not in the history")
        XCTAssertTrue(card.label.contains("Push"), "History: \(card.label)")
        XCTAssertTrue(card.label.contains("1 exercício · 2 séries"), "History: \(card.label)")
        card.tap()

        // The record: the original name, the exercise, and every set with its values and state.
        let detail = element("history.detail", in: app)
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "Session detail not opened")
        XCTAssertTrue(app.navigationBars["Push"].exists, "The detail does not show the session's name")
        let exercises = detail.descendants(matching: .any).matching(identifier: "history.detail.exercise")
        XCTAssertEqual(exercises.count, 1)
        XCTAssertTrue(exercises.element(boundBy: 0).staticTexts["Barra Fixa Pronada"].exists, "Exercise name not shown")
        let sets = detail.descendants(matching: .any).matching(identifier: "history.detail.set")
        XCTAssertEqual(sets.count, 3)
        XCTAssertEqual(sets.element(boundBy: 0).label, "Série 1, Meta: 8–12, Carga: 20 kg, 10 repetições, Concluída")
        XCTAssertEqual(sets.element(boundBy: 1).label, "Série 2, Meta: 8–12, Sem carga, 12 repetições, Concluída")
        XCTAssertEqual(sets.element(boundBy: 2).label, "Série 3, Meta: 8–12, Sem carga, Sem repetições, Não concluída")
        // Read-only: nothing to type in and no action to take.
        XCTAssertEqual(detail.textFields.count, 0, "The detail has editable fields")
        XCTAssertEqual(detail.buttons.count, 0, "The detail has action buttons")
        attachScreenshot(named: "37-history-detail", of: app)

        // Back to the list, which still opens the detail.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(detail.waitForNonExistence(timeout: 10), "Detail still shown after going back")
        XCTAssertTrue(card.waitForExistence(timeout: 10), "History list not shown after going back")
        card.tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "Session detail not opened again")
    }
}
