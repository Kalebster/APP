import CoreGraphics
import XCTest

/// Highest brightness (0...1) a pixel of the app's background may have for the app to count as dark.
/// The dark background is about 0.05 and a light one is above 0.9, so there is a wide margin.
let darkBrightnessLimit: CGFloat = 0.3

/// Highest brightness (0...1) the space bar may have for the keyboard to count as dark. The keys of the
/// dark keyboard are gray, not black, so the background limit does not fit them: in CI the space bar
/// measured 0.25 on the app's keyboard and 1.00 on the light keyboard of the simulator's Settings app
/// (white keys). The limit lies between the two, with a wide margin on both sides.
let darkKeyBrightnessLimit: CGFloat = 0.6

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

/// The base of every interface test. When a test fails it keeps the text of what was on the app's
/// screen, which the CI report prints: a failure message says which element was not found, and this
/// says what was there instead. Xcode attaches only the query that failed, not the screen.
class IronFlowUITestCase: XCTestCase {
    /// XCTest runs its asynchronous `tearDown` off the main actor, and a test case is not `Sendable`, so
    /// it cannot be sent to the main actor as it is. The screen is read there, and nothing else uses the
    /// test case meanwhile: the test has ended.
    private struct Handle: @unchecked Sendable {
        let testCase: IronFlowUITestCase
    }

    override func tearDown() async throws {
        let handle = Handle(testCase: self)
        await MainActor.run { handle.testCase.attachScreenHierarchyIfTheTestFailed() }
        try await super.tearDown()
    }
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
            // Percent-encoded (ASCII only), so accented names reach the app as written; `UITestSeed` decodes it.
            let list = seed.joined(separator: ",")
            arguments += ["-ui-seed", list.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? list]
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

