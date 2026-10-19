import XCTest

/// The app is dark only: it stays dark with the simulator in light mode, in a sheet and in the
/// keyboard too (the screens of every tab are checked by `SmokeUITests`, and the error screen by
/// `PersistenceErrorUITests`). Each measured brightness is kept with the result as a "Medição", which
/// the CI report prints even when the test passes.
final class AppearanceUITests: IronFlowUITestCase {
    /// Brightness of the background of the simulator's own Settings app, which follows the device
    /// setting. It proves the device really was in light mode when the app was checked.
    @MainActor
    private func deviceBrightness() -> CGFloat? {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        defer { settings.terminate() }
        guard let image = settings.screenshot().image.cgImage else { return nil }
        return pixelBrightness(of: image, x: 4, y: image.height / 4)
    }

    /// Brightness of the space bar of the keyboard on screen, at a point of the key's surface away from
    /// its label: 15% of its width from its left edge, halfway down. The letter keys are not used:
    /// their letter is in the middle, and their frames take in part of the gaps between the keys.
    /// The keyboard's one-time introduction, which covers the keys, is closed first.
    @MainActor
    private func spaceBarBrightness(in app: XCUIApplication) throws -> CGFloat {
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10), "Keyboard not shown")
        dismissKeyboardIntroductionIfShown(in: app)
        let space = try XCTUnwrap(spaceBar(of: keyboard), "No space bar on the keyboard")
        XCTAssertTrue(space.isHittable, "The space bar is covered")
        return try XCTUnwrap(
            brightness(of: app, atX: space.frame.minX + space.frame.width * 0.15, y: space.frame.midY),
            "Could not measure the space bar"
        )
    }

    /// The space bar, found by its name in English or Portuguese, or else as the widest key.
    @MainActor
    private func spaceBar(of keyboard: XCUIElement) -> XCUIElement? {
        let named = keyboard.keys.matching(NSPredicate(format: "label ==[c] 'space' OR label ==[c] 'espaço' OR identifier ==[c] 'space'")).firstMatch
        if named.waitForExistence(timeout: 5) {
            return named
        }
        return keyboard.keys.allElementsBoundByIndex.max { $0.frame.width < $1.frame.width }
    }

    @MainActor
    func testSheetAndKeyboardAreDarkWithTheDeviceInLightMode() throws {
        continueAfterFailure = false

        // The precondition: the device is light (a dark pixel here would make the rest prove nothing).
        let device = try XCTUnwrap(deviceBrightness(), "Could not measure the device's appearance")
        recordMeasurement("Medição: brilho do app Ajustes do iPhone (aparelho)", String(format: "%.3f (claro: acima de 0,5)", device))
        XCTAssertGreaterThan(device, 0.5, "The simulator is not in light mode, so this test proves nothing")

        let app = launchOnTab("Treinos")
        let add = app.buttons["workouts.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Add workout button not found")
        add.tap()

        // The sheet: a point of its navigation bar, between "Cancelar" and the title.
        let bar = app.navigationBars["Novo treino"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "Name sheet not shown")
        let sheet = try XCTUnwrap(
            brightness(of: app, atX: bar.frame.minX + bar.frame.width * 0.3, y: bar.frame.midY),
            "Could not measure the sheet"
        )
        recordMeasurement("Medição: brilho da folha", String(format: "%.3f (limite %.2f)", sheet, darkBrightnessLimit))
        XCTAssertLessThan(sheet, darkBrightnessLimit, "The sheet is not dark: brightness \(sheet)")

        // The keyboard: a point of the space bar. The dark keys are gray, not black, so they have their
        // own limit, below the white keys of a light keyboard.
        let key = try spaceBarBrightness(in: app)
        recordMeasurement("Medição: brilho da barra de espaço (teclado do app)", String(format: "%.3f (limite %.2f)", key, darkKeyBrightnessLimit))
        XCTAssertLessThan(key, darkKeyBrightnessLimit, "The keyboard is not dark: brightness \(key)")
        attachScreenshot(named: "48-sheet-keyboard", of: app)
    }
}
