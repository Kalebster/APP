import Foundation

/// How long "Pronto" stays on the rest bar once the rest reaches zero: 2,5 s.
enum RestReadyDuration {
    static let standard: Duration = .seconds(2.5)

    /// 2,5 s, or, in a Debug build launched for interface tests, the seconds given with
    /// `-ui-rest-ready-seconds <s>`: a test hook, so a test on a slow machine can read "Pronto" (one
    /// reading of the screen has taken 8 s in CI). The app as people use it always has 2,5 s.
    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> Duration {
        #if DEBUG
        if arguments.contains("-ui-testing"),
           let index = arguments.firstIndex(of: "-ui-rest-ready-seconds"),
           arguments.indices.contains(index + 1),
           let seconds = Double(arguments[index + 1]),
           seconds.isFinite, seconds > 0 {
            return .seconds(seconds)
        }
        #endif
        return standard
    }
}
