import CoreGraphics
import XCTest

/// Highest brightness (0...1) a pixel of the app's background may have for the app to count as dark.
/// The dark background is about 0.05 and a light one is above 0.9, so there is a wide margin.
let darkBrightnessLimit: CGFloat = 0.3

/// Brightness (0...1) of the pixel at (`x`, `y`) of `image`, counted in pixels from its top left corner.
func pixelBrightness(of image: CGImage, x: Int, y: Int) -> CGFloat? {
    let x = min(max(x, 0), image.width - 1)
    let y = min(max(y, 0), image.height - 1)
    var pixel = [UInt8](repeating: 0, count: 4)
    guard let context = CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
    return (CGFloat(pixel[0]) + CGFloat(pixel[1]) + CGFloat(pixel[2])) / (3 * 255)
}

/// What every interface test needs: launching the app (on an in-memory store, with ready-made data
/// when a test only needs the data to exist), moving between tabs, finding elements, creating a
/// workout through the interface, running a session, and screenshots and measurements.
extension XCTestCase {
    // MARK: - Launching

    /// Launches the app on an in-memory store. `seed` lists what `-ui-seed` should create before the
    /// first screen (see `UITestSeed`); `extraArguments` are added to the launch arguments.
    @MainActor
    func launchApp(seed: [String] = [], extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-ui-testing"]
        if !seed.isEmpty {
            arguments += ["-ui-seed", seed.joined(separator: ",")]
        }
        app.launchArguments = arguments + extraArguments
        app.launch()
        return app
    }

    /// Launches the app on its first tab, Início, and waits for its header.
    @MainActor
    func launchOnHome(seed: [String] = [], extraArguments: [String] = []) -> XCUIApplication {
        let app = launchApp(seed: seed, extraArguments: extraArguments)
        XCTAssertTrue(element("home.header", in: app).waitForExistence(timeout: 10), "Home not shown")
        return app
    }

    /// Launches the app and opens the tab with the given label ("Treinos", "Exercícios"...).
    @MainActor
    func launchOnTab(_ label: String, seed: [String] = [], extraArguments: [String] = []) -> XCUIApplication {
        let app = launchApp(seed: seed, extraArguments: extraArguments)
        openTab(label, in: app)
        return app
    }

    /// Opens a tab and waits until it is the selected one. The first tap right after the launch can be
    /// lost (seen in CI: the tab never opened and the first button of its screen was never found), so a
    /// tab that is still not selected is tapped once more. Nothing waits when the first tap works.
    @MainActor
    func openTab(_ label: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Tab '\(label)' not found")
        tab.tap()
        if !waitUntilSelected(tab, timeout: 5) {
            tab.tap()
            XCTAssertTrue(waitUntilSelected(tab, timeout: 10), "Tab '\(label)' did not open")
        }
    }

