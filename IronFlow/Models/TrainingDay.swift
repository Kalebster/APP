import Foundation

/// Calendar days of training, shared by the week on the Home, the days marked as trained outside
/// the app and the weekly plan.
enum TrainingDay {
    /// The weekdays of the weekly plan: 1 = Monday to 7 = Sunday. Not the `Calendar` weekday, where
    /// 1 is Sunday in every calendar.
    static let planWeekdays = 1...7

    /// The weekday of the weekly plan of `date`, from 1 (Monday) to 7 (Sunday), in the time zone of
    /// `calendar`. It does not depend on the first weekday of the calendar or its locale.
    static func planWeekday(of date: Date, calendar: Calendar) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    /// The whole day of `date` in `calendar`: from its start to the start of the next day, not
    /// included. A day of 23 or 25 hours keeps its limits. An empty interval in the case that cannot
    /// happen in the Gregorian calendar, so nothing is ever found in a day that cannot be built.
    static func dayInterval(of date: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 0)
    }

    /// The device's calendar days: Gregorian, in the device's time zone, following its changes.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    /// The calendar date of `date` in the time zone of `calendar`, as "AAAA-MM-DD". The date is always
    /// Gregorian, whatever the calendar, so the same day always has the same key.
    static func key(for date: Date, calendar: Calendar) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let components = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
