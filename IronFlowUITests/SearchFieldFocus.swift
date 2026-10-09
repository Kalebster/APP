import XCTest

extension XCUIElement {
    /// Taps this search field and waits until it has keyboard focus, so typing never starts before
    /// the field can receive it.
    ///
    /// Typing checks the same condition (`hasKeyboardFocus`) and fails at once without it. On a busy
    /// simulator the search bar can stay inactive after the tap (seen in CI: no focus and still at its
    /// resting position 1.5 s later), so the field is tapped once more when the focus does not come.
    @MainActor
    func tapAndWaitForKeyboardFocus(file: StaticString = #filePath, line: UInt = #line) {
        tap()
        if waitForKeyboardFocus(timeout: 5) {
            return
        }
        tap()
        XCTAssertTrue(waitForKeyboardFocus(timeout: 10), "Search field did not get keyboard focus", file: file, line: line)
    }

    @MainActor
    private func waitForKeyboardFocus(timeout: TimeInterval) -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: self)
        return XCTWaiter().wait(for: [focused], timeout: timeout) == .completed
    }
}
