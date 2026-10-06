import UIKit
import XCTest

/// The Exercises tab shows one card per muscle group; a card opens that group's exercises.
/// Searching from the groups screen finds exercises in every group.
/// Runs on an in-memory store where the 71 built-in exercises are installed at launch.
final class ExerciseListUITests: XCTestCase {
    @MainActor
    private func launchOnExercisesTab(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extraArguments
        app.launch()
        let tab = app.tabBars.buttons["Exercícios"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Exercises tab not found")
        tab.tap()
        return app
    }

    /// Any element whose accessibility label is exactly `label` (rows combine their texts).
    @MainActor
    private func element(labeled label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    @MainActor
    private func groupCard(_ rawValue: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["exercises.group.\(rawValue)"]
    }

    @MainActor
    private func searchField(in app: XCUIApplication) -> XCUIElement {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Search field not found")
        return field
    }

    @MainActor
    private func attachScreenshot(named name: String, of app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testGroupsAreShownFirst() throws {
        continueAfterFailure = false
        let app = launchOnExercisesTab()

        let chest = groupCard("chest", in: app)
        XCTAssertTrue(chest.waitForExistence(timeout: 10), "Chest card not found")
        XCTAssertTrue(chest.label.contains("9 exercícios"), "Unexpected chest card label: \(chest.label)")
        let back = groupCard("back", in: app)
        XCTAssertTrue(back.exists, "Back card not found")
        XCTAssertTrue(back.label.contains("7 exercícios"), "Unexpected back card label: \(back.label)")
        XCTAssertFalse(element(labeled: "Supino Reto com Barra", in: app).exists)

        attachScreenshot(named: "6-exercises-groups", of: app)
    }

    @MainActor
    func testGroupCardOpensItsExercises() throws {
        continueAfterFailure = false
        let app = launchOnExercisesTab()

        let back = groupCard("back", in: app)
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Back card not found")
        back.tap()

        XCTAssertTrue(element(labeled: "Barra Fixa", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(element(labeled: "Supino Reto com Barra", in: app).exists)
        attachScreenshot(named: "7-exercises-group", of: app)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(groupCard("chest", in: app).waitForExistence(timeout: 10), "Groups not shown after going back")
    }

    @MainActor
    func testGlobalSearchFindsMatchesAndShowsNoResults() throws {
        continueAfterFailure = false
        let app = launchOnExercisesTab()
        XCTAssertTrue(groupCard("chest", in: app).waitForExistence(timeout: 10), "Chest card not found")

        let field = searchField(in: app)
        field.tap()
        field.typeText("agachamento")

        XCTAssertTrue(element(labeled: "Agachamento Livre com Barra", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(element(labeled: "Supino Reto com Barra", in: app).exists)
        XCTAssertTrue(app.descendants(matching: .any)["exercises.section.quadriceps"].exists, "Quadriceps section not shown")
        XCTAssertFalse(groupCard("chest", in: app).exists, "Group cards shown during search")
        attachScreenshot(named: "8-exercises-search", of: app)

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "agachamento".count))
        field.typeText("xyz")
        XCTAssertTrue(app.descendants(matching: .any)["exercises.empty.search"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSearchInsideGroup() throws {
        continueAfterFailure = false
        let app = launchOnExercisesTab()

        let chest = groupCard("chest", in: app)
        XCTAssertTrue(chest.waitForExistence(timeout: 10), "Chest card not found")
        chest.tap()
        XCTAssertTrue(element(labeled: "Supino Reto com Barra", in: app).waitForExistence(timeout: 10))

        let field = searchField(in: app)
        field.tap()
        field.typeText("inclinado")

        XCTAssertTrue(element(labeled: "Supino Inclinado com Barra", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(element(labeled: "Supino Inclinado com Halteres", in: app).exists)
        XCTAssertFalse(element(labeled: "Supino Reto com Barra", in: app).exists)
    }

    /// Brightness (0...1) of the screen background, sampled at the left margin below the title.
    @MainActor
    private func backgroundBrightness(of app: XCUIApplication) -> CGFloat? {
        guard let image = app.screenshot().image.cgImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let x = 4, y = image.height / 4
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return (CGFloat(pixel[0]) + CGFloat(pixel[1]) + CGFloat(pixel[2])) / (3 * 255)
    }

    /// Dark appearance, forced with a Debug-only launch argument.
    @MainActor
    func testDarkAppearance() throws {
        continueAfterFailure = false
        let app = launchOnExercisesTab(extraArguments: ["-ui-dark-appearance"])
        let chest = groupCard("chest", in: app)
        XCTAssertTrue(chest.waitForExistence(timeout: 10), "Chest card not found")
        XCTAssertLessThan(backgroundBrightness(of: app) ?? 1, 0.3, "Groups screen is not dark")
        attachScreenshot(named: "9-exercises-groups-dark", of: app)

        chest.tap()
        XCTAssertTrue(element(labeled: "Supino Reto com Barra", in: app).waitForExistence(timeout: 10))
        XCTAssertLessThan(backgroundBrightness(of: app) ?? 1, 0.3, "Group screen is not dark")
        attachScreenshot(named: "10-exercises-group-dark", of: app)
    }
}
