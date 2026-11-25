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

    /// A valid draft of an exercise of the user's own: chest, dumbbells and the chest as its main muscle,
    /// unless told otherwise.
    static func draft(
        _ name: String,
        group: MuscleGroup = .chest,
        equipment: EquipmentChoice = .equipment(.dumbbell),
        primary: [Muscle] = [.chest],
        secondary: [Muscle] = []
    ) -> ExerciseDraft {
        ExerciseDraft(name: name, group: group, equipment: equipment, primary: primary, secondary: secondary)
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

    @Test("A name used by an archived exercise of the user's own is not free: the error names it, to restore it")
    func archivedNameIsTaken() throws {
        let old = try harness.exercises.createCustomExercise(name: "Crucifixo", muscleGroup: .chest)
        try harness.exercises.archive(old)
        let before = try storeCounts(in: harness.context)

        #expect(throws: ExerciseError.archivedExerciseHasName(name: "Crucifixo")) {
            try harness.exercises.create(Self.draft("crucifixo"))
        }
        #expect(throws: ExerciseError.archivedExerciseHasName(name: "Crucifixo")) {
            try harness.exercises.createCustomExercise(name: "CRUCIFIXO", muscleGroup: .chest)
        }
        #expect(try storeCounts(in: harness.context) == before)
        #expect(harness.context.hasChanges == false)
    }

    @Test("A name used only by an archived built-in exercise, which left the library, can be used")
    func archivedBuiltInNameIsFree() throws {
        let old = try harness.insertSystemExercise(name: "Crucifixo", muscleGroup: .chest, libraryKey: "old-fly")
        try harness.exercises.archive(old)

        let new = try harness.exercises.create(Self.draft("Crucifixo"))
        #expect(new.id != old.id)
    }

    @Test("Creating stores the equipment, the kind of machine and the muscles, with the name trimmed")
    func createWithChoices() throws {
        var draft = Self.draft("  Puxada na Máquina Articulada ", group: .back, equipment: .equipment(.machine), primary: [.lats], secondary: [.biceps, .upperBack])
        draft.machine = .lever
        let exercise = try harness.exercises.create(draft)

        #expect(exercise.name == "Puxada na Máquina Articulada")
        #expect(exercise.isCustom && !exercise.isArchived)
        #expect(exercise.libraryKey == nil)
        #expect(exercise.muscleGroup == .back)
        #expect(exercise.equipment == .machine)
        #expect(exercise.machineType == .lever)
        #expect(exercise.primaryMuscles == [.lats])
        #expect(exercise.secondaryMuscles == [.biceps, .upperBack])
        #expect(exercise.createdAt == harness.clock.current)
        #expect(harness.context.hasChanges == false)
    }

    @Test("\"Outro\" is stored as no equipment, and a kind of machine only counts with the machine")
    func otherEquipmentAndMachineOnlyWithMachine() throws {
        var draft = Self.draft("Remada Livre", equipment: .other)
        draft.machine = .graviton
        let other = try harness.exercises.create(draft)
        #expect(other.equipmentRaw == nil)
        #expect(other.machineTypeRaw == nil)

        draft.name = "Remada Halter"
        draft.equipment = .equipment(.dumbbell)
        let dumbbell = try harness.exercises.create(draft)
        #expect(dumbbell.equipment == .dumbbell)
        #expect(dumbbell.machineType == nil)
    }

    @Test("Every required field is checked before anything is saved")
    func requiredFields() throws {
        var noGroup = Self.draft("Sem grupo")
        noGroup.group = nil
        var noEquipment = Self.draft("Sem equipamento")
        noEquipment.equipment = nil
        let noPrimary = Self.draft("Sem principal", primary: [])
        let both = Self.draft("Nos dois", primary: [.chest], secondary: [.chest, .triceps])
        let longName = Self.draft(String(repeating: "a", count: 61))

        #expect(throws: ValidationError.emptyName) { try harness.exercises.create(Self.draft("   ")) }
        #expect(throws: ValidationError.nameTooLong) { try harness.exercises.create(longName) }
        #expect(throws: ExerciseError.muscleGroupMissing) { try harness.exercises.create(noGroup) }
        #expect(throws: ExerciseError.equipmentMissing) { try harness.exercises.create(noEquipment) }
        #expect(throws: ExerciseError.primaryMuscleMissing) { try harness.exercises.create(noPrimary) }
        #expect(throws: ExerciseError.muscleInBothLists) { try harness.exercises.create(both) }
        #expect(try count(Exercise.self, in: harness.context) == 0)
        #expect(harness.context.hasChanges == false)

        // 60 letters fit, and "Corpo inteiro" needs no main muscle.
        try harness.exercises.create(Self.draft(String(repeating: "a", count: 60)))
        try harness.exercises.create(Self.draft("Circuito", group: .fullBody, primary: []))
        #expect(try count(Exercise.self, in: harness.context) == 2)
    }

    @Test("Names are compared ignoring case and diacritics, against active exercises and archived ones of the user's own")
    func nameRules() throws {
        try harness.exercises.create(Self.draft("Elevação Pélvica"))
        let archived = try harness.exercises.create(Self.draft("Remada Cavalinho"))
        try harness.exercises.archive(archived)
        _ = try harness.insertSystemExercise(name: "Supino Reto (Barra)", muscleGroup: .chest, libraryKey: "bench-press-barbell")

        #expect(throws: ValidationError.duplicateExerciseName) { try harness.exercises.create(Self.draft("elevacao pelvica")) }
        #expect(throws: ValidationError.duplicateExerciseName) { try harness.exercises.create(Self.draft("SUPINO RETO (BARRA)")) }
        #expect(throws: ExerciseError.archivedExerciseHasName(name: "Remada Cavalinho")) {
            try harness.exercises.create(Self.draft(" remada cavalinho "))
        }
        let taken = try harness.exercises.takenNames(ignoring: nil)
        #expect(taken[Validation.comparisonKey(forName: "remada cavalinho")] == ExerciseNameOwner(name: "Remada Cavalinho", isArchived: true))
        #expect(taken[Validation.comparisonKey(forName: "elevação pélvica")] == ExerciseNameOwner(name: "Elevação Pélvica", isArchived: false))
    }

    @Test("Editing changes every field, keeps createdAt, and the history and the session keep the name of their day")
    func updateCustom() throws {
        let exercise = try harness.exercises.createCustomExercise(name: "Rosca", muscleGroup: .biceps)
        let workout = try harness.makeWorkout(name: "Braço", items: [(exercise, [.reps(8, 12)])])
        let session = try harness.sessions.startSession(from: workout)
        let createdAt = exercise.createdAt
        harness.clock.advance(by: 60)

        var draft = Self.draft(" Rosca Direta ", group: .forearms, equipment: .equipment(.machine), primary: [.forearms], secondary: [.biceps])
        draft.machine = .plates
        try harness.exercises.update(exercise, with: draft)

        #expect(exercise.name == "Rosca Direta")
        #expect(exercise.muscleGroup == .forearms)
        #expect(exercise.equipment == .machine)
        #expect(exercise.machineType == .plates)
        #expect(exercise.primaryMuscles == [.forearms])
        #expect(exercise.secondaryMuscles == [.biceps])
        #expect(exercise.createdAt == createdAt)
        #expect(exercise.updatedAt == harness.clock.current)
        // The planned workout shows the new name; the session keeps the one of its day.
        #expect(workout.orderedExercises.map { $0.exercise?.name } == ["Rosca Direta"])
        #expect(session.orderedExercises[0].exerciseNameSnapshot == "Rosca")
        #expect(session.orderedExercises[0].muscleGroupSnapshot == .biceps)
    }

    @Test("Editing keeps its own name valid and rejects another exercise's name, also an archived one")
    func updateNameRules() throws {
        let curl = try harness.exercises.createCustomExercise(name: "Rosca", muscleGroup: .biceps)
        try harness.exercises.createCustomExercise(name: "Martelo", muscleGroup: .biceps)
        let archived = try harness.exercises.createCustomExercise(name: "Concentrada", muscleGroup: .biceps)
        try harness.exercises.archive(archived)

        try harness.exercises.update(curl, with: Self.draft("ROSCA", group: .biceps, primary: [.biceps]))
        #expect(curl.name == "ROSCA")

        #expect(throws: ValidationError.duplicateExerciseName) {
            try harness.exercises.update(curl, with: Self.draft("martelo", group: .biceps, primary: [.biceps]))
        }
        #expect(throws: ExerciseError.archivedExerciseHasName(name: "Concentrada")) {
            try harness.exercises.update(curl, with: Self.draft("concentrada", group: .biceps, primary: [.biceps]))
        }
        #expect(throws: ValidationError.emptyName) {
            try harness.exercises.update(curl, with: Self.draft("  ", group: .biceps, primary: [.biceps]))
        }
        // An archived exercise can be edited too, keeping its name.
        try harness.exercises.update(archived, with: Self.draft("Concentrada", group: .biceps, primary: [.biceps]))
        #expect(archived.isArchived)
        #expect(curl.name == "ROSCA")
        #expect(harness.context.hasChanges == false)
    }

    @Test("A system exercise cannot be edited")
    func systemExerciseNotEditable() throws {
        let bench = try harness.insertSystemExercise(name: "Supino Reto", muscleGroup: .chest, libraryKey: "bench-press")

        #expect(throws: ExerciseError.systemExerciseNotEditable) {
            try harness.exercises.update(bench, with: Self.draft("Outro nome", group: .back, primary: [.lats]))
        }
        #expect(bench.name == "Supino Reto")
        #expect(bench.muscleGroup == .chest)
    }

    // MARK: - Copy

    @Test("A copy's name gets 2, then 3, against active and archived names, and fits in 60 letters")
    func copyNames() throws {
        try harness.exercises.create(Self.draft("Leg Press"))
        #expect(try harness.exercises.copyName(for: "Leg Press") == "Leg Press 2")
        let second = try harness.exercises.create(Self.draft("leg press 2"))
        try harness.exercises.archive(second)
        #expect(try harness.exercises.copyName(for: "Leg Press") == "Leg Press 3")

        let long = String(repeating: "b", count: 60)
        #expect(try harness.exercises.copyName(for: long) == String(repeating: "b", count: 58) + " 2")
        #expect(ExerciseService.copyName(for: String(repeating: "c", count: 57) + " d e") { _ in false } == String(repeating: "c", count: 57) + " 2")
        let taken = Set((2...9).map { "Remada \($0)" })
        #expect(ExerciseService.copyName(for: "Remada") { taken.contains($0) } == "Remada 10")
    }

    @Test("A copy of a library exercise or of one of the user's own copies its choices, starts without history, and the original does not change")
    func copies() throws {
        let entry = try #require(DefaultExerciseLibrary.byKey["leg-press"])
        let library = try harness.insertSystemExercise(name: entry.name, muscleGroup: entry.muscleGroup, libraryKey: entry.key)
        let workout = try harness.makeWorkout(name: "Pernas", items: [(library, [.reps(8, 10)])])
        try harness.sessions.startSession(from: workout)

        var mine = ExerciseDraft(library)
        mine.name = try harness.exercises.copyName(for: library.name)
        #expect(mine.equipment == .equipment(.machine))
        #expect(mine.machine == DefaultExerciseMuscles.byKey["leg-press"]?.machine)
        #expect(mine.primary == DefaultExerciseMuscles.byKey["leg-press"]?.primary)
        let version = try harness.exercises.create(mine)

        #expect(version.name == "\(entry.name) 2")
        #expect(version.isCustom)
        #expect(version.sessionExercises.isEmpty)
        #expect(version.workoutExercises.isEmpty)
        #expect(version.equipment == .machine)
        #expect(version.machineType == DefaultExerciseMuscles.byKey["leg-press"]?.machine)
        #expect(DefaultExerciseMuscles.muscles(of: version).primary == DefaultExerciseMuscles.byKey["leg-press"]?.primary)
        #expect(library.name == entry.name)
        #expect(library.sessionExercises.count == 1)

        var copy = ExerciseDraft(version)
        copy.name = try harness.exercises.copyName(for: version.name)
        let second = try harness.exercises.create(copy)
        // As in the prototype, a copy of "… 2" is "… 2 2".
        #expect(second.name == "\(entry.name) 2 2")
        #expect(second.primaryMuscles == version.primaryMuscles)
        #expect(second.secondaryMuscles == version.secondaryMuscles)
        #expect(second.machineType == version.machineType)
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

    @Test("Restoring fails, with the other exercise's name, when an active exercise already has the name")
    func unarchiveNameConflict() throws {
        let old = try harness.exercises.createCustomExercise(name: "Crucifixo", muscleGroup: .chest)
        try harness.exercises.archive(old)
        // A built-in exercise that took the name meanwhile (the library can rename its exercises).
        _ = try harness.insertSystemExercise(name: "CRUCIFIXO", muscleGroup: .chest, libraryKey: "fly")

        #expect(throws: ExerciseError.nameTakenByActiveExercise(name: "CRUCIFIXO")) { try harness.exercises.unarchive(old) }
        #expect(old.isArchived)
        #expect(harness.context.hasChanges == false)
    }

    @Test("Restoring only conflicts with an active exercise, and the restored exercise does not go back to its workouts")
    func restoreWithoutConflict() throws {
        let other = try harness.exercises.createCustomExercise(name: "Agachamento", muscleGroup: .quadriceps)
        let exercise = try harness.exercises.createCustomExercise(name: "Afundo", muscleGroup: .glutes)
        let workout = try harness.makeWorkout(name: "Perna", items: [(other, [.reps(8, 10)]), (exercise, [.reps(10, 12)])])
        try harness.sessions.startSession(from: workout)
        #expect(try harness.exercises.remove(exercise, confirmedWorkoutIDs: [workout.id]) == .archived)
        harness.clock.advance(by: 10)

        try harness.exercises.unarchive(exercise)

        #expect(exercise.isArchived == false)
        #expect(exercise.updatedAt == harness.clock.current)
        #expect(workout.orderedExercises.map { $0.exercise?.id } == [other.id])
    }

    // MARK: - Removal

    @Test("Removal impact: built-in, deleted without history, archived with history or in the session in progress, with the workouts it leaves")
    func removalImpact() throws {
        let system = try harness.insertSystemExercise(name: "Supino Reto", muscleGroup: .chest, libraryKey: "bench-press")
        let unused = try harness.exercises.createCustomExercise(name: "Sem uso", muscleGroup: .other)
        let planned = try harness.exercises.createCustomExercise(name: "Planejado", muscleGroup: .back)
        let performed = try harness.exercises.createCustomExercise(name: "Executado", muscleGroup: .calves)
        let workout = try harness.makeWorkout(name: "Treino", items: [(planned, [.reps(8, 10)])])
        let performedWorkout = try harness.makeWorkout(name: "Feito", items: [(performed, [.reps(8, 10)])])
        try harness.sessions.startSession(from: performedWorkout)

        #expect(harness.exercises.removalImpact(of: system) == .notAllowedSystemExercise)
        #expect(harness.exercises.removalImpact(of: unused) == .willDelete([]))
        #expect(harness.exercises.removalImpact(of: planned) == .willDelete([workout]))
        #expect(harness.exercises.removalImpact(of: performed) == .willArchive([performedWorkout]))
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

    @Test("A custom exercise with history is archived, leaves its workouts (renumbered) and keeps its history with the name of its day")
    func removeWithHistoryArchives() throws {
        let first = try harness.exercises.createCustomExercise(name: "Supino", muscleGroup: .chest)
        let exercise = try harness.exercises.createCustomExercise(name: "Rosca", muscleGroup: .biceps)
        let last = try harness.exercises.createCustomExercise(name: "Tríceps", muscleGroup: .triceps)
        let workout = try harness.makeWorkout(name: "Braço", items: [
            (first, [.reps(8, 12)]), (exercise, [.reps(8, 12), .reps(8, 12)]), (last, [.reps(10, 12)]),
        ])
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(session.orderedExercises[1].orderedSetLogs[0], weightKg: 12, reps: 10)
        try harness.sessions.finishSession(session)
        try harness.exercises.update(exercise, with: Self.draft("Rosca Direta", group: .biceps, primary: [.biceps]))
        harness.clock.advance(by: 30)

        #expect(throws: ExerciseError.confirmationRequired(workoutIDs: [workout.id])) { try harness.exercises.remove(exercise) }
        #expect(try harness.exercises.remove(exercise, confirmedWorkoutIDs: [workout.id]) == .archived)

        #expect(exercise.isArchived)
        #expect(exercise.updatedAt == harness.clock.current)
        #expect(try count(Exercise.self, in: harness.context) == 3)
        #expect(workout.orderedExercises.map { $0.exercise?.id } == [first.id, last.id])
        #expect(workout.orderedExercises.map(\.sortIndex) == [0, 1])
        #expect(workout.updatedAt == harness.clock.current)
        #expect(try count(PlannedSet.self, in: harness.context) == 2)
        // The finished session kept only what was done: the curl, under the name of its day.
        #expect(try count(SessionExercise.self, in: harness.context) == 1)
        #expect(session.orderedExercises.map { $0.exercise?.id } == [exercise.id])
        #expect(session.orderedExercises[0].exerciseNameSnapshot == "Rosca")
        #expect(session.orderedExercises[0].orderedSetLogs.map(\.reps) == [10])
    }

    @Test("A custom exercise in the session in progress is archived and stays in the session")
    func removeInSessionArchives() throws {
        let exercise = try harness.exercises.createCustomExercise(name: "Rosca", muscleGroup: .biceps)
        let session = try harness.sessions.startFreeSession()
        try harness.sessions.addExercises([exercise], to: session)

        #expect(try harness.exercises.remove(exercise) == .archived)
        #expect(exercise.isArchived)
        #expect(session.isActive)
        #expect(session.orderedExercises.map { $0.exercise?.id } == [exercise.id])
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
