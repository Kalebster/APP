import Foundation
import SwiftData
import Testing
@testable import IronFlow

@MainActor
struct WorkoutServiceTests {
    let harness: ServiceTestHarness
    let bench: Exercise
    let row: Exercise
    let squat: Exercise

    init() throws {
        harness = try ServiceTestHarness()
        bench = try harness.exercises.createCustomExercise(name: "Supino", muscleGroup: .chest)
        row = try harness.exercises.createCustomExercise(name: "Remada", muscleGroup: .back)
        squat = try harness.exercises.createCustomExercise(name: "Agachamento", muscleGroup: .quadriceps)
    }

    private func sortIndexes(of workout: Workout) -> [Int] {
        workout.orderedExercises.map(\.sortIndex)
    }

    private func sortIndexes(of item: WorkoutExercise) -> [Int] {
        item.orderedPlannedSets.map(\.sortIndex)
    }

    // MARK: - Workout

    @Test("Create and rename validate the name and keep createdAt")
    func createAndRename() throws {
        let workout = try harness.workouts.createWorkout(name: "  Push ")
        #expect(workout.name == "Push")
        #expect(workout.createdAt == harness.clock.current)
        let createdAt = workout.createdAt

        harness.clock.advance(by: 60)
        try harness.workouts.rename(workout, to: "Peito e Tríceps")
        #expect(workout.name == "Peito e Tríceps")
        #expect(workout.createdAt == createdAt)
        #expect(workout.updatedAt == harness.clock.current)

        #expect(throws: ValidationError.emptyName) { try harness.workouts.rename(workout, to: " ") }
        #expect(throws: ValidationError.emptyName) { try harness.workouts.createWorkout(name: "") }
        #expect(workout.name == "Peito e Tríceps")
        #expect(try count(Workout.self, in: harness.context) == 1)
    }

    @Test("Workouts may share a name")
    func duplicateWorkoutNamesAllowed() throws {
        try harness.workouts.createWorkout(name: "Push")
        try harness.workouts.createWorkout(name: "push")
        #expect(try count(Workout.self, in: harness.context) == 2)
    }

