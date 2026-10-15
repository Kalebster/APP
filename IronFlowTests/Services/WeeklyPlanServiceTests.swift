import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// Planning a workout for a day of the week, and making a day a rest day.
@MainActor
struct WeeklyPlanServiceTests {
    let harness: ServiceTestHarness
    let service: WeeklyPlanService
    let push: Workout
    let pull: Workout

    init() throws {
        harness = try ServiceTestHarness()
        service = WeeklyPlanService(context: harness.context, now: harness.clock.now)
        push = try harness.workouts.createWorkout(name: "Push")
        pull = try harness.workouts.createWorkout(name: "Pull")
        harness.clock.advance(by: 60)
    }

    /// Every stored day of the plan, Monday first.
    private func stored() throws -> [WeeklyPlanDay] {
        try harness.context.fetch(FetchDescriptor<WeeklyPlanDay>()).sorted { $0.weekday < $1.weekday }
    }

    @Test("Planning a workout for a day stores the weekday and the workout, with the time of the change")
    func setWorkout() throws {
        let record = try service.setWorkout(push, for: 1)

        #expect(record.weekday == 1)
        #expect(record.workoutID == push.id)
        #expect(record.createdAt == harness.clock.current)
        #expect(record.updatedAt == harness.clock.current)
        #expect(try stored().map(\.weekday) == [1])
    }

    @Test("Planning another workout for a day replaces the first; the same workout can be on several days")
    func replaceAndRepeat() throws {
        let created = harness.clock.current
        let first = try service.setWorkout(push, for: 3)
        harness.clock.advance(by: 60)

        let second = try service.setWorkout(pull, for: 3)

        // The same record: one per day.
        #expect(second.id == first.id)
        #expect(second.workoutID == pull.id)
        #expect(second.createdAt == created)
        #expect(second.updatedAt == harness.clock.current)
        #expect(try stored().map(\.workoutID) == [pull.id])

        try service.setWorkout(pull, for: 1)
        try service.setWorkout(pull, for: 5)
        #expect(try stored().map(\.weekday) == [1, 3, 5])
        #expect(try stored().map(\.workoutID) == [pull.id, pull.id, pull.id])
    }

    @Test("Planning the workout a day already has changes nothing")
    func sameWorkoutAgain() throws {
        let record = try service.setWorkout(push, for: 2)
        let planned = record.updatedAt
        harness.clock.advance(by: 60)

        try service.setWorkout(push, for: 2)

        #expect(record.updatedAt == planned)
        #expect(harness.context.hasChanges == false)
        #expect(try stored().count == 1)
    }

    @Test("A rest day has no record; clearing a day leaves the others, and a day without a workout as it is")
    func clear() throws {
        try service.setWorkout(push, for: 1)
        try service.setWorkout(pull, for: 3)

        try service.clear(weekday: 1)
        #expect(try stored().map(\.weekday) == [3])

        try service.clear(weekday: 1)
        #expect(try stored().map(\.weekday) == [3])
        #expect(try stored().map(\.workoutID) == [pull.id])
        #expect(harness.context.hasChanges == false)
    }

    @Test("A day holds one record: extra records of the day are removed, the oldest is kept")
    func oneRecordPerDay() throws {
        // Records the service never creates, as an error or a future sync could leave them.
        let older = WeeklyPlanDay(weekday: 5, workoutID: push.id)
        older.createdAt = harness.clock.current.addingTimeInterval(-120)
        let newer = WeeklyPlanDay(weekday: 5, workoutID: pull.id)
        newer.createdAt = harness.clock.current.addingTimeInterval(-60)
        harness.context.insert(older)
        harness.context.insert(newer)
        try harness.context.save()

        let kept = try service.setWorkout(pull, for: 5)

        #expect(kept.id == older.id)
        #expect(try stored().map(\.id) == [older.id])
        #expect(try stored().map(\.workoutID) == [pull.id])

        // Clearing a day removes every record it has.
        let extra = WeeklyPlanDay(weekday: 5, workoutID: push.id)
        harness.context.insert(extra)
        try harness.context.save()
        try service.clear(weekday: 5)
        #expect(try stored().isEmpty)
    }

    @Test("A weekday outside 1 to 7 is refused and nothing is changed")
    func invalidWeekday() throws {
        try service.setWorkout(push, for: 4)

        for weekday in [0, 8, -1] {
            #expect(throws: WeeklyPlanError.invalidWeekday) { try service.setWorkout(pull, for: weekday) }
            #expect(throws: WeeklyPlanError.invalidWeekday) { try service.clear(weekday: weekday) }
        }

        #expect(try stored().map(\.weekday) == [4])
        #expect(try stored().map(\.workoutID) == [push.id])
        #expect(harness.context.hasChanges == false)
    }

    @Test("The plan stays after the store is closed and opened again")
    func planSurvivesReopening() throws {
        var workoutID = UUID()
        try roundTripThroughDisk(
            write: { context in
                let workout = try WorkoutService(context: context).createWorkout(name: "Push")
                workoutID = workout.id
                let planner = WeeklyPlanService(context: context)
                try planner.setWorkout(workout, for: 3)
                try planner.setWorkout(workout, for: 7)
            },
            read: { context in
                let days = try context.fetch(FetchDescriptor<WeeklyPlanDay>()).sorted { $0.weekday < $1.weekday }
                #expect(days.map(\.weekday) == [3, 7])
                #expect(days.map(\.workoutID) == [workoutID, workoutID])
            }
        )
    }

    @Test("Deleting a workout removes its days from the plan and leaves the days of the other workouts")
    func deletingWorkoutClearsItsDays() throws {
        try service.setWorkout(push, for: 1)
        try service.setWorkout(pull, for: 2)
        try service.setWorkout(push, for: 3)
        let remaining = pull.id

        try harness.workouts.delete(push)

        #expect(try stored().map(\.weekday) == [2])
        #expect(try stored().map(\.workoutID) == [remaining])
        #expect(try count(Workout.self, in: harness.context) == 1)
        #expect(harness.context.hasChanges == false)
    }
}
