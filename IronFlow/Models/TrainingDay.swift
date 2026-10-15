import Foundation

/// Calendar days of training, shared by the week on the Home and the days marked as trained outside
/// the app.
enum TrainingDay {
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
