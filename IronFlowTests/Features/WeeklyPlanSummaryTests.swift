import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// The weekly plan screens: the weekday of a date, the seven rows, the count of planned days and what
/// a day whose workout was deleted shows.
@MainActor
struct WeeklyPlanSummaryTests {
    /// A Gregorian calendar whose weeks start on Sunday, like pt_BR's: the weekday of the plan must not
    /// depend on it.
    private func makeCalendar(firstWeekday: Int = 1) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        calendar.locale = Locale(identifier: "pt_BR")
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 12, in calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)))
    }

    private func dayRecord(_ weekday: Int, _ workoutID: UUID, createdAt: Date? = nil) -> WeeklyPlanDay {
        let record = WeeklyPlanDay(weekday: weekday, workoutID: workoutID)
        if let createdAt {
            record.createdAt = createdAt
        }
        return record
    }

    @Test("The plan's weekday goes from 1 on Monday to 7 on Sunday, whatever the calendar's first weekday")
    func weekdayMapping() throws {
        // 12 to 18 October 2026 is Monday to Sunday.
        for firstWeekday in [1, 2] {
            let calendar = try makeCalendar(firstWeekday: firstWeekday)
            for (offset, day) in (12...18).enumerated() {
                let moment = try date(day, in: calendar)
                #expect(TrainingDay.planWeekday(of: moment, calendar: calendar) == offset + 1)
            }
        }

        let calendar = try makeCalendar()
        // The first and the last minute of a day belong to it.
        let mondayStart = try date(12, 0, in: calendar)
        let sundayLastMinute = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 23, minute: 59)))
        #expect(TrainingDay.planWeekday(of: mondayStart, calendar: calendar) == 1)
        #expect(TrainingDay.planWeekday(of: sundayLastMinute, calendar: calendar) == 7)
        #expect(TrainingDay.planWeekdays == 1...7)
    }

    @Test("A day's interval runs from its start to the start of the next day")
    func dayInterval() throws {
        let calendar = try makeCalendar()
        let afternoon = try date(14, 15, in: calendar)
        let start = try date(14, 0, in: calendar)
        let nextStart = try date(15, 0, in: calendar)

        let interval = TrainingDay.dayInterval(of: afternoon, calendar: calendar)

        #expect(interval.start == start)
        #expect(interval.end == nextStart)
    }

    @Test("There is a row for each day, Monday to Sunday, with the planned workout, a rest day and today")
    func rows() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let push = Workout(name: "Push")
        let pull = Workout(name: "Pull")
        context.insert(push)
        context.insert(pull)
        // Monday and Sunday: Push, Wednesday: Pull; the other days rest.
        let plan = [dayRecord(1, push.id), dayRecord(3, pull.id), dayRecord(7, push.id)]
        for record in plan {
            context.insert(record)
        }
        try context.save()

        let rows = WeeklyPlanSummary.rows(plan: plan, workouts: [push, pull], todayWeekday: 3)

        #expect(rows.map(\.weekday) == [1, 2, 3, 4, 5, 6, 7])
        #expect(rows.map(\.dayName) == ["Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado", "Domingo"])
        #expect(rows.map(\.workoutName) == ["Push", nil, "Pull", nil, nil, nil, "Push"])
        #expect(rows.map(\.workoutID) == [push.id, nil, pull.id, nil, nil, nil, push.id])
        #expect(rows.map(\.isToday) == [false, false, true, false, false, false, false])
        #expect(rows.map(\.choiceText) == ["Push", "Descanso", "Pull", "Descanso", "Descanso", "Descanso", "Push"])

        // VoiceOver: the day and the choice, and "hoje" for today.
        #expect(rows[0].accessibilityText == "segunda-feira, Push")
        #expect(rows[1].accessibilityText == "terça-feira, descanso")
        #expect(rows[2].accessibilityText == "quarta-feira, hoje, Pull")
        #expect(rows[6].accessibilityText == "domingo, Push")
        let restToday = WeeklyPlanSummary.rows(plan: plan, workouts: [push, pull], todayWeekday: 4)[3]
        #expect(restToday.accessibilityText == "quinta-feira, hoje, descanso")
    }

    @Test("A day whose workout no longer exists is a rest day and is not counted")
    func deletedWorkoutIsARestDay() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let push = Workout(name: "Push")
        context.insert(push)
        let deleted = UUID()
        let plan = [dayRecord(1, push.id), dayRecord(2, deleted)]
        for record in plan {
            context.insert(record)
        }
        try context.save()

        let rows = WeeklyPlanSummary.rows(plan: plan, workouts: [push], todayWeekday: 2)

        #expect(rows[1].workoutID == nil)
        #expect(rows[1].workoutName == nil)
        #expect(rows[1].accessibilityText == "terça-feira, hoje, descanso")
        #expect(WeeklyPlanSummary.plannedDayCount(plan: plan, workouts: [push]) == 1)
        // The record still names the workout; whether it exists is known by whoever looks it up.
        #expect(WeeklyPlanSummary.scheduledWorkoutID(plan: plan, weekday: 2) == deleted)
        #expect(WeeklyPlanSummary.workoutsByWeekday(plan: plan, workouts: [push]).keys.sorted() == [1])
    }

    @Test("A weekday with more than one record uses the oldest, and the same workout can be on several days")
    func oldestRecordAndRepeatedWorkout() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let push = Workout(name: "Push")
        let pull = Workout(name: "Pull")
        context.insert(push)
        context.insert(pull)
        let early = Date(timeIntervalSinceReferenceDate: 1_000)
        let late = Date(timeIntervalSinceReferenceDate: 2_000)
        for plan in [[dayRecord(2, push.id, createdAt: early), dayRecord(2, pull.id, createdAt: late)],
                     [dayRecord(2, pull.id, createdAt: late), dayRecord(2, push.id, createdAt: early)]] {
            #expect(WeeklyPlanSummary.scheduledWorkoutID(plan: plan, weekday: 2) == push.id)
            #expect(WeeklyPlanSummary.workoutsByWeekday(plan: plan, workouts: [push, pull])[2]?.name == "Push")
        }

        let plan = [dayRecord(1, push.id), dayRecord(3, push.id), dayRecord(5, push.id)]
        #expect(WeeklyPlanSummary.workoutsByWeekday(plan: plan, workouts: [push]).keys.sorted() == [1, 3, 5])
        #expect(WeeklyPlanSummary.plannedDayCount(plan: plan, workouts: [push]) == 3)
        #expect(WeeklyPlanSummary.plannedWeekdays(plan: plan, workouts: [push]) == [1, 3, 5])
    }

    @Test("The planned weekdays leave out a day whose workout no longer exists")
    func plannedWeekdays() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let push = Workout(name: "Push")
        context.insert(push)
        let plan = [dayRecord(1, push.id), dayRecord(4, UUID()), dayRecord(7, push.id)]

        #expect(WeeklyPlanSummary.plannedWeekdays(plan: plan, workouts: [push]) == [1, 7])
        #expect(WeeklyPlanSummary.plannedWeekdays(plan: [], workouts: [push]).isEmpty)
    }

    @Test("The short count of the Treinos row: none, one and several days")
    func dayCountText() {
        #expect(WeeklyPlanSummary.dayCountText(0) == "Nenhum dia")
        #expect(WeeklyPlanSummary.dayCountText(1) == "1 dia")
        #expect(WeeklyPlanSummary.dayCountText(4) == "4 dias")
        #expect(WeeklyPlanSummary.dayCountText(7) == "7 dias")
    }

    @Test("The summary of the plan: none, one and several planned days")
    func summaryText() {
        #expect(WeeklyPlanSummary.summaryText(0) == "Nenhum dia programado")
        #expect(WeeklyPlanSummary.summaryText(1) == "1 dia programado")
        #expect(WeeklyPlanSummary.summaryText(3) == "3 dias programados")
        #expect(WeeklyPlanSummary.summaryText(7) == "7 dias programados")
    }
}
