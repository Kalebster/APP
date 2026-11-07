import Foundation

/// How long a short notice ("Peso salvo") stays on screen: 2,5 s, or 4 s for a text of more than 40
/// characters, which takes longer to read.
enum ToastDuration {
    static func standard(for text: String) -> Duration {
        text.count > 40 ? .seconds(4) : .seconds(2.5)
    }

    /// The standard time, or, in a Debug build launched for interface tests, the seconds given with
    /// `-ui-toast-seconds <s>`: a test hook, so a test on a slow machine can still read a notice (after a
    /// tap that closed two sheets, the test only looked at the screen again 9,6 s later in CI). The app as
    /// people use it always has the standard time.
    static func current(for text: String, arguments: [String] = ProcessInfo.processInfo.arguments) -> Duration {
        #if DEBUG
        if arguments.contains("-ui-testing"),
           let index = arguments.firstIndex(of: "-ui-toast-seconds"),
           arguments.indices.contains(index + 1),
           let seconds = Double(arguments[index + 1]),
           seconds.isFinite, seconds > 0 {
            return .seconds(seconds)
        }
        #endif
        return standard(for: text)
    }
}