    @Test("Renaming a workout does not change the name stored in its sessions")
    func renameKeepsSessionSnapshot() throws {
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10)])])
        let session = try harness.sessions.startSession(from: workout)

        try harness.workouts.rename(workout, to: "Push A")
        #expect(session.workoutNameSnapshot == "Push")
    }

    // MARK: - Exercises

    @Test("Adding to an empty workout starts at the first position")
    func addExercisesToEmptyWorkout() throws {
        let workout = try harness.workouts.createWorkout(name: "Push")
        harness.clock.advance(by: 10)

        let items = try harness.workouts.addExercises([bench], to: workout)

        let item = try #require(items.first)
        #expect(items.count == 1)
        #expect(workout.orderedExercises.map(\.id) == [item.id])
        #expect(item.sortIndex == 0)
        #expect(item.exercise?.id == bench.id)
        #expect(item.plannedSets.count == WorkoutService.defaultPlannedSets.count)
        #expect(item.plannedSets.allSatisfy { $0.createdAt == harness.clock.current })
        #expect(item.createdAt == harness.clock.current)
        #expect(workout.updatedAt == harness.clock.current)
        #expect(harness.context.hasChanges == false)
    }

    @Test("The default planned sets are 3 valid sets of 8–12 reps without load")
    func defaultPlannedSetsAreValid() throws {
        #expect(WorkoutService.defaultPlannedSets == Array(repeating: .reps(8, 12), count: 3))
        for values in WorkoutService.defaultPlannedSets {
            try values.validate()
        }
    }

    @Test("Removing an exercise from the middle renumbers the rest")
    func removeExercise() throws {
        let workout = try harness.makeWorkout(name: "Full", items: [
            (bench, [.reps(8, 10), .reps(8, 10)]), (row, [.reps(8, 10)]), (squat, [.reps(5, 5)]),
        ])
        let middle = workout.orderedExercises[1]

        try harness.workouts.removeExercise(middle)

        #expect(workout.orderedExercises.map { $0.exercise?.id } == [bench.id, squat.id])
        #expect(sortIndexes(of: workout) == [0, 1])
        #expect(try count(PlannedSet.self, in: harness.context) == 3)
        #expect(try count(Exercise.self, in: harness.context) == 3)
    }

    @Test("Moving exercises to the start, end and middle keeps indexes 0...n-1")
    func moveExercises() throws {
        let workout = try harness.makeWorkout(name: "Full", items: [
            (bench, [.reps(8, 10)]), (row, [.reps(8, 10)]), (squat, [.reps(5, 5)]),
        ])
        func order() -> [UUID?] { workout.orderedExercises.map { $0.exercise?.id } }

        try harness.workouts.moveExercises(in: workout, fromOffsets: [2], toOffset: 0)
        #expect(order() == [squat.id, bench.id, row.id])
        try harness.workouts.moveExercises(in: workout, fromOffsets: [0], toOffset: 3)
        #expect(order() == [bench.id, row.id, squat.id])
        try harness.workouts.moveExercises(in: workout, fromOffsets: [0], toOffset: 2)
        #expect(order() == [row.id, bench.id, squat.id])
        #expect(sortIndexes(of: workout) == [0, 1, 2])
    }

    @Test("Moving with an invalid position fails and changes nothing")
    func moveExercisesInvalid() throws {
        let workout = try harness.makeWorkout(name: "Full", items: [(bench, [.reps(8, 10)]), (row, [.reps(8, 10)])])

        #expect(throws: WorkoutError.invalidPosition) {
            try harness.workouts.moveExercises(in: workout, fromOffsets: [5], toOffset: 0)
        }
        #expect(throws: WorkoutError.invalidPosition) {
            try harness.workouts.moveExercises(in: workout, fromOffsets: [0], toOffset: 3)
        }
        #expect(throws: WorkoutError.invalidPosition) {
            try harness.workouts.moveExercises(in: workout, fromOffsets: [], toOffset: 0)
        }
        #expect(workout.orderedExercises.map { $0.exercise?.id } == [bench.id, row.id])
        #expect(harness.context.hasChanges == false)
    }

    // MARK: - Adding from the picker

    @Test("Adding exercises appends them in order, each with 3 sets of 8–12 reps and no load")
    func addExercisesDefaultSets() throws {
        let workout = try harness.makeWorkout(name: "Full", items: [(squat, [.reps(5, 5)])])
        harness.clock.advance(by: 10)

        let items = try harness.workouts.addExercises([bench, row], to: workout)

        #expect(workout.orderedExercises.map { $0.exercise?.id } == [squat.id, bench.id, row.id])
        #expect(items.map(\.id) == Array(workout.orderedExercises.dropFirst()).map(\.id))
        #expect(sortIndexes(of: workout) == [0, 1, 2])
        for item in items {
            #expect(sortIndexes(of: item) == [0, 1, 2])
            #expect(item.orderedPlannedSets.allSatisfy { $0.repsMin == 8 && $0.repsMax == 12 && $0.weightKg == nil })
            #expect(item.createdAt == harness.clock.current)
        }
        #expect(workout.updatedAt == harness.clock.current)
        #expect(harness.context.hasChanges == false)
    }

    @Test("An exercise already in the workout cannot be added again, and nothing is added")
    func addExercisesAlreadyInWorkout() throws {
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10)])])
        let before = try storeCounts(in: harness.context)

        #expect(throws: WorkoutError.exerciseAlreadyInWorkout) {
            try harness.workouts.addExercises([row, bench], to: workout)
        }
        #expect(try storeCounts(in: harness.context) == before)
        #expect(workout.orderedExercises.map { $0.exercise?.id } == [bench.id])
        #expect(harness.context.hasChanges == false)
    }

    @Test("The same exercise chosen twice in one request is rejected, and nothing is added")
    func addExercisesRepeatedInRequest() throws {
        let workout = try harness.workouts.createWorkout(name: "Push")
        let before = try storeCounts(in: harness.context)

        #expect(throws: WorkoutError.exerciseAlreadyInWorkout) {
            try harness.workouts.addExercises([bench, row, bench], to: workout)
        }
        #expect(try storeCounts(in: harness.context) == before)
        #expect(workout.exercises.isEmpty)
    }

    @Test("An archived exercise cannot be added, alone or anywhere in the request, and nothing is added")
    func addExercisesArchived() throws {
        let workout = try harness.workouts.createWorkout(name: "Push")
        try harness.exercises.archive(row)
        let before = try storeCounts(in: harness.context)

        #expect(throws: WorkoutError.exerciseArchived) {
            try harness.workouts.addExercises([row], to: workout)
        }
        #expect(throws: WorkoutError.exerciseArchived) {
            try harness.workouts.addExercises([bench, row], to: workout)
        }
        #expect(try storeCounts(in: harness.context) == before)
        #expect(workout.exercises.isEmpty)
        #expect(harness.context.hasChanges == false)
    }

    @Test("After reordering and removing others, an exercise still in the workout cannot be added again")
    func duplicateCheckFollowsPlanChanges() throws {
        let workout = try harness.workouts.createWorkout(name: "Full")
        try harness.workouts.addExercises([bench, row, squat], to: workout)
        try harness.workouts.moveExercises(in: workout, fromOffsets: [0], toOffset: 3)
        try harness.workouts.removeExercise(workout.orderedExercises[0])
        #expect(workout.orderedExercises.map { $0.exercise?.id } == [squat.id, bench.id])
        let before = try storeCounts(in: harness.context)

        #expect(throws: WorkoutError.exerciseAlreadyInWorkout) {
            try harness.workouts.addExercises([bench], to: workout)
        }
        // The removed exercise alone could be added, but not together with one still in the workout.
        #expect(throws: WorkoutError.exerciseAlreadyInWorkout) {
            try harness.workouts.addExercises([row, squat], to: workout)
        }
        #expect(try storeCounts(in: harness.context) == before)
        #expect(workout.orderedExercises.map { $0.exercise?.id } == [squat.id, bench.id])
        #expect(harness.context.hasChanges == false)
    }

    @Test("The same exercise can be in different workouts")
    func sameExerciseInDifferentWorkouts() throws {
        let push = try harness.workouts.createWorkout(name: "Push")
        let full = try harness.workouts.createWorkout(name: "Full")

        try harness.workouts.addExercises([bench], to: push)
        try harness.workouts.addExercises([bench, row], to: full)

        #expect(push.orderedExercises.map { $0.exercise?.id } == [bench.id])
        #expect(full.orderedExercises.map { $0.exercise?.id } == [bench.id, row.id])
    }

    @Test("Adding no exercises changes nothing")
    func addExercisesEmpty() throws {
        let workout = try harness.workouts.createWorkout(name: "Push")
        let updatedAt = workout.updatedAt
        harness.clock.advance(by: 10)

        #expect(try harness.workouts.addExercises([], to: workout).isEmpty)
        #expect(workout.updatedAt == updatedAt)
        #expect(harness.context.hasChanges == false)
    }

    @Test("An exercise removed from the workout can be added again")
    func addExercisesAfterRemoval() throws {
        let workout = try harness.workouts.createWorkout(name: "Push")
        let items = try harness.workouts.addExercises([bench, row], to: workout)

        try harness.workouts.removeExercise(items[0])
        #expect(try count(PlannedSet.self, in: harness.context) == 3)
        try harness.workouts.addExercises([bench], to: workout)

        #expect(workout.orderedExercises.map { $0.exercise?.id } == [row.id, bench.id])
        #expect(sortIndexes(of: workout) == [0, 1])
    }

    @Test("Exercises added from the picker can be reordered")
    func addExercisesThenMove() throws {
        let workout = try harness.workouts.createWorkout(name: "Full")
        try harness.workouts.addExercises([bench, row, squat], to: workout)

        try harness.workouts.moveExercises(in: workout, fromOffsets: [2], toOffset: 0)

        #expect(workout.orderedExercises.map { $0.exercise?.id } == [squat.id, bench.id, row.id])
        #expect(sortIndexes(of: workout) == [0, 1, 2])
    }

    @Test("Deleting a workout built from the picker keeps its session history")
    func addExercisesDeleteKeepsHistory() throws {
        let workout = try harness.workouts.createWorkout(name: "Push")
        try harness.workouts.addExercises([bench, row], to: workout)
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(session.orderedExercises[0].orderedSetLogs[0], weightKg: 40, reps: 10)
        try harness.sessions.finishSession(session)

        try harness.workouts.delete(workout)

        #expect(try count(Workout.self, in: harness.context) == 0)
        #expect(try count(WorkoutExercise.self, in: harness.context) == 0)
        #expect(try count(PlannedSet.self, in: harness.context) == 0)
        #expect(try count(Session.self, in: harness.context) == 1)
        #expect(try count(SessionExercise.self, in: harness.context) == 2)
        #expect(try count(SetLog.self, in: harness.context) == 6)
        #expect(session.workout == nil)
        #expect(session.workoutNameSnapshot == "Push")
    }

    // MARK: - Planned sets

    @Test("Adding a planned set appends it with the given values")
    func addPlannedSet() throws {
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10, kg: 20)])])
        let item = workout.orderedExercises[0]
        harness.clock.advance(by: 5)

        let added = try harness.workouts.addPlannedSet(to: item, values: .reps(6, 8, kg: 22.25))

        #expect(sortIndexes(of: item) == [0, 1])
        #expect(item.orderedPlannedSets.last?.id == added.id)
        #expect(added.weightKg == 22.25)
        #expect(added.repsMin == 6)
        #expect(added.repsMax == 8)
        #expect(workout.updatedAt == harness.clock.current)

        #expect(throws: ValidationError.invalidRepsMin) { try harness.workouts.addPlannedSet(to: item, values: .reps(0, 8)) }
        #expect(item.plannedSets.count == 2)
    }

    @Test("Updating a planned set saves valid values and keeps the old ones on error")
    func updatePlannedSet() throws {
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10, kg: 20)])])
        let plannedSet = workout.orderedExercises[0].orderedPlannedSets[0]
        let createdAt = plannedSet.createdAt
        harness.clock.advance(by: 5)

        try harness.workouts.updatePlannedSet(plannedSet, values: .reps(10, 12, kg: nil))
        #expect(plannedSet.weightKg == nil)
        #expect(plannedSet.repsMin == 10)
        #expect(plannedSet.repsMax == 12)
        #expect(plannedSet.createdAt == createdAt)
        #expect(plannedSet.updatedAt == harness.clock.current)
        #expect(workout.updatedAt == harness.clock.current)

        for invalid in [PlannedSetValues.reps(12, 10), .reps(0, 10), .reps(8, 0), .reps(8, 10, kg: -1), .reps(8, 10, kg: 1.005)] {
            #expect(throws: ValidationError.self) { try harness.workouts.updatePlannedSet(plannedSet, values: invalid) }
        }
        #expect(plannedSet.weightKg == nil)
        #expect(plannedSet.repsMin == 10)
        #expect(plannedSet.repsMax == 12)
        #expect(harness.context.hasChanges == false)
    }

    @Test("Adding a set copies the values of the last set and appends it")
    func addPlannedSetCopyingLast() throws {
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10, kg: 20), .reps(6, 8, kg: 82.5)])])
        let item = workout.orderedExercises[0]
        harness.clock.advance(by: 5)

        let added = try harness.workouts.addPlannedSetCopyingLast(to: item)

        #expect(item.orderedPlannedSets.last?.id == added.id)
        #expect(sortIndexes(of: item) == [0, 1, 2])
        #expect(added.repsMin == 6)
        #expect(added.repsMax == 8)
        #expect(added.weightKg == 82.5)
        #expect(added.createdAt == harness.clock.current)
        #expect(workout.updatedAt == harness.clock.current)
        #expect(harness.context.hasChanges == false)

        try harness.workouts.addPlannedSetCopyingLast(to: item)
        #expect(item.orderedPlannedSets.map(\.repsMin) == [8, 6, 6, 6])
        #expect(sortIndexes(of: item) == [0, 1, 2, 3])
    }

    @Test("Copying the last set of an item without sets changes nothing")
    func addPlannedSetCopyingLastWithoutSets() throws {
        // Such items cannot be produced through the services; it is built directly.
        let workout = try harness.workouts.createWorkout(name: "Inconsistente")
        let item = WorkoutExercise(sortIndex: 0)
        harness.context.insert(item)
        item.workout = workout
        item.exercise = bench
        try harness.context.save()
        let before = try storeCounts(in: harness.context)

        #expect(throws: WorkoutError.plannedSetsMissing) { try harness.workouts.addPlannedSetCopyingLast(to: item) }
        #expect(try storeCounts(in: harness.context) == before)
        #expect(harness.context.hasChanges == false)
    }

    @Test("Planned set values above the limits are rejected and change nothing")
    func plannedSetLimits() throws {
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10, kg: 20)])])
        let item = workout.orderedExercises[0]
        let plannedSet = item.orderedPlannedSets[0]
        let updatedAt = plannedSet.updatedAt
        let before = try storeCounts(in: harness.context)
        harness.clock.advance(by: 5)

        #expect(throws: ValidationError.repsTooHigh) { try harness.workouts.updatePlannedSet(plannedSet, values: .reps(8, 101)) }
        #expect(throws: ValidationError.weightTooHigh) { try harness.workouts.updatePlannedSet(plannedSet, values: .reps(8, 10, kg: 1_000.5)) }
        #expect(throws: ValidationError.repsTooHigh) { try harness.workouts.addPlannedSet(to: item, values: .reps(120, 150)) }

        #expect(plannedSet.repsMin == 8)
        #expect(plannedSet.repsMax == 10)
        #expect(plannedSet.weightKg == 20)
        #expect(plannedSet.updatedAt == updatedAt)
        #expect(try storeCounts(in: harness.context) == before)
        #expect(harness.context.hasChanges == false)

        try harness.workouts.updatePlannedSet(plannedSet, values: .reps(100, 100, kg: 1_000))
        #expect(plannedSet.repsMax == 100)
        #expect(plannedSet.weightKg == 1_000)
    }

    @Test("Editing, adding and removing planned sets does not change the history")
    func plannedSetChangesKeepHistory() throws {
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10, kg: 20), .reps(6, 8, kg: 22.5)])])
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(session.orderedExercises[0].orderedSetLogs[0], weightKg: 20, reps: 9)
        try harness.sessions.finishSession(session)
        func history() -> [[Double?]] {
            session.orderedExercises[0].orderedSetLogs.map {
                [$0.targetWeightKg, $0.targetRepsMin.map { Double($0) }, $0.targetRepsMax.map { Double($0) }, $0.weightKg, $0.reps.map { Double($0) }]
            }
        }
        let before = history()

        let item = workout.orderedExercises[0]
        try harness.workouts.updatePlannedSet(item.orderedPlannedSets[0], values: .reps(12, 15, kg: 100))
        try harness.workouts.addPlannedSetCopyingLast(to: item)
        try harness.workouts.removePlannedSet(item.orderedPlannedSets[1])

        #expect(history() == before)
        #expect(session.orderedExercises[0].setLogs.count == 2)
    }

    @Test("Removing a planned set renumbers; the last one cannot be removed")
    func removePlannedSet() throws {
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10), .reps(6, 8), .reps(4, 6)])])
        let item = workout.orderedExercises[0]

        try harness.workouts.removePlannedSet(item.orderedPlannedSets[1])
        #expect(item.orderedPlannedSets.map(\.repsMin) == [8, 4])
        #expect(sortIndexes(of: item) == [0, 1])

        try harness.workouts.removePlannedSet(item.orderedPlannedSets[0])
        #expect(throws: WorkoutError.lastPlannedSet) { try harness.workouts.removePlannedSet(item.orderedPlannedSets[0]) }
        #expect(item.plannedSets.count == 1)
        #expect(sortIndexes(of: item) == [0])
    }

    @Test("Moving planned sets renumbers them")
    func movePlannedSets() throws {
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(1, 1), .reps(2, 2), .reps(3, 3)])])
        let item = workout.orderedExercises[0]

        try harness.workouts.movePlannedSets(in: item, fromOffsets: [0], toOffset: 3)
        #expect(item.orderedPlannedSets.map(\.repsMin) == [2, 3, 1])
        #expect(sortIndexes(of: item) == [0, 1, 2])
    }

    @Test("Plan changes update the changed object and the workout")
    func updatedAtPropagation() throws {
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10)]), (row, [.reps(8, 10)])])
        let item = workout.orderedExercises[0]

        harness.clock.advance(by: 10)
        try harness.workouts.addPlannedSet(to: item, values: .reps(6, 8))
        #expect(workout.updatedAt == harness.clock.current)

        harness.clock.advance(by: 10)
        try harness.workouts.moveExercises(in: workout, fromOffsets: [1], toOffset: 0)
        #expect(workout.updatedAt == harness.clock.current)
        #expect(workout.orderedExercises.allSatisfy { $0.updatedAt == harness.clock.current })

        harness.clock.advance(by: 10)
        try harness.workouts.removeExercise(workout.orderedExercises[0])
        #expect(workout.updatedAt == harness.clock.current)
    }

    @Test("Repeated add, remove and move never leave duplicate or missing indexes")
    func sortIndexStaysContiguous() throws {
        let workout = try harness.workouts.createWorkout(name: "Ordem")
        // Each round adds three exercises that are not in the workout yet: an exercise is never added twice.
        let others = try (1...9).map { try harness.exercises.createCustomExercise(name: "Exercício \($0)", muscleGroup: .other) }
        let pool = [bench, row, squat] + others
        for round in 0..<4 {
            try harness.workouts.addExercises(Array(pool[(round * 3)..<(round * 3 + 3)]), to: workout)
            try harness.workouts.moveExercises(in: workout, fromOffsets: [0, 2], toOffset: workout.exercises.count)
            try harness.workouts.removeExercise(workout.orderedExercises[round % workout.exercises.count])
            let item = workout.orderedExercises[0]
            // Down to the one-set minimum, removing the first set each time.
            while item.plannedSets.count > 1 {
                try harness.workouts.removePlannedSet(item.orderedPlannedSets[0])
                #expect(sortIndexes(of: item) == Array(0..<item.plannedSets.count))
            }
            try harness.workouts.addPlannedSet(to: item, values: .reps(5, 5))
            try harness.workouts.movePlannedSets(in: item, fromOffsets: [0], toOffset: item.plannedSets.count)
            try harness.workouts.removePlannedSet(item.orderedPlannedSets[0])

            #expect(sortIndexes(of: workout) == Array(0..<workout.exercises.count))
            for item in workout.orderedExercises {
                #expect(sortIndexes(of: item) == Array(0..<item.plannedSets.count))
            }
        }
    }

    // MARK: - Delete

    @Test("Deleting a workout removes its plan and keeps sessions, other workouts and the library")
    func deleteWorkoutKeepsHistory() throws {
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10), .reps(6, 8)])])
        let other = try harness.makeWorkout(name: "Pull", items: [(row, [.reps(8, 10)])])
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(session.orderedExercises[0].orderedSetLogs[0], weightKg: 20, reps: 10)
        try harness.sessions.finishSession(session)

        try harness.workouts.delete(workout)

        #expect(try count(Workout.self, in: harness.context) == 1)
        #expect(try count(WorkoutExercise.self, in: harness.context) == 1)
        #expect(try count(PlannedSet.self, in: harness.context) == 1)
        #expect(other.orderedExercises.count == 1)
        #expect(try count(Exercise.self, in: harness.context) == 3)
        #expect(try count(Session.self, in: harness.context) == 1)
        #expect(try count(SessionExercise.self, in: harness.context) == 1)
        #expect(try count(SetLog.self, in: harness.context) == 2)
        #expect(session.workout == nil)
        #expect(session.workoutNameSnapshot == "Push")
    }
}