    @MainActor
    private func waitUntilSelected(_ tab: XCUIElement, timeout: TimeInterval) -> Bool {
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: tab)
        return XCTWaiter().wait(for: [selected], timeout: timeout) == .completed
    }

    // MARK: - Finding and waiting

    /// Any element with this accessibility identifier.
    @MainActor
    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Any element whose accessibility label starts with `prefix`.
    @MainActor
    func element(labelStartingWith prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Waits until the element's label contains `text`.
    @MainActor
    func waitForLabel(of element: XCUIElement, containing text: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }

    /// Waits until the element's label is exactly `label`.
    @MainActor
    func waitForLabel(of element: XCUIElement, toBe label: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }

    /// Closes a confirmation dialog without confirming it. Depending on the system layout the dialog has a
    /// "Cancelar" button or is dismissed by tapping outside it.
    @MainActor
    func cancelDialog(confirmLabel: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[confirmLabel].waitForExistence(timeout: 10), "Confirmation '\(confirmLabel)' not shown")
        let cancel = app.buttons["Cancelar"]
        if cancel.exists {
            cancel.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        XCTAssertTrue(app.buttons[confirmLabel].waitForNonExistence(timeout: 10), "Confirmation not dismissed")
    }

    @MainActor
    func scrollToBottom(in app: XCUIApplication) {
        for _ in 0..<3 {
            app.swipeUp()
        }
    }

    @MainActor
    func scrollToTop(in app: XCUIApplication) {
        for _ in 0..<3 {
            app.swipeDown()
        }
    }

    // MARK: - Workouts and sessions

    /// Creates a workout with the name sheet and waits for its editor.
    @MainActor
    func createWorkout(named name: String, in app: XCUIApplication) {
        let add = app.buttons["workouts.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Add workout button not found")
        add.tap()
        let field = app.textFields["workout.name.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Name field not found")
        field.tap()
        field.typeText(name)
        app.buttons["workout.name.save"].tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 10), "Editor of '\(name)' did not open")
    }

    /// Chooses one exercise in the exercise picker on screen (the one of a workout or of a session),
    /// by searching its exact name, and confirms with "Adicionar".
    @MainActor
    func pickExercise(_ name: String, in app: XCUIApplication) {
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "Picker search field not found")
        search.tapAndWaitForKeyboardFocus()
        search.typeText(name)
        let row = app.buttons[name]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Exercise '\(name)' not found in the picker")
        row.tap()
        app.buttons["picker.add"].tap()
    }

    /// Starts a workout from its ▶ button on the Treinos tab and waits for the session screen.
    @MainActor
    func startWorkout(named name: String, in app: XCUIApplication) {
        let start = app.buttons["Iniciar \(name)"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "No ▶ for '\(name)'")
        start.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
    }

    /// In the session on screen: completes the first set and finishes it, confirming the sets left undone.
    @MainActor
    func completeFirstSetAndFinishSession(in app: XCUIApplication) {
        app.buttons.matching(identifier: "session.set.check").element(boundBy: 0).tap()
        app.buttons["session.finish"].tap()
        let confirm = app.buttons["Concluir treino"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Finish confirmation not shown")
        confirm.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
    }

    /// Discards the session on screen, confirming the question.
    @MainActor
    func discardSession(in app: XCUIApplication) {
        app.buttons["session.discard"].tap()
        let discard = app.buttons["Descartar"]
        XCTAssertTrue(discard.waitForExistence(timeout: 10), "Discard confirmation not shown")
        discard.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
    }

    // MARK: - Screenshots and measurements

    @MainActor
    func attachScreenshot(named name: String, of app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Keeps a measured value with the test result. The CI report prints the attachments whose name
    /// starts with "Medição", so a measurement can be read even when the test passes.
    @MainActor
    func recordMeasurement(_ name: String, _ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Brightness (0...1) of the screen at (`x`, `y`), in points, as the app's screenshot shows it.
    @MainActor
    func brightness(of app: XCUIApplication, atX x: CGFloat, y: CGFloat) -> CGFloat? {
        guard let image = app.screenshot().image.cgImage else { return nil }
        let frame = app.frame
        guard frame.width > 0, frame.height > 0 else { return nil }
        let column = Int(x / frame.width * CGFloat(image.width))
        let row = Int(y / frame.height * CGFloat(image.height))
        return pixelBrightness(of: image, x: column, y: row)
    }

    /// Checks that the screen background is dark: samples the left margin, a quarter of the way down,
    /// and keeps the measured value and the limit with the result.
    @MainActor
    func assertScreenIsDark(_ app: XCUIApplication, _ description: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let image = app.screenshot().image.cgImage,
              let value = pixelBrightness(of: image, x: 4, y: image.height / 4) else {
            XCTFail("Could not measure the brightness of \(description)", file: file, line: line)
            return
        }
        recordMeasurement(
            "Medição: brilho do fundo (\(description))",
            String(format: "%.3f (limite %.2f)", value, darkBrightnessLimit)
        )
        XCTAssertLessThan(value, darkBrightnessLimit, "\(description) is not dark: brightness \(value)", file: file, line: line)
    }
}
