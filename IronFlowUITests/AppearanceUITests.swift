import XCTest

/// The app is dark only: it stays dark with the simulator in light mode, in a sheet and in the
/// keyboard too (the screens of every tab are checked by `SmokeUITests`, and the error screen by
/// `PersistenceErrorUITests`). Each measured brightness is kept with the result as a "Medição", which
/// the CI report prints even when the test passes.
final class AppearanceUITests: XCTestCase {
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

        // The keyboard: the margin at the left edge of its frame, halfway down.
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10), "Keyboard not shown")
        let keys = try XCTUnwrap(
            brightness(of: app, atX: keyboard.frame.minX + 2, y: keyboard.frame.midY),
            "Could not measure the keyboard"
        )
        recordMeasurement("Medição: brilho do teclado", String(format: "%.3f (limite %.2f)", keys, darkBrightnessLimit))
        XCTAssertLessThan(keys, darkBrightnessLimit, "The keyboard is not dark: brightness \(keys)")
        attachScreenshot(named: "48-sheet-keyboard", of: app)
    }
}
