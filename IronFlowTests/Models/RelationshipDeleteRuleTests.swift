import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// Every check saves first and then reads the store, so it verifies what was persisted.
@MainActor
struct RelationshipDeleteRuleTests {
    @Test("Linking a child fills the inverse relationship")
    func inversesAreMaintained() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let graph = SampleGraph.insert(into: context)
        try context.save()

        #expect(graph.workout.exercises.count == 2)
        #expect(graph.benchPlan.plannedSets.count == 2)
        #expect(graph.workout.sessions.map(\.id) == [graph.session.id])
        #expect(graph.session.exercises.count == 2)
        #expect(graph.benchPerformed.setLogs.count == 2)

        // Appending to the parent's array also sets the child's reference.
        let extra = WorkoutExercise(sortIndex: 2)
        context.insert(extra)
        graph.workout.exercises.append(extra)
        try context.save()
        #expect(extra.workout?.id == graph.workout.id)
    }

    @Test("Ordered lists follow sortIndex, not insertion order")
    func orderFollowsSortIndex() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext

        let workout = Workout(name: "Ordem")
        context.insert(workout)
        for index in [2, 0, 1] {
            let item = WorkoutExercise(sortIndex: index)
            context.insert(item)
            item.workout = workout
            let planned = PlannedSet(sortIndex: 2 - index, weightKg: Double(index), repsMin: 1, repsMax: 1)
            context.insert(planned)
            planned.workoutExercise = item
        }

        let session = Session(startedAt: .now, workoutNameSnapshot: "Ordem")
        context.insert(session)
        for index in [1, 2, 0] {
            let performed = SessionExercise(sortIndex: index, exerciseNameSnapshot: "E\(index)", muscleGroupSnapshot: .other)
            context.insert(performed)
            performed.session = session
            for setIndex in [2, 0, 1] {
                let log = SetLog(sortIndex: setIndex, reps: setIndex)
                context.insert(log)
                log.sessionExercise = performed
            }
        }

        // Equal sortIndex: the earlier createdAt comes first.
        let tieWorkout = Workout(name: "Empate")
        context.insert(tieWorkout)
        let later = WorkoutExercise(sortIndex: 0)
        let earlier = WorkoutExercise(sortIndex: 0)
        later.createdAt = Date(timeIntervalSinceReferenceDate: 2_000)
        earlier.createdAt = Date(timeIntervalSinceReferenceDate: 1_000)
        for item in [later, earlier] {
            context.insert(item)
            item.workout = tieWorkout
        }
        try context.save()

        #expect(workout.orderedExercises.map(\.sortIndex) == [0, 1, 2])
        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["E0", "E1", "E2"])
        for performed in session.orderedExercises {
            #expect(performed.orderedSetLogs.map(\.reps) == [0, 1, 2])
        }
        for item in workout.orderedExercises {
            #expect(item.orderedPlannedSets.map(\.sortIndex) == [2 - item.sortIndex])
        }
        #expect(tieWorkout.orderedExercises.map(\.id) == [earlier.id, later.id])
    }

    @Test("Deleting a workout deletes its plan but keeps the library exercises")
    func deletingWorkoutDeletesPlan() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let graph = SampleGraph.insert(into: context)
        try context.save()

        context.delete(graph.workout)
        try context.save()

        #expect(try count(Workout.self, in: context) == 0)
        #expect(try count(WorkoutExercise.self, in: context) == 0)
        #expect(try count(PlannedSet.self, in: context) == 0)
        #expect(try count(Exercise.self, in: context) == 2)
    }

    @Test("Deleting a workout never deletes its sessions or any history")
    func deletingWorkoutKeepsHistory() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let graph = SampleGraph.insert(into: context)
        try context.save()

        context.delete(graph.workout)
        try context.save()

        #expect(try count(Session.self, in: context) == 1)
        #expect(try count(SessionExercise.self, in: context) == 2)
        #expect(try count(SetLog.self, in: context) == 3)

        let session = try #require(try fetchSession(id: graph.session.id, in: context))
        #expect(session.workout == nil)
        #expect(session.workoutNameSnapshot == "Push")
        #expect(session.orderedExercises.flatMap(\.orderedSetLogs).map(\.isCompleted) == [true, false, true])
    }

    @Test("Deleting a planned exercise deletes only its planned sets")
    func deletingWorkoutExerciseDeletesItsSets() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let graph = SampleGraph.insert(into: context)
        try context.save()

        context.delete(graph.benchPlan)
        try context.save()

        #expect(try count(WorkoutExercise.self, in: context) == 1)
        #expect(try count(PlannedSet.self, in: context) == 1)
        #expect(try count(Workout.self, in: context) == 1)
        #expect(try count(Exercise.self, in: context) == 2)
        #expect(graph.workout.exercises.map(\.id) == [graph.curlPlan.id])
        #expect(graph.benchPress.workoutExercises.isEmpty)
    }

    @Test("Deleting a session deletes only that session's data")
    func deletingSessionDeletesOnlyItsData() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let graph = SampleGraph.insert(into: context)
        let otherSession = Session(startedAt: .now, workoutNameSnapshot: "Push")
        context.insert(otherSession)
        otherSession.workout = graph.workout
        let otherPerformed = SessionExercise(sortIndex: 0, exerciseNameSnapshot: "Supino Reto", muscleGroupSnapshot: .chest)
        context.insert(otherPerformed)
        otherPerformed.session = otherSession
        let otherLog = SetLog(sortIndex: 0)
        context.insert(otherLog)
        otherLog.sessionExercise = otherPerformed
        try context.save()

        context.delete(graph.session)
        try context.save()

        #expect(try count(Session.self, in: context) == 1)
        #expect(try count(SessionExercise.self, in: context) == 1)
        #expect(try count(SetLog.self, in: context) == 1)
        #expect(try count(Workout.self, in: context) == 1)
        #expect(try count(WorkoutExercise.self, in: context) == 2)
        #expect(try count(Exercise.self, in: context) == 2)
        #expect(graph.workout.sessions.map(\.id) == [otherSession.id])
    }

    @Test("Deleting a performed exercise deletes its set logs and keeps the session")
    func deletingSessionExerciseDeletesItsLogs() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let graph = SampleGraph.insert(into: context)
        try context.save()

        context.delete(graph.benchPerformed)
        try context.save()

        #expect(try count(Session.self, in: context) == 1)
        #expect(try count(SessionExercise.self, in: context) == 1)
        #expect(try count(SetLog.self, in: context) == 1)
        #expect(graph.session.exercises.map(\.id) == [graph.curlPerformed.id])
    }

    /// The services (step 0.3) will not delete exercises that have history; this checks
    /// that even if one is deleted, the store itself never removes history with it.
    @Test("Deleting an exercise only clears references and keeps history readable")
    func deletingExerciseKeepsHistory() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let graph = SampleGraph.insert(into: context)
        try context.save()

        context.delete(graph.benchPress)
        try context.save()

        #expect(try count(Exercise.self, in: context) == 1)
        #expect(try count(WorkoutExercise.self, in: context) == 2)
        #expect(try count(PlannedSet.self, in: context) == 3)
        #expect(try count(SessionExercise.self, in: context) == 2)
        #expect(try count(SetLog.self, in: context) == 3)

        #expect(graph.benchPlan.exercise == nil)
        #expect(graph.benchPerformed.exercise == nil)
        #expect(graph.benchPerformed.exerciseNameSnapshot == "Supino Reto")
        #expect(graph.benchPerformed.muscleGroupSnapshot == .chest)
        #expect(graph.benchPerformed.setLogs.count == 2)
    }

    @Test("Renaming the workout or exercise does not change the history snapshots")
    func snapshotsAreIndependent() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let graph = SampleGraph.insert(into: context)
        try context.save()

        graph.workout.name = "Peito e Tríceps"
        graph.benchPress.name = "Supino Reto com Barra"
        graph.benchPress.muscleGroup = .triceps
        try context.save()

        let session = try #require(try fetchSession(id: graph.session.id, in: context))
        #expect(session.workoutNameSnapshot == "Push")
        #expect(session.orderedExercises[0].exerciseNameSnapshot == "Supino Reto")
        #expect(session.orderedExercises[0].muscleGroupSnapshot == .chest)
        #expect(session.orderedExercises[0].exercise?.name == "Supino Reto com Barra")
    }

    @Test("Archiving an exercise keeps all its plan and history links")
    func archivingKeepsLinks() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let graph = SampleGraph.insert(into: context)
        try context.save()

        graph.benchPress.isArchived = true
        try context.save()

        #expect(graph.benchPlan.exercise?.id == graph.benchPress.id)
        #expect(graph.benchPerformed.exercise?.id == graph.benchPress.id)
        #expect(graph.benchPress.workoutExercises.map(\.id) == [graph.benchPlan.id])
        #expect(graph.benchPress.sessionExercises.map(\.id) == [graph.benchPerformed.id])
    }

    @Test("An exercise knows whether it is used in plans and in history")
    func exerciseUsageIsVisible() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let graph = SampleGraph.insert(into: context)
        let unused = Exercise(name: "Elevação Lateral", muscleGroup: .shoulders, isCustom: true)
        context.insert(unused)
        try context.save()

        #expect(graph.benchPress.workoutExercises.count == 1)
        #expect(graph.benchPress.sessionExercises.count == 1)
        #expect(unused.workoutExercises.isEmpty)
        #expect(unused.sessionExercises.isEmpty)
    }
}
