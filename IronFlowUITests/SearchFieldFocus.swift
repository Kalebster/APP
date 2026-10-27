import XCTest

extension XCUIElement {
    /// Taps this field (a search field or any text field) and waits until it has keyboard focus, so
    /// typing never starts before the field can receive it. `offset` is where to tap, as a fraction of
    /// the field; without it, the field is tapped as a whole.
    ///
    /// Typing checks the same condition (`hasKeyboardFocus`) and fails at once without it. On a busy
    /// simulator the search bar can stay inactive after the tap (seen in CI: no focus and still at its
    /// resting position 1.5 s later), so the field is tapped once more when the focus does not come.
    @MainActor
    func tapAndWaitForKeyboardFocus(at offset: CGVector? = nil, file: StaticString = #filePath, line: UInt = #line) {
        tap(at: offset)
        if waitForKeyboardFocus(timeout: 5) {
            return
        }
        tap(at: offset)
        XCTAssertTrue(waitForKeyboardFocus(timeout: 10), "Field did not get keyboard focus", file: file, line: line)
    }

    /// Waits until this field holds `text`. On a busy simulator the field's value can lag behind the
    /// typed keys (seen in CI: "a" read right after typing "agach", which the screen then showed), so
    /// the value is checked only after it had the time to arrive. Returns whether it arrived; a lost
    /// key still shows as a wrong value in the check that follows.
    @MainActor
    @discardableResult
    func waitForValue(_ text: String, timeout: TimeInterval = 5) -> Bool {
        let holds = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", text), object: self)
        return XCTWaiter().wait(for: [holds], timeout: timeout) == .completed
    }

    @MainActor
    private func tap(at offset: CGVector?) {
        if let offset {
            coordinate(withNormalizedOffset: offset).tap()
        } else {
            tap()
        }
    }

    @MainActor
    private func waitForKeyboardFocus(timeout: TimeInterval) -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: self)
        return XCTWaiter().wait(for: [focused], timeout: timeout) == .completed
    }
}
