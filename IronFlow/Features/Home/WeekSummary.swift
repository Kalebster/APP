import Foundation

/// The Home "Sua semana" card: the current week from Monday to Sunday, the state of each day, the
/// week's count and its goal. Pure logic: no UI and no store access.
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
        /// How the day's circle looks. Today also has a ring, whatever its state.
        enum Appearance: Equatable, Sendable {
            /// A finished session started on the day (even if it was marked too): solid accent.
            case trainedInApp
            /// Marked as trained outside the app only: dashed accent border.
            case markedOutside
            /// A day before today without a workout: a gray circle.
            case missed
            /// Today, without a workout yet: only today's ring.
            case todayWithoutWorkout
            /// A day after today: the number only.
            case future
        }

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
        /// "Quarta", what VoiceOver reads before the day of the month.
        let weekdayName: String
        let isToday: Bool
        let isFuture: Bool
        /// Finished sessions started on the day.
        let appWorkouts: Int
        let isMarked: Bool
        /// The weekly plan has a workout on the day.
        let isPlanned: Bool

        var id: String { key }

        var isTrained: Bool { appWorkouts > 0 || isMarked }

        var appearance: Appearance {
            if appWorkouts > 0 { return .trainedInApp }
            if isMarked { return .markedOutside }
            if isFuture { return .future }
            return isToday ? .todayWithoutWorkout : .missed
        }

        /// A planned day still to do (today or later, without a workout) shows a dot below its circle.
        var showsPlanDot: Bool {
            isPlanned && !isTrained && (isToday || isFuture)
        }

        /// A future day cannot be touched; a marked day can be unmarked; a day trained only in the
        /// app keeps its record; any other day can be marked.
        var tapAction: TapAction {
            if isFuture { return .unavailable }
            if isMarked { return .confirmUnmark }
            if appWorkouts > 0 { return .unavailable }
            return .mark
        }

        /// "feito no app", "marcado como feito fora do app", both, "treino programado" for a planned
        /// day still to do, "dia futuro" or "sem treino".
        var stateText: String {
            switch (appWorkouts > 0, isMarked) {
            case (true, true): String(localized: "feito no app e marcado fora do app")
            case (true, false): String(localized: "feito no app")
            case (false, true): String(localized: "marcado como feito fora do app")
            case (false, false):
                if showsPlanDot {
                    String(localized: "treino programado")
                } else {
                    isFuture ? String(localized: "dia futuro") : String(localized: "sem treino")
                }
            }
        }

        /// What VoiceOver reads: "Quarta, 14, marcado como feito fora do app" or
        /// "Sexta, 16, hoje, treino programado".
        var accessibilityText: String {
            var parts = [weekdayName, number.formatted()]
            if isToday {
                parts.append(String(localized: "hoje"))
            }
            parts.append(stateText)
            return parts.joined(separator: ", ")
        }
    }

    /// The week's goal: the workouts done against the days of the weekly plan.
    struct Goal: Equatable, Sendable {
        /// Finished sessions plus days marked as trained outside the app; it can go past `total`.
        let done: Int
        /// Days of the weekly plan with a workout; more than zero.
        let total: Int

        /// The filled part of the ring, from 0 to 1: it stops at 1 when the week goes past the goal.
        var progress: Double {
            min(Double(done) / Double(total), 1)
        }

        var isComplete: Bool { done >= total }

        /// "3/4", in the middle of the ring.
        var ringText: String { "\(done)/\(total)" }

        /// "treinos" under `ringText`; "treino" for a goal of one.
        var ringCaption: String {
            total == 1 ? String(localized: "treino") : String(localized: "treinos")
        }

        /// "3 de 4 treinos"; "1 de 1 treino".
        var titleText: String {
            total == 1 ? String(localized: "\(done) de 1 treino") : String(localized: "\(done) de \(total) treinos")
        }

        /// "Falta 1 para fechar a semana", "Faltam 2 para fechar a semana" or, at the goal and past it,
        /// "Semana completa".
        var remainingText: String {
            switch total - done {
            case ...0: String(localized: "Semana completa")
            case 1: String(localized: "Falta 1 para fechar a semana")
            case let remaining: String(localized: "Faltam \(remaining) para fechar a semana")
            }
        }

        /// What VoiceOver reads for the ring: "3 de 4 treinos programados feitos".
        var accessibilityText: String {
            total == 1
                ? String(localized: "\(done) de 1 treino programado feito")
                : String(localized: "\(done) de \(total) treinos programados feitos")
        }
    }

    /// The app is in Brazilian Portuguese only.
    private static let locale = Locale(identifier: "pt_BR")
    /// The letters of the days, Monday to Sunday.
    private static let letters = ["S", "T", "Q", "Q", "S", "S", "D"]
    /// The names of the days that VoiceOver reads, Monday to Sunday.
    private static var weekdayNames: [String] {
        [
            String(localized: "Segunda"), String(localized: "Terça"), String(localized: "Quarta"),
            String(localized: "Quinta"), String(localized: "Sexta"), String(localized: "Sábado"),
            String(localized: "Domingo"),
        ]
    }

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
    /// duplicate never counts twice. `plannedWeekdays` are the weekdays of the weekly plan with a
    /// workout, 1 = Monday to 7 = Sunday (`WeeklyPlanSummary.plannedWeekdays(plan:workouts:)`).
    static func days(
        of week: Week,
        now: Date,
        calendar: Calendar,
        sessions: [Session],
        markedDays: [String],
        plannedWeekdays: Set<Int> = []
    ) -> [Day] {
        var appWorkouts: [String: Int] = [:]
        for session in sessions where session.endedAt != nil {
            appWorkouts[TrainingDay.key(for: session.startedAt, calendar: calendar), default: 0] += 1
        }
        let marked = Set(markedDays)
        let today = TrainingDay.key(for: now, calendar: calendar)
        var dateStyle = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide).locale(locale)
        dateStyle.timeZone = calendar.timeZone
        let names = weekdayNames

        return week.days.indices.map { index in
            let date = week.days[index]
            let key = week.keys[index]
            return Day(
                key: key,
                date: date,
                letter: letters[index],
                number: calendar.component(.day, from: date),
                dateText: date.formatted(dateStyle),
                weekdayName: names[index],
                // Keys are "AAAA-MM-DD", so their order is the order of the days.
                isToday: key == today,
                isFuture: key > today,
                appWorkouts: appWorkouts[key] ?? 0,
                isMarked: marked.contains(key),
                // The days run from Monday, the plan's weekday 1.
                isPlanned: plannedWeekdays.contains(index + 1)
            )
        }
    }

    /// Finished sessions of the week plus the days marked as trained outside the app.
    static func workoutCount(of days: [Day]) -> Int {
        days.reduce(0) { $0 + $1.appWorkouts + ($1.isMarked ? 1 : 0) }
    }

    /// The week's goal: every workout of the week (`workoutCount(of:)`) against the days of the weekly
    /// plan with a workout. `nil` without a plan: then the card shows the count only.
    static func goal(of days: [Day], plannedDays: Int) -> Goal? {
        plannedDays > 0 ? Goal(done: workoutCount(of: days), total: plannedDays) : nil
    }

    /// "0 treinos esta semana", "1 treino esta semana", "2 treinos esta semana". The singular is chosen
    /// here: the Portuguese plural rules treat 0 as singular, which would read "0 treino".
    static func workoutsText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 treino esta semana") : String(localized: "\(count) treinos esta semana")
    }

    // MARK: - Private

    /// The start of the day `offset` days after `day`. The Gregorian calendar always has that day.
    private static func startOfDay(adding offset: Int, to day: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: day) ?? day)
    }
}