    /// Waits until the tab bar is off the screen: hidden on the workout editor and the weekly plan, as in
    /// the model.
    @MainActor
    func waitForHiddenTabBar(in app: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
        let hidden = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false OR hittable == false"),
            object: app.tabBars.buttons["Início"]
        )
        return XCTWaiter().wait(for: [hidden], timeout: timeout) == .completed
    }

    /// Waits until the element's label contains `text`.
    @MainActor
    func waitForLabel(of element: XCUIElement, containing text: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }

    /// Waits for the notice at the top of the screen to read `text`, looking every tenth of a second: a
    /// notice stays 2,5 s, which the usual waits, about a second apart, can miss after a sheet closes or
    /// a screen changes.
    @MainActor
    func waitForToast(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
        let toast = app.staticTexts["toast"]
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if toast.exists && toast.label == text {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return false
    }

    /// Waits until the element's label is exactly `label`.
    @MainActor
    func waitForLabel(of element: XCUIElement, toBe label: String, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
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

    /// Closes the keyboard's one-time introduction to typing by sliding over the letters ("Speed up your
    /// typing…"), which covers the keys the first time a simulator shows the keyboard, by tapping its
    /// button. Does nothing when it is not shown; once closed, the simulator does not show it again.
    @MainActor
    func dismissKeyboardIntroductionIfShown(in app: XCUIApplication) {
        let button = app.buttons.matching(NSPredicate(format: "label IN %@", ["Continue", "Continuar"])).firstMatch
        guard button.waitForExistence(timeout: 2) else { return }
        button.tap()
        XCTAssertTrue(button.waitForNonExistence(timeout: 10), "The keyboard introduction did not close")
    }

    /// Taps 15 points above the vertical center of a field, beside its text but inside a box 44 points
    /// tall, and waits until the field has keyboard focus: the whole box must respond, not only the text.
    @MainActor
    func tapAboveTheTextAndWaitForFocus(of field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: -15)).tap()
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        XCTAssertTrue(XCTWaiter().wait(for: [focused], timeout: 10) == .completed, "A tap beside the text did not focus the field", file: file, line: line)
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
        waitForEditor(of: name, in: app)
    }

    /// Opens the editor of the first workout on the Treinos list, from its card.
    @MainActor
    func openWorkout(named name: String, in app: XCUIApplication) {
        let card = app.buttons["workouts.card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Workout card not shown")
        card.tap()
        waitForEditor(of: name, in: app)
    }

    /// Waits for the editor of the workout `name`, from its title.
    @MainActor
    func waitForEditor(of name: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let title = element("workout.title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Editor of '\(name)' did not open", file: file, line: line)
        XCTAssertTrue(waitForLabel(of: title, toBe: name), "Editor title: \(title.label)", file: file, line: line)
    }

    /// In the workout editor on screen: goes back to the Treinos list with "‹ Treinos".
    @MainActor
    func goBackFromEditor(in app: XCUIApplication) {
        let back = app.buttons["workout.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Back button not found")
        back.tap()
        XCTAssertTrue(app.buttons["workouts.add"].waitForExistence(timeout: 10), "Treinos list not shown")
    }

    /// In the workout editor on screen: deletes the workout from its ⋮ menu, confirming the question.
    @MainActor
    func deleteWorkoutFromEditor(in app: XCUIApplication) {
        app.buttons["workout.menu"].tap()
        let delete = app.buttons["Excluir treino"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "Delete option not found")
        delete.tap()
        let confirm = app.buttons["Excluir"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Delete confirmation not shown")
        confirm.tap()
    }

    /// Chooses one exercise in the exercise picker on screen (the one of a workout or of a session),
    /// by searching its exact name, and confirms with "Adicionar".
    @MainActor
    func pickExercise(_ name: String, in app: XCUIApplication) {
        searchPicker(for: name, in: app)
        let card = pickerCard(name, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Exercise '\(name)' not found in the picker")
        card.tap()
        app.buttons["picker.add"].tap()
    }

    /// Types `text` in the search of the exercise picker on screen, replacing what it held.
    @MainActor
    func searchPicker(for text: String, in app: XCUIApplication) {
        let search = app.textFields["picker.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10), "Picker search field not found")
        let clear = app.buttons["picker.search.clear"]
        if clear.exists {
            clear.tap()
        }
        search.tapAndWaitForKeyboardFocus()
        search.typeText(text)
    }

    /// The card of the exercise `name` in the exercise picker on screen. Its label starts with the name,
    /// followed by the group, the focus and the equipment.
    @MainActor
    func pickerCard(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "picker.card", "\(name), "))
            .firstMatch
    }

    /// Starts a workout from its ▶ button on the Treinos tab and waits for the session screen.
    @MainActor
    func startWorkout(named name: String, in app: XCUIApplication) {
        let start = app.buttons["Iniciar \(name)"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "No ▶ for '\(name)'")
        start.tap()
        XCTAssertTrue(element("session.name", in: app).waitForExistence(timeout: 10), "Session screen not shown")
    }

    /// In the session on screen: completes the first set and finishes it with "Concluir e salvar"; the
    /// sets left undone are not saved.
    @MainActor
    func completeFirstSetAndFinishSession(in app: XCUIApplication) {
        app.buttons.matching(identifier: "session.set.check").element(boundBy: 0).tap()
        saveSessionFromTheFinishSheet(in: app)
    }

    /// In the session on screen, with a set done: "Concluir", then "Concluir e salvar" in "Concluir treino?".
    @MainActor
    func saveSessionFromTheFinishSheet(in app: XCUIApplication) {
        app.buttons["session.finish"].tap()
        let save = app.buttons["finish.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Concluir treino? not shown")
        save.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
    }

    /// Discards the session on screen from its ⋯ menu, confirming the question.
    @MainActor
    func discardSession(in app: XCUIApplication) {
        app.buttons["session.more"].tap()
        let option = app.buttons["Descartar treino"]
        XCTAssertTrue(option.waitForExistence(timeout: 10), "No Descartar treino in the ⋯ menu")
        option.tap()
        let discard = app.buttons["Descartar"]
        XCTAssertTrue(discard.waitForExistence(timeout: 10), "Discard confirmation not shown")
        discard.tap()
        XCTAssertTrue(element("session.name", in: app).waitForNonExistence(timeout: 10), "Session screen not closed")
    }

    // MARK: - Screenshots and measurements

    /// Attaches the hierarchy of the app's screen, as text, when the test that just ended has failed.
    /// The app is only asked for it while it is running, so a crash is not made worse by a second error.
    @MainActor
    func attachScreenHierarchyIfTheTestFailed() {
        guard (testRun?.totalFailureCount ?? 0) > 0 else { return }
        let app = XCUIApplication()
        let attachment = XCTAttachment(string: app.state == .runningForeground
            ? app.debugDescription
            : "The app was not on screen when the test ended (state \(app.state.rawValue)).")
        attachment.name = "App UI hierarchy (failed test)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

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
