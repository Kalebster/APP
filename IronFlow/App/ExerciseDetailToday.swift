import Foundation

/// The "today" the exercise screen counts its periods back from: now, or, in a Debug build launched for
/// interface tests, the day given with `-ui-today <AAAA-MM-DD>` (at noon, in the device's time zone): a
/// test hook, so the screenshots of the exercise screen show the same periods as the approved prototype,
/// whose "today" is 16 October 2026. Only the exercise screen reads it; the app as people use it always
/// has now.
enum ExerciseDetailToday {
    static func current(arguments: [String] = ProcessInfo.processInfo.arguments, now: Date = .now) -> Date {
        #if DEBUG
        if arguments.contains("-ui-testing"),
           let index = arguments.firstIndex(of: "-ui-today"),
           arguments.indices.contains(index + 1) {
            let parts = arguments[index + 1].split(separator: "-").compactMap { Int($0) }
            if parts.count == 3,
               let day = TrainingDay.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) {
                return day
            }
        }
        #endif
        return now
    }
}
