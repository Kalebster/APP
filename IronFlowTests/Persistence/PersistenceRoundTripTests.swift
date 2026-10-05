import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// Writes to disk, reopens the store with a new container and checks what was really stored.
@MainActor
struct PersistenceRoundTripTests {
    @Test("Complete graph survives closing and reopening the store")
    func completeGraphSurvivesReopening() throws {
        var sessionID = UUID()

        try roundTripThroughDisk { context in
            sessionID = SampleGraph.insert(into: context).session.id
        } read: { context in
            #expect(try count(Exercise.self, in: context) == 2)
            #expect(try count(Workout.self, in: context) == 1)
            #expect(try count(WorkoutExercise.self, in: context) == 2)
            #expect(try count(PlannedSet.self, in: context) == 3)
            #expect(try count(Session.self, in: context) == 1)
            #expect(try count(SessionExercise.self, in: context) == 2)
            #expect(try count(SetLog.self, in: context) == 3)

            // Plan
            let workout = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
            #expect(workout.name == "Push")
            let plan = workout.orderedExercises
            #expect(plan.map { $0.exercise?.name } == ["Supino Reto", "Rosca Direta"])
            let benchSets = plan[0].orderedPlannedSets
            #expect(benchSets.map(\.weightKg) == [20, 22.25])
            #expect(benchSets.map(\.repsMin) == [8, 6])
            #expect(benchSets.map(\.repsMax) == [10, 8])
            #expect(plan[1].orderedPlannedSets.map(\.weightKg) == [nil])

            // Library
            let bench = try #require(plan[0].exercise)
            #expect(bench.muscleGroup == .chest)
            #expect(bench.isCustom == false)
            #expect(bench.isArchived == false)
            #expect(bench.libraryKey == "bench-press")
            let curl = try #require(plan[1].exercise)
            #expect(curl.isCustom == true)
            #expect(curl.libraryKey == nil)

            // History
            let session = try #require(try fetchSession(id: sessionID, in: context))
            #expect(session.workout?.id == workout.id)
            #expect(session.workoutNameSnapshot == "Push")
            #expect(abs(session.startedAt.timeIntervalSince(SampleGraph.sessionStart)) < 0.001)
            let duration = try #require(session.duration)
            #expect(abs(duration - 3_600) < 0.001)
            #expect(session.isActive == false)

            let performed = session.orderedExercises
            #expect(performed.map(\.exerciseNameSnapshot) == ["Supino Reto", "Rosca Direta"])
            #expect(performed.map(\.muscleGroupSnapshot) == [.chest, .biceps])
            #expect(performed[0].exercise?.id == bench.id)

            let benchLogs = performed[0].orderedSetLogs
            #expect(benchLogs.count == 2)
            let completed = benchLogs[0]
            #expect(completed.isCompleted == true)
            let completedAt = try #require(completed.completedAt)
            #expect(abs(completedAt.timeIntervalSince(SampleGraph.completedAt)) < 0.001)
            #expect(completed.weightKg == 20)
            #expect(completed.reps == 10)
            #expect(completed.targetWeightKg == 20)
            #expect(completed.targetRepsMin == 8)
            #expect(completed.targetRepsMax == 10)

            // A set that was not done stays recorded as not done.
            let notCompleted = benchLogs[1]
            #expect(notCompleted.isCompleted == false)
            #expect(notCompleted.completedAt == nil)
            #expect(notCompleted.weightKg == nil)
            #expect(notCompleted.reps == nil)
            #expect(notCompleted.targetWeightKg == 22.25)
            #expect(notCompleted.targetRepsMin == 6)
            #expect(notCompleted.targetRepsMax == 8)

            let curlLog = try #require(performed[1].orderedSetLogs.first)
            #expect(curlLog.weightKg == nil)
            #expect(curlLog.reps == 12)
        }
    }

    @Test("Deleting a workout keeps its session history after reopening the store")
    func deletingWorkoutKeepsHistoryOnDisk() throws {
        var sessionID = UUID()

        try roundTripThroughDisk { context in
            let graph = SampleGraph.insert(into: context)
            sessionID = graph.session.id
            try context.save()
            context.delete(graph.workout)
        } read: { context in
            #expect(try count(Workout.self, in: context) == 0)
            #expect(try count(WorkoutExercise.self, in: context) == 0)
            #expect(try count(PlannedSet.self, in: context) == 0)

            #expect(try count(Session.self, in: context) == 1)
            #expect(try count(SessionExercise.self, in: context) == 2)
            #expect(try count(SetLog.self, in: context) == 3)
            #expect(try count(Exercise.self, in: context) == 2)

            let session = try #require(try fetchSession(id: sessionID, in: context))
            #expect(session.workout == nil)
            #expect(session.workoutNameSnapshot == "Push")
            #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Supino Reto", "Rosca Direta"])
        }
    }

    @Test("Open session and its timestamps survive reopening the store")
    func activeSessionAndTimestampsSurviveReopening() throws {
        let startedAt = Date(timeIntervalSinceReferenceDate: 800_000_123.456)
        var sessionID = UUID()
        var createdAt = Date.distantPast
        var updatedAt = Date.distantPast

        try roundTripThroughDisk { context in
            let session = Session(startedAt: startedAt, workoutNameSnapshot: "Pull")
            context.insert(session)
            sessionID = session.id
            createdAt = session.createdAt
            updatedAt = session.updatedAt
        } read: { context in
            let session = try #require(try fetchSession(id: sessionID, in: context))
            #expect(session.isActive)
            #expect(session.endedAt == nil)
            #expect(session.duration == nil)
            #expect(abs(session.startedAt.timeIntervalSince(startedAt)) < 0.001)
            #expect(abs(session.createdAt.timeIntervalSince(createdAt)) < 0.001)
            #expect(abs(session.updatedAt.timeIntervalSince(updatedAt)) < 0.001)
        }
    }
}
