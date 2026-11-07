import Testing
@testable import IronFlow

/// A notice stays 2,5 s, or 4 s with a long text; only an interface test asks for longer, with
/// -ui-testing and its own argument.
struct ToastDurationTests {
    private let short = "Peso salvo"
    private let long = "Descanso acabou. Próxima: Supino Reto com Barra · série 3 de 5"

    @Test("2,5 s or 4 s unless -ui-testing and a valid -ui-toast-seconds")
    func duration() {
        #expect(ToastDuration.standard(for: short) == .seconds(2.5))
        #expect(ToastDuration.standard(for: long) == .seconds(4))
        // The tests' own process has no -ui-testing: a notice keeps its standard time.
        #expect(ToastMessage(short).duration == .seconds(2.5))
        #expect(ToastMessage(long).duration == .seconds(4))
        #expect(ToastDuration.current(for: short, arguments: []) == .seconds(2.5))
        #expect(ToastDuration.current(for: long, arguments: []) == .seconds(4))
        // Without -ui-testing the argument does nothing.
        #expect(ToastDuration.current(for: short, arguments: ["-ui-toast-seconds", "15"]) == .seconds(2.5))
        #expect(ToastDuration.current(for: long, arguments: ["-ui-toast-seconds", "15"]) == .seconds(4))
        #expect(ToastDuration.current(for: short, arguments: ["-ui-testing"]) == .seconds(2.5))
        #if DEBUG
        #expect(ToastDuration.current(for: short, arguments: ["-ui-testing", "-ui-toast-seconds", "15"]) == .seconds(15))
        #expect(ToastDuration.current(for: long, arguments: ["-ui-testing", "-ui-toast-seconds", "15"]) == .seconds(15))
        #else
        // The hook is compiled into Debug builds only.
        #expect(ToastDuration.current(for: short, arguments: ["-ui-testing", "-ui-toast-seconds", "15"]) == .seconds(2.5))
        #endif
        // Invalid, zero and negative values keep the standard time.
        for value in ["", "x", "0", "-5", "inf", "nan"] {
            #expect(ToastDuration.current(for: short, arguments: ["-ui-testing", "-ui-toast-seconds", value]) == .seconds(2.5))
            #expect(ToastDuration.current(for: long, arguments: ["-ui-testing", "-ui-toast-seconds", value]) == .seconds(4))
        }
        #expect(ToastDuration.current(for: short, arguments: ["-ui-testing", "-ui-toast-seconds"]) == .seconds(2.5))
    }
}
