import XCTest

/// Smoke test: the app launches and each of the five main tabs opens its screen, dark (the app is dark
/// only, whatever the simulator's setting). Its screenshots are the picture of each tab.
final class SmokeUITests: IronFlowUITestCase {
    @MainActor
    func testLaunchAndOpenEachTab() throws {
        continueAfterFailure = false

        let tabs: [(label: String, rootIdentifier: String)] = [
            ("Início", "tab.home.root"),
            ("Treinos", "tab.workouts.root"),
            ("Exercícios", "tab.exercises.root"),
            ("Histórico", "tab.history.root"),
            ("Ajustes", "tab.settings.root"),
        ]

        let app = launchApp()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "Tab bar did not appear")

        for (index, tab) in tabs.enumerated() {
            openTab(tab.label, in: app)
            XCTAssertTrue(element(tab.rootIdentifier, in: app).waitForExistence(timeout: 10), "Screen '\(tab.rootIdentifier)' did not appear")
            assertScreenIsDark(app, "tab \(tab.label)")
            attachScreenshot(named: "\(index + 1)-\(tab.rootIdentifier)", of: app)
        }
    }
}
