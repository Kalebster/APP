import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// The "Sua semana" card: the week's limits, its count and goal, and the state and look of each day, in
/// fixed time zones.
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
        // Three finished sessions and two marked days, on three distinct days: without a plan the card
        // counts every workout.
        #expect(WeekSummary.workoutCount(of: days) == 5)
        #expect(days.filter(\.isTrained).count == 3)
        // The goal counts each day with a workout once: Monday's two sessions, and Wednesday's session
        // and marking, count one day each.
        #expect(WeekSummary.trainedDayCount(of: days) == 3)
        #expect(WeekSummary.goal(of: days, plannedDays: 4) == WeekSummary.Goal(done: 3, total: 4))
        // It can go past the planned days.
        #expect(WeekSummary.goal(of: days, plannedDays: 2) == WeekSummary.Goal(done: 3, total: 2))
        #expect(WeekSummary.goal(of: days, plannedDays: 0) == nil)
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
        #expect(days.filter(\.isTrained).count == 1)
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
            "feito no app", "marcado como feito fora do app", "feito no app e marcado fora do app",
            "dia futuro", "dia futuro", "dia futuro", "dia futuro",
        ])
        #expect(days[0].dateText.hasPrefix("segunda-feira"))
        #expect(days[2].dateText.contains("14 de outubro"))
        #expect(days[2].accessibilityText == "Quarta, 14, hoje, feito no app e marcado fora do app")
        #expect(days[1].accessibilityText == "Terça, 13, marcado como feito fora do app")

        // With nothing recorded, today and the days before it can be marked.
        let empty = WeekSummary.days(of: week, now: now, calendar: calendar, sessions: [], markedDays: [])
        let emptyActions: [WeekSummary.Day.TapAction] = [.mark, .mark, .mark, .unavailable, .unavailable, .unavailable, .unavailable]
        #expect(empty.map(\.tapAction) == emptyActions)
        #expect(empty[0].stateText == "sem treino")
        #expect(empty[2].accessibilityText == "Quarta, 14, hoje, sem treino")
        #expect(empty.map(\.weekdayName) == ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"])
    }

    @Test("Each day's look: in the app, marked outside the app, missed, today without a workout and future; a dot on planned days still to do")
    func dayAppearance() throws {
        let calendar = try makeCalendar()
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        // Thursday the 15th; Monday, Wednesday, Thursday and Saturday are planned.
        let now = try date(2026, 10, 15, 15, in: calendar)
        let week = WeekSummary.week(containing: now, calendar: calendar)
        let sessions = try [finishedSession(startedAt: date(2026, 10, 12, 8, in: calendar), in: context)]
        try context.save()

        let days = WeekSummary.days(
            of: week, now: now, calendar: calendar, sessions: sessions,
            markedDays: ["2026-10-13"], plannedWeekdays: [1, 3, 4, 6]
        )

        let looks: [WeekSummary.Day.Appearance] = [.trainedInApp, .markedOutside, .missed, .todayWithoutWorkout, .future, .future, .future]
        #expect(days.map(\.appearance) == looks)
        #expect(days.map(\.isPlanned) == [true, false, true, true, false, true, false])
        // Monday is done and Wednesday has passed: only today and Saturday still wait for their workout.
        #expect(days.map(\.showsPlanDot) == [false, false, false, true, false, true, false])
        #expect(days.map(\.stateText) == [
            "feito no app", "marcado como feito fora do app", "sem treino", "treino programado",
            "dia futuro", "treino programado", "dia futuro",
        ])
        #expect(days[3].accessibilityText == "Quinta, 15, hoje, treino programado")
        #expect(days[5].accessibilityText == "Sábado, 17, treino programado")

        // Trained in the app and marked too: the app's workout decides the look. Today, once trained,
        // keeps no dot.
        let both = WeekSummary.days(
            of: week, now: try date(2026, 10, 12, 20, in: calendar), calendar: calendar, sessions: sessions,
            markedDays: ["2026-10-12"], plannedWeekdays: [1]
        )
        #expect(both[0].appearance == .trainedInApp)
        #expect(both[0].showsPlanDot == false)
        #expect(both[0].accessibilityText == "Segunda, 12, hoje, feito no app e marcado fora do app")
    }

    @Test("The goal: the workouts done out of the planned days, with what is left to close the week")
    func goal() {
        let threeOfFour = WeekSummary.Goal(done: 3, total: 4)
        #expect(threeOfFour.ringText == "3/4")
        #expect(threeOfFour.ringCaption == "treinos")
        #expect(threeOfFour.titleText == "3 de 4 treinos")
        #expect(threeOfFour.remainingText == "Falta 1 para fechar a semana")
        #expect(threeOfFour.progress == 0.75)
        #expect(threeOfFour.isComplete == false)
        #expect(threeOfFour.accessibilityText == "3 de 4 treinos programados feitos")

        let none = WeekSummary.Goal(done: 0, total: 4)
        #expect(none.remainingText == "Faltam 4 para fechar a semana")
        #expect(none.progress == 0)
        #expect(WeekSummary.Goal(done: 2, total: 4).remainingText == "Faltam 2 para fechar a semana")

        let reached = WeekSummary.Goal(done: 4, total: 4)
        #expect(reached.remainingText == "Semana completa")
        #expect(reached.progress == 1)
        #expect(reached.isComplete)

        // Past the goal: the text says so, the ring stops at full.
        let past = WeekSummary.Goal(done: 5, total: 4)
        #expect(past.titleText == "5 de 4 treinos")
        #expect(past.ringText == "5/4")
        #expect(past.remainingText == "Semana completa")
        #expect(past.progress == 1)
        #expect(past.accessibilityText == "5 de 4 treinos programados feitos")

        // A goal of one reads in the singular.
        let single = WeekSummary.Goal(done: 1, total: 1)
        #expect(single.titleText == "1 de 1 treino")
        #expect(single.ringCaption == "treino")
        #expect(single.accessibilityText == "1 de 1 treino programado feito")
        #expect(WeekSummary.Goal(done: 0, total: 1).titleText == "0 de 1 treino")
    }

    @Test("Without a plan the card counts the week's workouts: none, one and more")
    func countTexts() {
        #expect(WeekSummary.workoutsText(0) == "0 treinos esta semana")
        #expect(WeekSummary.workoutsText(1) == "1 treino esta semana")
        #expect(WeekSummary.workoutsText(2) == "2 treinos esta semana")
    }
}
