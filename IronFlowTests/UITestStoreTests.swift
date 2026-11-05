import Foundation
import Testing
@testable import IronFlow

/// The interface tests' store on disk lives in the app's temporary folder, never in the real store's place.
struct UITestStoreTests {
    @Test("Only with -ui-testing and a name; inside tmp/ui-tests; never the real store")
    func location() throws {
        #expect(try UITestStore.url(in: ["-ui-store", "a"]) == nil)
        #expect(try UITestStore.url(in: ["-ui-testing"]) == nil)
        let url = try #require(try UITestStore.url(in: ["-ui-testing", "-ui-store", "reopen-1"]))
        #expect(url.lastPathComponent == "IronFlow.store")
        #expect(url.path(percentEncoded: false).hasPrefix(FileManager.default.temporaryDirectory.appending(path: "ui-tests").path(percentEncoded: false)))
        #expect(url != ModelContainerFactory.defaultStoreURL)
        for name in ["", "../x", "a/b", "."] {
            #expect(throws: UITestStore.InvalidName.self) {
                _ = try UITestStore.url(in: ["-ui-testing", "-ui-store", name])
            }
        }
    }
}
