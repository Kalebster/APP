import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// What the Home "Treino de hoje" card shows with the weekly plan: the order of its states, when a
/// workout counts as finished today and what happens when the day changes.
@MainActor
struct TodayWorkoutStateTests {
    private func makeCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        calendar.locale = Locale(identifier: "pt_BR")
        calendar.firstWeekday = 1
        return calendar
    }

    /// A moment of October 2026 (the 13th is a Tuesday).
    private func moment(_ day: Int, _ hour: Int, _ minute: Int = 0, in calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)))
    }

    /// A session that started at `start`, finished an hour later unless it is in progress.
    private func session(of workout: Workout?, startedAt start: Date, inProgress: Bool = false, in context: ModelContext) -> Session {
        let session = Session(startedAt: start, workoutNameSnapshot: workout?.name ?? "")
        if !inProgress {
            session.endedAt = start.addingTimeInterval(3_600)
        }
        context.insert(session)
        session.workout = workout
        return session
    }

    @Test("The states in order: in progress, planned for today, finished today, nothing planned")
    func priority() throws {
        let calendar = try makeCalendar()
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let push = Workout(name: "Push")
        context.insert(push)
        let now = try moment(13, 18, in: calendar)
        let running = session(of: nil, startedAt: try moment(13, 17, in: calendar), inProgress: true, in: context)
        let finished = session(of: push, startedAt: try moment(13, 8, in: calendar), in: context)
        try context.save()

        // A session in progress comes before everything.
        #expect(TodayWorkoutState.resolve(activeSessions: [running], hasWorkouts: true, scheduled: push, finishedSessions: [finished], now: now, calendar: calendar)
            == .inProgress(name: "", startedAt: running.startedAt))
        // Then the workout planned for today.
        #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: true, scheduled: push, finishedSessions: [], now: now, calendar: calendar)
            == .scheduled(workoutID: push.id, name: "Push"))
        // Finished today.
        #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: true, scheduled: push, finishedSessions: [finished], now: now, calendar: calendar)
            == .scheduledCompleted(name: "Push", duration: 3_600))
        // Nothing planned for today: as before the weekly plan.
        #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: true, scheduled: nil, finishedSessions: [finished], now: now, calendar: calendar)
            == .nothingPlanned)
        #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: false, scheduled: nil, now: now, calendar: calendar)
            == .noWorkouts)
    }

    @Test("Only a finished session of the planned workout that started today finishes it")
    func whatCountsAsFinishedToday() throws {
        let calendar = try makeCalendar()
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let push = Workout(name: "Push")
        let pull = Workout(name: "Pull")
        context.insert(push)
        context.insert(pull)
        let now = try moment(13, 18, in: calendar)
        let scheduled = TodayWorkoutState.scheduled(workoutID: push.id, name: "Push")

        let otherWorkout = session(of: pull, startedAt: try moment(13, 8, in: calendar), in: context)
        let freeWorkout = session(of: nil, startedAt: try moment(13, 9, in: calendar), in: context)
        let yesterday = session(of: push, startedAt: try moment(12, 20, in: calendar), in: context)
        let unfinished = session(of: push, startedAt: try moment(13, 10, in: calendar), inProgress: true, in: context)
        try context.save()

        for notCounted in [otherWorkout, freeWorkout, yesterday, unfinished] {
            #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: true, scheduled: push, finishedSessions: [notCounted], now: now, calendar: calendar) == scheduled)
        }

        // The first minute of the day and a session that ends after midnight both count, by their start.
        let midnight = session(of: push, startedAt: try moment(13, 0, in: calendar), in: context)
        let lateNight = session(of: push, startedAt: try moment(13, 23, 30, in: calendar), in: context)
        try context.save()
        for counted in [midnight, lateNight] {
            #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: true, scheduled: push, finishedSessions: [otherWorkout, counted], now: now, calendar: calendar)
                == .scheduledCompleted(name: "Push", duration: 3_600))
        }
    }

    @Test("Finished twice today, the block shows the duration of the latest session")
    func durationOfTheLatestSession() throws {
        let calendar = try makeCalendar()
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let push = Workout(name: "Push")
        context.insert(push)
        let morning = session(of: push, startedAt: try moment(13, 7, in: calendar), in: context)
        let evening = session(of: push, startedAt: try moment(13, 17, in: calendar), in: context)
        evening.endedAt = try moment(13, 17, 55, in: calendar)
        try context.save()

        for sessions in [[morning, evening], [evening, morning]] {
            #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: true, scheduled: push, finishedSessions: sessions, now: try moment(13, 20, in: calendar), calendar: calendar)
                == .scheduledCompleted(name: "Push", duration: 55 * 60))
        }
    }

    @Test("A planned workout that was deleted is no longer planned: the day is a rest day")
    func deletedPlannedWorkout() throws {
        let calendar = try makeCalendar()
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let push = Workout(name: "Push")
        context.insert(push)
        let tuesday = try moment(13, 12, in: calendar)
        let weekday = TrainingDay.planWeekday(of: tuesday, calendar: calendar)
        context.insert(WeeklyPlanDay(weekday: weekday, workoutID: push.id))
        try context.save()

        // Deleted without going through the service, so the record is left behind.
        context.delete(push)
        try context.save()

        let plan = try context.fetch(FetchDescriptor<WeeklyPlanDay>())
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(plan.count == 1)
        let scheduled = WeeklyPlanSummary.workoutsByWeekday(plan: plan, workouts: workouts)[weekday]
        #expect(scheduled == nil)
        #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: false, scheduled: scheduled, now: tuesday, calendar: calendar) == .noWorkouts)
        // With other workouts left, the card is the one of a day with nothing planned.
        #expect(TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: true, scheduled: scheduled, now: tuesday, calendar: calendar) == .nothingPlanned)
    }

    @Test("Each day of the week finds its own planned workout, Monday to Sunday")
    func eachWeekdayFindsItsWorkout() throws {
        let calendar = try makeCalendar()
        // One workout id per weekday, in the order Monday to Sunday.
        let ids = (1...7).map { _ in UUID() }
        let plan = ids.enumerated().map { WeeklyPlanDay(weekday: $0.offset + 1, workoutID: $0.element) }

        // 12 to 18 October 2026 is Monday to Sunday.
        for (offset, day) in (12...18).enumerated() {
            let noon = try moment(day, 12, in: calendar)
            let weekday = TrainingDay.planWeekday(of: noon, calendar: calendar)
            #expect(WeeklyPlanSummary.scheduledWorkoutID(plan: plan, weekday: weekday) == ids[offset])
        }
    }

    @Test("When the day changes the plan of the new day applies, and yesterday's workout is not finished today")
    func dayTurn() throws {
        let calendar = try makeCalendar()
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let push = Workout(name: "Push")
        let pull = Workout(name: "Pull")
        context.insert(push)
        context.insert(pull)
        // Tuesday and Wednesday: Push. Thursday: Pull.
        let plan = [WeeklyPlanDay(weekday: 2, workoutID: push.id), WeeklyPlanDay(weekday: 3, workoutID: push.id), WeeklyPlanDay(weekday: 4, workoutID: pull.id)]
        let doneTuesday = session(of: push, startedAt: try moment(13, 20, in: calendar), in: context)
        try context.save()
        let workouts = [push, pull]

        func state(at now: Date) -> TodayWorkoutState {
            let weekday = TrainingDay.planWeekday(of: now, calendar: calendar)
            let scheduledID = WeeklyPlanSummary.scheduledWorkoutID(plan: plan, weekday: weekday)
            let scheduled = workouts.first { $0.id == scheduledID }
            return TodayWorkoutState.resolve(activeSessions: [], hasWorkouts: true, scheduled: scheduled, finishedSessions: [doneTuesday], now: now, calendar: calendar)
        }

        // Tuesday evening: Push was done today.
        #expect(state(at: try moment(13, 23, 59, in: calendar)) == .scheduledCompleted(name: "Push", duration: 3_600))
        // A minute later it is Wednesday: Push is planned again and not done yet.
        #expect(state(at: try moment(14, 0, in: calendar)) == .scheduled(workoutID: push.id, name: "Push"))
        // Thursday: the plan names Pull.
        #expect(state(at: try moment(15, 9, in: calendar)) == .scheduled(workoutID: pull.id, name: "Pull"))
        // Friday: nothing planned.
        #expect(state(at: try moment(16, 9, in: calendar)) == .nothingPlanned)
    }
}
