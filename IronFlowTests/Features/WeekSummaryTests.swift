import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// The "Sua semana" card: the week's limits, its counts and the state of each day, in fixed time zones.
@MainActor
struct WeekSummaryTests {
    /// A Gregorian calendar whose weeks start on Sunday, like pt_BR's, so the card must find Monday itself.
    private func makeCalendar(_ identifier: String = "America/Sao_Paulo") throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: identifier))
        calendar.locale = Locale(identifier: "pt_BR")
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, in calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }

    private func finishedSession(startedAt start: Date, in context: ModelContext) -> Session {
        let session = Session(startedAt: start, workoutNameSnapshot: "Push")
        session.endedAt = start.addingTimeInterval(3_600)
        context.insert(session)
        return session
    }

    @Test("The week runs from Monday to Sunday, whether today is Monday, Wednesday or Sunday")
    func mondayToSunday() throws {
        let calendar = try makeCalendar()
        let keys = ["2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16", "2026-10-17", "2026-10-18"]
        let monday = try date(2026, 10, 12, 0, in: calendar)
        let nextMonday = try date(2026, 10, 19, 0, in: calendar)

        for today in [12, 14, 18] {
            let week = try WeekSummary.week(containing: date(2026, 10, today, in: calendar), calendar: calendar)
            #expect(week.keys == keys)
            #expect(week.start == monday)
            #expect(week.end == nextMonday)
            #expect(week.days.map { calendar.component(.weekday, from: $0) } == [2, 3, 4, 5, 6, 7, 1])
            #expect(week.days.allSatisfy { calendar.startOfDay(for: $0) == $0 })
        }
        // The first and the last minute of the week belong to it.
        let lastMinute = try date(2026, 10, 18, 23, 59, in: calendar)
        #expect(WeekSummary.week(containing: monday, calendar: calendar).keys == keys)
        #expect(WeekSummary.week(containing: lastMinute, calendar: calendar).keys == keys)
    }

    @Test("A week that crosses a month or a year keeps its seven days")
    func monthAndYearTurns() throws {
        let calendar = try makeCalendar()

        let july = try WeekSummary.week(containing: date(2026, 7, 1, in: calendar), calendar: calendar)
        #expect(july.keys == ["2026-06-29", "2026-06-30", "2026-07-01", "2026-07-02", "2026-07-03", "2026-07-04", "2026-07-05"])

        let newYear = try WeekSummary.week(containing: date(2026, 1, 1, in: calendar), calendar: calendar)
        #expect(newYear.keys == ["2025-12-29", "2025-12-30", "2025-12-31", "2026-01-01", "2026-01-02", "2026-01-03", "2026-01-04"])
        let start = try date(2025, 12, 29, 0, in: calendar)
        let end = try date(2026, 1, 5, 0, in: calendar)
        #expect(newYear.start == start)
        #expect(newYear.end == end)
    }

    @Test("Days are counted with the calendar, so a day of 23 or 25 hours keeps its limits")
    func daylightSavingTime() throws {
        let calendar = try makeCalendar("America/New_York")

        // Clocks go forward on Sunday, 8 March 2026: that Sunday has 23 hours.
        let spring = try WeekSummary.week(containing: date(2026, 3, 4, in: calendar), calendar: calendar)
        #expect(spring.keys == ["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05", "2026-03-06", "2026-03-07", "2026-03-08"])
        let springEnd = try date(2026, 3, 9, 0, in: calendar)
        #expect(spring.end == springEnd)
        #expect(spring.end.timeIntervalSince(spring.days[6]) == TimeInterval(23 * 3_600))
        #expect(spring.days.allSatisfy { calendar.component(.hour, from: $0) == 0 })

        // Clocks go back on Sunday, 1 November 2026: that Sunday has 25 hours.
        let autumn = try WeekSummary.week(containing: date(2026, 10, 28, in: calendar), calendar: calendar)
        #expect(autumn.keys == ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01"])
        #expect(autumn.end.timeIntervalSince(autumn.days[6]) == TimeInterval(25 * 3_600))
        let lateSunday = try date(2026, 11, 1, 23, 30, in: calendar)
        #expect(TrainingDay.key(for: lateSunday, calendar: calendar) == "2026-11-01")
    }

    @Test("A day's key is its calendar date in the calendar's time zone")
    func dayKeys() throws {
        // 01:30 UTC on 15 October is still the 14th in São Paulo and already the 15th in Tokyo.
        let instant = try date(2026, 10, 15, 1, 30, in: makeCalendar("UTC"))
        let saoPaulo = try makeCalendar("America/Sao_Paulo")
        let tokyo = try makeCalendar("Asia/Tokyo")
        #expect(TrainingDay.key(for: instant, calendar: saoPaulo) == "2026-10-14")
        #expect(TrainingDay.key(for: instant, calendar: tokyo) == "2026-10-15")
        // Month and day always have two digits.
        let january = try date(2026, 1, 4, in: saoPaulo)
        #expect(TrainingDay.key(for: january, calendar: saoPaulo) == "2026-01-04")
    }

    @Test("The week counts finished sessions by the day they started, plus the marked days")
    func counts() throws {
        let calendar = try makeCalendar()
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = try date(2026, 10, 14, 15, in: calendar)
        let week = WeekSummary.week(containing: now, calendar: calendar)

        let inProgress = try Session(startedAt: date(2026, 10, 14, 14, in: calendar), workoutNameSnapshot: "Pull")
        context.insert(inProgress)
        let sessions = try [
            finishedSession(startedAt: date(2026, 10, 12, 8, in: calendar), in: context),
            finishedSession(startedAt: date(2026, 10, 12, 19, in: calendar), in: context),
            finishedSession(startedAt: date(2026, 10, 14, 7, in: calendar), in: context),
            // Started on the Sunday before and finished on Monday: it belongs to the week before.
            finishedSession(startedAt: date(2026, 10, 11, 23, 30, in: calendar), in: context),
            // Started on the next Monday: it belongs to the next week.
            finishedSession(startedAt: date(2026, 10, 19, 0, 0, in: calendar), in: context),
            inProgress,
        ]
        try context.save()

        let days = WeekSummary.days(
            of: week,
            now: now,
            calendar: calendar,
            sessions: sessions,
            markedDays: ["2026-10-13", "2026-10-14", "2026-10-20"]
        )

        // Monday has two sessions, Wednesday one; the session in progress does not count.
        #expect(days.map(\.appWorkouts) == [2, 0, 1, 0, 0, 0, 0])
        #expect(days.map(\.isMarked) == [false, true, true, false, false, false, false])
        // Three finished sessions and two marked days, on three distinct days.
        #expect(WeekSummary.workoutCount(of: days) == 5)
        #expect(WeekSummary.trainedDayCount(of: days) == 3)
    }

    @Test("Two markings of the same day count as one workout and one day")
    func duplicateMarkingsCountOnce() throws {
        let calendar = try makeCalendar()
        let now = try date(2026, 10, 14, 15, in: calendar)
        let week = WeekSummary.week(containing: now, calendar: calendar)

        let days = WeekSummary.days(of: week, now: now, calendar: calendar, sessions: [], markedDays: ["2026-10-13", "2026-10-13"])

        #expect(days.map(\.isMarked) == [false, true, false, false, false, false, false])
        #expect(WeekSummary.workoutCount(of: days) == 1)
        #expect(WeekSummary.trainedDayCount(of: days) == 1)
    }

    @Test("Each day shows its letter, number and state, and what a tap on it does")
    func dayStates() throws {
        let calendar = try makeCalendar()
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = try date(2026, 10, 14, 15, in: calendar)
        let week = WeekSummary.week(containing: now, calendar: calendar)
        let sessions = try [
            finishedSession(startedAt: date(2026, 10, 12, 8, in: calendar), in: context),
            finishedSession(startedAt: date(2026, 10, 14, 7, in: calendar), in: context),
        ]
        try context.save()

        // Monday: in the app; Tuesday: marked; Wednesday (today): both; Thursday to Sunday: future.
        let days = WeekSummary.days(of: week, now: now, calendar: calendar, sessions: sessions, markedDays: ["2026-10-13", "2026-10-14"])

        #expect(days.map(\.letter) == ["S", "T", "Q", "Q", "S", "S", "D"])
        #expect(days.map(\.number) == [12, 13, 14, 15, 16, 17, 18])
        #expect(days.map(\.isToday) == [false, false, true, false, false, false, false])
        #expect(days.map(\.isFuture) == [false, false, false, true, true, true, true])
        let actions: [WeekSummary.Day.TapAction] = [.unavailable, .confirmUnmark, .confirmUnmark, .unavailable, .unavailable, .unavailable, .unavailable]
        #expect(days.map(\.tapAction) == actions)
        #expect(days.map(\.stateText) == [
            "treinou no app", "marcado manualmente", "treinou no app e marcado manualmente",
            "dia futuro", "dia futuro", "dia futuro", "dia futuro",
        ])
        #expect(days[0].dateText.hasPrefix("segunda-feira"))
        #expect(days[2].dateText.contains("14 de outubro"))
        #expect(days[2].accessibilityText == "\(days[2].dateText), hoje, treinou no app e marcado manualmente")
        #expect(days[1].accessibilityText == "\(days[1].dateText), marcado manualmente")

        // With nothing recorded, today and the days before it can be marked.
        let empty = WeekSummary.days(of: week, now: now, calendar: calendar, sessions: [], markedDays: [])
        let emptyActions: [WeekSummary.Day.TapAction] = [.mark, .mark, .mark, .unavailable, .unavailable, .unavailable, .unavailable]
        #expect(empty.map(\.tapAction) == emptyActions)
        #expect(empty[0].stateText == "sem treino")
        #expect(empty[2].accessibilityText == "\(empty[2].dateText), hoje, sem treino")
    }

    @Test("The counts read in Portuguese: none, one and more workouts, and days out of seven")
    func countTexts() {
        #expect(WeekSummary.workoutsText(0) == "0 treinos esta semana")
        #expect(WeekSummary.workoutsText(1) == "1 treino esta semana")
        #expect(WeekSummary.workoutsText(2) == "2 treinos esta semana")
        #expect(WeekSummary.trainedDaysText(0) == "0/7 dias")
        #expect(WeekSummary.trainedDaysText(7) == "7/7 dias")
    }
}
