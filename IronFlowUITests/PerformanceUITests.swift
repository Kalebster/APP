import XCTest

/// Measurements of the Visual novo stage, taken before and after the new look in the short diagnostic
/// run: scrolling the session with the rest bar over the list (hitches while dragging and decelerating),
/// and opening the app. They have no baseline and never fail on a number. Temporary: removed before the
/// stage's final full CI (the lasting performance tests come with the S5, with many data).
final class PerformanceUITests: IronFlowUITestCase {
    /// Push with four exercises of the built-in library: a list longer than the screen.
    private let push = "workout:Push:Supino Reto (Barra)|Supino Inclinado (Halter)|Desenvolvimento (Halter)|Tríceps Corda (Polia)"

    @MainActor
    func testScrollingTheSessionWithTheRestBar() throws {
        continueAfterFailure = false
        let app = launchOnTab("Treinos", seed: [push, "last-time:Push"])
        startWorkout(named: "Push", in: app)
        let check = app.buttons.matching(identifier: "session.set.check").element(boundBy: 0)
        XCTAssertTrue(check.waitForExistence(timeout: 10), "No set to check")
        check.tap()
        // The rest bar, over the list, while the list scrolls under it.
        XCTAssertTrue(element("session.rest", in: app).waitForExistence(timeout: 10), "No rest bar")
        let list = app.scrollViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10), "No list")
        // Rests of 90 s outlast the measurement: the bar stays on screen in every iteration.
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(
            metrics: [XCTOSSignpostMetric.scrollDraggingMetric, XCTOSSignpostMetric.scrollDecelerationMetric],
            options: options
        ) {
            list.swipeUp(velocity: .fast)
            list.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(element("session.rest", in: app).exists, "The rest bar left before the end of the measurement")
    }

    @MainActor
    func testOpeningTheApp() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing"]
            app.launch()
        }
    }
}
