import Foundation

/// The Home "Sua semana" card: the current week from Monday to Sunday, the state of each day and
/// the week's counts. Pure logic: no UI and no store access.
enum WeekSummary {
    /// The limits and days of one week.
    struct Week: Hashable, Sendable {
        /// Monday at the start of the day.
        let start: Date
        /// The next Monday at the start of the day, not included.
        let end: Date
        /// The start of each day, Monday to Sunday.
        let days: [Date]
        /// The calendar date of each day, "AAAA-MM-DD" (`TrainingDay.key(for:calendar:)`).
        let keys: [String]
    }

    /// One day of the week, as the card shows it.
    struct Day: Equatable, Identifiable, Sendable {
        /// What a tap on the day does.
        enum TapAction: Equatable, Sendable {
            /// Nothing: a future day, or a day trained in the app only.
            case unavailable
            /// Marks the day as trained outside the app.
            case mark
            /// Asks before removing the day's marking.
            case confirmUnmark
        }

        /// The calendar date, "AAAA-MM-DD"; also the key of the day's marking.
        let key: String
        /// The start of the day.
        let date: Date
        /// "S", "T", "Q", "Q", "S", "S" or "D", Monday to Sunday.
        let letter: String
        /// The day of the month.
        let number: Int
        /// "quarta-feira, 14 de outubro".
        let dateText: String
        let isToday: Bool
        let isFuture: Bool
        /// Finished sessions started on the day.
        let appWorkouts: Int
        let isMarked: Bool

        var id: String { key }

        var isTrained: Bool { appWorkouts > 0 || isMarked }

        /// A future day cannot be touched; a marked day can be unmarked; a day trained only in the
        /// app keeps its record; any other day can be marked.
        var tapAction: TapAction {
            if isFuture { return .unavailable }
            if isMarked { return .confirmUnmark }
            if appWorkouts > 0 { return .unavailable }
            return .mark
        }

        /// "treinou no app", "marcado manualmente", both, "sem treino" or "dia futuro".
        var stateText: String {
            switch (appWorkouts > 0, isMarked) {
            case (true, true): String(localized: "treinou no app e marcado manualmente")
            case (true, false): String(localized: "treinou no app")
            case (false, true): String(localized: "marcado manualmente")
            case (false, false): isFuture ? String(localized: "dia futuro") : String(localized: "sem treino")
            }
        }

        /// What VoiceOver reads: "quarta-feira, 14 de outubro, hoje, marcado manualmente".
        var accessibilityText: String {
            let parts = isToday ? [dateText, String(localized: "hoje"), stateText] : [dateText, stateText]
            return parts.joined(separator: ", ")
        }
    }

    /// The app is in Brazilian Portuguese only.
    private static let locale = Locale(identifier: "pt_BR")
    /// The letters of the days, Monday to Sunday.
    private static let letters = ["S", "T", "Q", "Q", "S", "S", "D"]

    /// The week of `date`, from Monday to Sunday in `calendar`. It always starts on Monday, whatever
    /// the first weekday of the calendar or its locale. Days are counted with the calendar, never by
    /// adding 24 hours, so days of 23 or 25 hours (daylight saving time) keep their limits.
    static func week(containing date: Date, calendar: Calendar) -> Week {
        let today = calendar.startOfDay(for: date)
        // `weekday` is 1 for Sunday to 7 for Saturday in every calendar, so Monday is 2.
        let daysSinceMonday = (calendar.component(.weekday, from: today) + 5) % 7
        let monday = startOfDay(adding: -daysSinceMonday, to: today, calendar: calendar)
        let days = (0..<7).map { startOfDay(adding: $0, to: monday, calendar: calendar) }
        return Week(
            start: monday,
            end: startOfDay(adding: 7, to: monday, calendar: calendar),
            days: days,
            keys: days.map { TrainingDay.key(for: $0, calendar: calendar) }
        )
    }

    /// The days of `week` at `now`. A finished session counts on the day it started; the session in
    /// progress does not count. A day counts as marked once, however many markings it has, so a
    /// duplicate never counts twice.
    static func days(
        of week: Week,
        now: Date,
        calendar: Calendar,
        sessions: [Session],
        markedDays: [String]
    ) -> [Day] {
        var appWorkouts: [String: Int] = [:]
        for session in sessions where session.endedAt != nil {
            appWorkouts[TrainingDay.key(for: session.startedAt, calendar: calendar), default: 0] += 1
        }
        let marked = Set(markedDays)
        let today = TrainingDay.key(for: now, calendar: calendar)
        var dateStyle = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide).locale(locale)
        dateStyle.timeZone = calendar.timeZone

        return week.days.indices.map { index in
            let date = week.days[index]
            let key = week.keys[index]
            return Day(
                key: key,
                date: date,
                letter: letters[index],
                number: calendar.component(.day, from: date),
                dateText: date.formatted(dateStyle),
                // Keys are "AAAA-MM-DD", so their order is the order of the days.
                isToday: key == today,
                isFuture: key > today,
                appWorkouts: appWorkouts[key] ?? 0,
                isMarked: marked.contains(key)
            )
        }
    }

    /// Finished sessions of the week plus the days marked as trained outside the app.
    static func workoutCount(of days: [Day]) -> Int {
        days.reduce(0) { $0 + $1.appWorkouts + ($1.isMarked ? 1 : 0) }
    }

    /// Days of the week with at least one finished session or a marking.
    static func trainedDayCount(of days: [Day]) -> Int {
        days.filter(\.isTrained).count
    }

    /// "0 treinos esta semana", "1 treino esta semana", "2 treinos esta semana". The singular is chosen
    /// here: the Portuguese plural rules treat 0 as singular, which would read "0 treino".
    static func workoutsText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 treino esta semana") : String(localized: "\(count) treinos esta semana")
    }

    /// "3/7 dias".
    static func trainedDaysText(_ count: Int) -> String {
        String(localized: "\(count)/7 dias")
    }

    // MARK: - Private

    /// The start of the day `offset` days after `day`. The Gregorian calendar always has that day.
    private static func startOfDay(adding offset: Int, to day: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: day) ?? day)
    }
}
