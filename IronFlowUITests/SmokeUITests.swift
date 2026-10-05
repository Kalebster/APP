import XCTest

/// Smoke test: the app launches and each of the four main tabs opens its screen.
final class SmokeUITests: XCTestCase {
    @MainActor
    func testLaunchAndOpenEachTab() throws {
        continueAfterFailure = false

        let tabs: [(label: String, rootIdentifier: String)] = [
            ("Início", "tab.home.root"),
            ("Treinos", "tab.workouts.root"),
            ("Exercícios", "tab.exercises.root"),
            ("Histórico", "tab.history.root"),
        ]

        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar did not appear")

        for (index, tab) in tabs.enumerated() {
            let button = tabBar.buttons[tab.label]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "Tab button '\(tab.label)' not found")
            button.tap()

            let root = app.descendants(matching: .any).matching(identifier: tab.rootIdentifier).firstMatch
            XCTAssertTrue(root.waitForExistence(timeout: 10), "Screen '\(tab.rootIdentifier)' did not appear")
            XCTAssertTrue(button.isSelected, "Tab '\(tab.label)' is not selected after tapping it")

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "\(index + 1)-\(tab.rootIdentifier)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }
}
