import Foundation
import SwiftData
import Testing
@testable import IronFlow

@MainActor
struct ExerciseServiceTests {
    let harness: ServiceTestHarness

    init() throws {
        harness = try ServiceTestHarness()
    }

    // MARK: - Create and update

    @Test("Creating a custom exercise stores it trimmed, with equal timestamps from the clock")
    func createCustom() throws {
        let exercise = try harness.exercises.createCustomExercise(name: "  Elevação Pélvica ", muscleGroup: .glutes)

        #expect(exercise.name == "Elevação Pélvica")
        #expect(exercise.isCustom)
        #expect(exercise.isArchived == false)
        #expect(exercise.muscleGroup == .glutes)
        #expect(exercise.createdAt == harness.clock.current)
        #expect(exercise.updatedAt == harness.clock.current)
        #expect(try count(Exercise.self, in: harness.context) == 1)
        #expect(harness.context.hasChanges == false)
    }

    @Test("Each created exercise gets a new id")
    func createdIDsAreUnique() throws {
        let first = try harness.exercises.createCustomExercise(name: "A", muscleGroup: .other)
        let second = try harness.exercises.createCustomExercise(name: "B", muscleGroup: .other)
        #expect(first.id != second.id)
    }

    @Test("Active exercise names are unique ignoring case and diacritics; nothing is saved on conflict")
    func duplicateNameRejected() throws {
        try harness.exercises.createCustomExercise(name: "Elevação Pélvica", muscleGroup: .glutes)
        let before = try storeCounts(in: harness.context)

        #expect(throws: ValidationError.duplicateExerciseName) {
            try harness.exercises.createCustomExercise(name: "elevacao pelvica", muscleGroup: .glutes)
        }
        #expect(try storeCounts(in: harness.context) == before)
        #expect(harness.context.hasChanges == false)
    }

    @Test("A name used only by an archived exercise can be reused")
    func archivedNameCanBeReused() throws {
        let old = try harness.exercises.createCustomExercise(name: "Crucifixo", muscleGroup: .chest)
        try harness.exercises.archive(old)

        let new = try harness.exercises.createCustomExercise(name: "Crucifixo", muscleGroup: .chest)
        #expect(new.id != old.id)
    }

    @Test("Updating a custom exercise changes it, keeps createdAt and does not touch history")
    func updateCustom() throws {
        let exercise = try harness.exercises.createCustomExercise(name: "Rosca", muscleGroup: .biceps)
        let workout = try harness.makeWorkout(name: "Braço", items: [(exercise, [.reps(8, 12)])])
        let session = try harness.sessions.startSession(from: workout)
        let createdAt = exercise.createdAt
        harness.clock.advance(by: 60)

        try harness.exercises.updateCustomExercise(exercise, name: " Rosca Direta ", muscleGroup: .forearms)

        #expect(exercise.name == "Rosca Direta")
        #expect(exercise.muscleGroup == .forearms)
        #expect(exercise.createdAt == createdAt)
        #expect(exercise.updatedAt == harness.clock.current)
        #expect(session.orderedExercises[0].exerciseNameSnapshot == "Rosca")
        #expect(session.orderedExercises[0].muscleGroupSnapshot == .biceps)
    }

    @Test("Updating keeps its own name valid and rejects another exercise's name")
    func updateNameRules() throws {
        let curl = try harness.exercises.createCustomExercise(name: "Rosca", muscleGroup: .biceps)
        try harness.exercises.createCustomExercise(name: "Martelo", muscleGroup: .biceps)

        try harness.exercises.updateCustomExercise(curl, name: "ROSCA", muscleGroup: .biceps)
        #expect(curl.name == "ROSCA")

        #expect(throws: ValidationError.duplicateExerciseName) {
            try harness.exercises.updateCustomExercise(curl, name: "martelo", muscleGroup: .biceps)
        }
        #expect(throws: ValidationError.emptyName) {
            try harness.exercises.updateCustomExercise(curl, name: "  ", muscleGroup: .biceps)
        }
        #expect(curl.name == "ROSCA")
        #expect(harness.context.hasChanges == false)
    }

    @Test("A system exercise cannot be edited")
    func systemExerciseNotEditable() throws {
        let bench = try harness.insertSystemExercise(name: "Supino Reto", muscleGroup: .chest, libraryKey: "bench-press")

        #expect(throws: ExerciseError.systemExerciseNotEditable) {
            try harness.exercises.updateCustomExercise(bench, name: "Outro nome", muscleGroup: .back)
        }
        #expect(bench.name == "Supino Reto")
        #expect(bench.muscleGroup == .chest)
    }

    // MARK: - Archive

    @Test("Archiving and restoring work for system and custom exercises and keep workouts intact")
    func archiveAndUnarchive() throws {
        let bench = try harness.insertSystemExercise(name: "Supino Reto", muscleGroup: .chest, libraryKey: "bench-press")
        let custom = try harness.exercises.createCustomExercise(name: "Crucifixo", muscleGroup: .chest)
        let workout = try harness.makeWorkout(name: "Peito", items: [(bench, [.reps(8, 10)]), (custom, [.reps(10, 12)])])
        harness.clock.advance(by: 30)

        try harness.exercises.archive(bench)
        try harness.exercises.archive(custom)
        #expect(bench.isArchived && custom.isArchived)
        #expect(custom.updatedAt == harness.clock.current)
        #expect(workout.orderedExercises.map { $0.exercise?.id } == [bench.id, custom.id])

        try harness.exercises.unarchive(bench)
        try harness.exercises.unarchive(custom)
        #expect(bench.isArchived == false && custom.isArchived == false)
    }

    @Test("Restoring fails when an active exercise already has the same name")
    func unarchiveNameConflict() throws {
        let old = try harness.exercises.createCustomExercise(name: "Crucifixo", muscleGroup: .chest)
        try harness.exercises.archive(old)
        try harness.exercises.createCustomExercise(name: "CRUCIFIXO", muscleGroup: .chest)

        #expect(throws: ValidationError.duplicateExerciseName) { try harness.exercises.unarchive(old) }
        #expect(old.isArchived)
        #expect(harness.context.hasChanges == false)
    }

    // MARK: - Removal

    @Test("Removal impact reports each of the four cases")
    func removalImpact() throws {
        let system = try harness.insertSystemExercise(name: "Supino Reto", muscleGroup: .chest, libraryKey: "bench-press")
        let unused = try harness.exercises.createCustomExercise(name: "Sem uso", muscleGroup: .other)
        let planned = try harness.exercises.createCustomExercise(name: "Planejado", muscleGroup: .back)
        let performed = try harness.exercises.createCustomExercise(name: "Executado", muscleGroup: .calves)
        let workout = try harness.makeWorkout(name: "Treino", items: [(planned, [.reps(8, 10)])])
        let performedWorkout = try harness.makeWorkout(name: "Feito", items: [(performed, [.reps(8, 10)])])
        try harness.sessions.startSession(from: performedWorkout)

        #expect(harness.exercises.removalImpact(of: system) == .notAllowedSystemExercise)
        #expect(harness.exercises.removalImpact(of: unused) == .willDelete)
        #expect(harness.exercises.removalImpact(of: planned) == .willRemoveFromWorkouts([workout]))
        #expect(harness.exercises.removalImpact(of: performed) == .willArchive)
    }

    @Test("A system exercise cannot be removed")
    func systemExerciseNotDeletable() throws {
        let bench = try harness.insertSystemExercise(name: "Supino Reto", muscleGroup: .chest, libraryKey: "bench-press")

        #expect(throws: ExerciseError.systemExerciseNotDeletable) { try harness.exercises.remove(bench) }
        #expect(try count(Exercise.self, in: harness.context) == 1)
        #expect(bench.isArchived == false)
    }

    @Test("An unused custom exercise is deleted")
    func removeUnused() throws {
        let exercise = try harness.exercises.createCustomExercise(name: "Sem uso", muscleGroup: .other)

        #expect(try harness.exercises.remove(exercise) == .deleted)
        #expect(try count(Exercise.self, in: harness.context) == 0)
    }

    @Test("A custom exercise with history is archived and its history is kept")
    func removeWithHistoryArchives() throws {
        let exercise = try harness.exercises.createCustomExercise(name: "Rosca", muscleGroup: .biceps)
        let workout = try harness.makeWorkout(name: "Braço", items: [(exercise, [.reps(8, 12), .reps(8, 12)])])
        try harness.sessions.startSession(from: workout)

        #expect(try harness.exercises.remove(exercise) == .archived)
        #expect(exercise.isArchived)
        #expect(try count(Exercise.self, in: harness.context) == 1)
        #expect(try count(SessionExercise.self, in: harness.context) == 1)
        #expect(try count(SetLog.self, in: harness.context) == 2)
        // D-C: still in the workout.
        #expect(workout.orderedExercises.map { $0.exercise?.id } == [exercise.id])
    }

    @Test("Removing a custom exercise used in a workout requires confirmation; nothing changes without it")
    func removeFromWorkoutNeedsConfirmation() throws {
        let other = try harness.exercises.createCustomExercise(name: "Agachamento", muscleGroup: .quadriceps)
        let exercise = try harness.exercises.createCustomExercise(name: "Afundo", muscleGroup: .glutes)
        let workout = try harness.makeWorkout(name: "Perna", items: [(other, [.reps(8, 10)]), (exercise, [.reps(10, 12)])])
        let before = try storeCounts(in: harness.context)

        #expect(throws: ExerciseError.confirmationRequired(workoutIDs: [workout.id])) {
            try harness.exercises.remove(exercise)
        }
        #expect(try storeCounts(in: harness.context) == before)
        #expect(harness.context.hasChanges == false)
    }

    @Test("Confirmed removal deletes the exercise, its workout items and planned sets, and renumbers")
    func removeFromWorkoutConfirmed() throws {
        let first = try harness.exercises.createCustomExercise(name: "Agachamento", muscleGroup: .quadriceps)
        let removed = try harness.exercises.createCustomExercise(name: "Afundo", muscleGroup: .glutes)
        let last = try harness.exercises.createCustomExercise(name: "Panturrilha", muscleGroup: .calves)
        let workout = try harness.makeWorkout(name: "Perna", items: [
            (first, [.reps(8, 10)]),
            (removed, [.reps(10, 12), .reps(10, 12)]),
            (last, [.reps(12, 15)]),
        ])
        harness.clock.advance(by: 30)

        #expect(try harness.exercises.remove(removed, confirmedWorkoutIDs: [workout.id]) == .deleted)

        #expect(try count(Exercise.self, in: harness.context) == 2)
        #expect(try count(WorkoutExercise.self, in: harness.context) == 2)
        #expect(try count(PlannedSet.self, in: harness.context) == 2)
        #expect(workout.orderedExercises.map { $0.exercise?.id } == [first.id, last.id])
        #expect(workout.orderedExercises.map(\.sortIndex) == [0, 1])
        #expect(workout.updatedAt == harness.clock.current)
    }

    @Test("A confirmation for a different list of workouts is rejected and changes nothing")
    func staleConfirmationRejected() throws {
        let exercise = try harness.exercises.createCustomExercise(name: "Afundo", muscleGroup: .glutes)
        let shown = try harness.makeWorkout(name: "A", items: [(exercise, [.reps(10, 12)])])
        harness.clock.advance(by: 1)
        // Added after the user saw the confirmation listing only workout A.
        let added = try harness.makeWorkout(name: "B", items: [(exercise, [.reps(10, 12)])])
        let before = try storeCounts(in: harness.context)

        #expect(throws: ExerciseError.confirmationRequired(workoutIDs: [shown.id, added.id])) {
            try harness.exercises.remove(exercise, confirmedWorkoutIDs: [shown.id])
        }
        #expect(try storeCounts(in: harness.context) == before)
        #expect(harness.context.hasChanges == false)
    }

    @Test("Confirmed removal fixes every workout that used the exercise")
    func removeFromSeveralWorkouts() throws {
        let kept = try harness.exercises.createCustomExercise(name: "Remada", muscleGroup: .back)
        let removed = try harness.exercises.createCustomExercise(name: "Pullover", muscleGroup: .back)
        let workoutA = try harness.makeWorkout(name: "A", items: [(removed, [.reps(8, 10)]), (kept, [.reps(8, 10)])])
        harness.clock.advance(by: 1)
        let workoutB = try harness.makeWorkout(name: "B", items: [(kept, [.reps(8, 10)]), (removed, [.reps(8, 10)])])

        #expect(throws: ExerciseError.confirmationRequired(workoutIDs: [workoutA.id, workoutB.id])) {
            try harness.exercises.remove(removed)
        }
        try harness.exercises.remove(removed, confirmedWorkoutIDs: [workoutA.id, workoutB.id])

        for workout in [workoutA, workoutB] {
            #expect(workout.orderedExercises.map { $0.exercise?.id } == [kept.id])
            #expect(workout.orderedExercises.map(\.sortIndex) == [0])
        }
    }
}
