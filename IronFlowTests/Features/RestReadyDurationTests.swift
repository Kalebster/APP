import Testing
@testable import IronFlow

/// "Pronto" stays 2,5 s; only an interface test asks for longer, with -ui-testing and its own argument.
struct RestReadyDurationTests {
    @Test("2,5 s unless -ui-testing and a valid -ui-rest-ready-seconds")
    func duration() {
        #expect(RestReadyDuration.standard == .seconds(2.5))
        #expect(RestReadyDuration.current(arguments: []) == .seconds(2.5))
        #expect(RestReadyDuration.current(arguments: ["-ui-rest-ready-seconds", "20"]) == .seconds(2.5))
        #expect(RestReadyDuration.current(arguments: ["-ui-testing"]) == .seconds(2.5))
        #if DEBUG
        #expect(RestReadyDuration.current(arguments: ["-ui-testing", "-ui-rest-ready-seconds", "20"]) == .seconds(20))
        #else
        // The hook is compiled into Debug builds only.
        #expect(RestReadyDuration.current(arguments: ["-ui-testing", "-ui-rest-ready-seconds", "20"]) == .seconds(2.5))
        #endif
        for value in ["", "x", "0", "-5", "inf", "nan"] {
            #expect(RestReadyDuration.current(arguments: ["-ui-testing", "-ui-rest-ready-seconds", value]) == .seconds(2.5))
        }
        #expect(RestReadyDuration.current(arguments: ["-ui-testing", "-ui-rest-ready-seconds"]) == .seconds(2.5))
    }
}
