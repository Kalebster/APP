import XCTest

/// TEMPORARY: the investigation of the first tap on "Peito" that is sometimes lost about 7 s after the
/// Exercícios tab opens (PR #39). Not in ci/ui-test-shards.json: run only in the short diagnostic run, with
/// repetitions, and removed before the stage's pull request. Each test taps "Peito" once, with a plain
/// tap and no second try, fails when the tap is lost, and keeps the app's record of touches, filter
/// actions and scroll phases (`TapDiagnostics`, `-ui-tap-diagnostics`).
final class FilterTapDiagnosticsUITests: IronFlowUITestCase {
    private let diagnostics = ["-ui-tap-diagnostics"]

    /// Right after the tab opens and its header is there.
    @MainActor
    func testDiagnosticTapRightAfterOpeningTheTab() throws {
        let app = launchOnTab("Exercícios", extraArguments: diagnostics)
        XCTAssertTrue(element("exercises.total", in: app).waitForExistence(timeout: 10), "Header not shown")
        tapChest(in: app, how: "element") { $0.tap() }
    }

    /// After the same checks and screenshot as `ExerciseListUITests.testAllExercisesAndGroupChips`.
    @MainActor
    func testDiagnosticTapAfterTheOriginalChecks() throws {
        let app = launchOnTab("Exercícios", extraArguments: diagnostics)
        originalChecks(in: app)
        tapChest(in: app, how: "element") { $0.tap() }
    }

    /// The same, tapping the chip's center by coordinate.
    @MainActor
    func testDiagnosticTapByCoordinateAfterTheOriginalChecks() throws {
        let app = launchOnTab("Exercícios", extraArguments: diagnostics)
        originalChecks(in: app)
        tapChest(in: app, how: "coordinate") { $0.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
    }

    @MainActor
    private func originalChecks(in app: XCUIApplication) {
        XCTAssertTrue(element("exercises.total", in: app).waitForExistence(timeout: 10), "Header not shown")
        XCTAssertEqual(element("exercises.total", in: app).label, "420 exercícios")
        XCTAssertTrue(app.buttons["exercises.filter.all"].isSelected)
        XCTAssertFalse(app.buttons["exercises.filter.mine"].exists)
        XCTAssertFalse(app.buttons["exercises.filter.other"].exists)
        XCTAssertTrue(app.buttons["exercises.equipment.plate"].exists)
        XCTAssertFalse(element("exercises.count", in: app).exists)
        let cards = app.descendants(matching: .any).matching(identifier: "exercises.card")
        XCTAssertFalse(cards.element(boundBy: 0).label.isEmpty)
        XCTAssertFalse(cards.element(boundBy: 1).label.isEmpty)
        attachScreenshot(named: "diagnostic-before-tap", of: app)
    }

    @MainActor
    private func tapChest(in app: XCUIApplication, how: String, tap: (XCUIElement) -> Void) {
        let chest = app.buttons["exercises.filter.chest"]
        XCTAssertTrue(chest.waitForExistence(timeout: 10), "Peito not found")
        let count = element("exercises.count", in: app)
        let tappedAt = Date.now
        tap(chest)
        let arrived = count.waitForExistence(timeout: 5)
        let waited = Date.now.timeIntervalSince(tappedAt)
        let events = element("diagnostics.events", in: app)
        let record = "tap (\(how)) \(arrived ? "worked" : "LOST") after \(String(format: "%.2f", waited)) s; chest frame \(chest.frame); events: \(events.exists ? (events.value as? String ?? "") : "none")"
        print("TAP-DIAGNOSTICS \(name): \(record)")
        let attachment = XCTAttachment(string: record)
        attachment.name = "tap-diagnostics"
        attachment.lifetime = .keepAlways
        add(attachment)
        if !arrived {
            XCTFail("Tap lost: \(record)")
        }
    }
}
