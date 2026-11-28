import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// The migration of a store with the library of 420 to the base list (`ExerciseLibrarySeeder`): renamed
/// exercises, junctions, the exercises that left the list, the new combinations and a custom exercise with
/// the name of one of them. Every store is on disk, as on the iPhone.
@MainActor
struct LibraryMigrationTests {
    /// A store as the app had it until this stage: the library of 420, and the person's data.
    private struct OldStore {
        let url: URL
        let directory: URL
    }

    /// The ids of the records the tests look at, by role.
    private enum Fixed {
        static let crossoverHigh = "cable-crossover"
        static let flyCable = "fly-cable"
        static let crossoverMid = "cable-crossover-mid"
        static let uprightRow = "upright-row-barbell"
        static let guillotine = "guillotine-press-barbell"
        static let scissorKick = "scissor-kick"
        static let deadBug = "dead-bug"
        static let gluteHam = "glute-ham-raise"
        static let calfRaise = "standing-calf-raise-bodyweight"
        static let tibialis = "tibialis-raise"
        static let sissySquat = "sissy-squat"
    }

    private static func exercise(_ key: String, in context: ModelContext) throws -> Exercise? {
        try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.libraryKey == key })).first
    }

    private static func exercise(id: String, in context: ModelContext) throws -> Exercise? {
        let uuid = try #require(UUID(uuidString: id))
        return try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == uuid })).first
    }

    private static func id(of key: String) throws -> String {
        try #require(Library420Fixture.entries.first { $0.key == key }).id
    }

    /// Writes, on disk, the library of 420 and:
    /// - "Peito": Crucifixo (Polia) and Crossover (Polia Média) (a junction, both in one workout), Crossover
    ///   (Polia Alta) (renamed) and Supino Guilhotina (Barra) (leaves the list), with a finished session
    ///   with a set of each;
    /// - a finished session with only Crossover (Polia Média), and one with Glute Ham Raise (Máquina)
    ///   (leaves the list, done on a GHD bench);
    /// - "Ombro": Remada Alta (Barra) (becomes Remada Ombro (Barra), and its name goes to a new
    ///   combination) and Abdominal Tesoura (leaves the list, only planned);
    /// - the session in progress with Dead Bug (leaves the list) and Elevação de Ponta dos Pés (merged into
    ///   Panturrilha em Pé), a set done of each;
    /// - two exercises of the user's own: "Meu Exercício", and "supino reto (kettlebell)", the name of a new
    ///   combination.
    private static func makeOldStore() throws -> OldStore {
        let directory = try makeTemporaryDirectory()
        let url = directory.appending(path: "IronFlow.store")
        let harness = ServiceTestHarness(container: try ModelContainerFactory.makePersistent(at: url))
        let context = harness.context
        try ExerciseLibrarySeeder(context: context, now: harness.clock.now).seed(Library420Fixture.entries, retired: [], junctions: [])

        let fly = try #require(try exercise(Fixed.flyCable, in: context))
        let mid = try #require(try exercise(Fixed.crossoverMid, in: context))
        let high = try #require(try exercise(Fixed.crossoverHigh, in: context))
        let guillotine = try #require(try exercise(Fixed.guillotine, in: context))
        let chest = try harness.makeWorkout(name: "Peito", items: [
            (fly, [.reps(10, 12, kg: 15), .reps(10, 12, kg: 15)]), (mid, [.reps(12, 15, kg: 10)]),
            (high, [.reps(12, 15)]), (guillotine, [.reps(8, 10, kg: 40)]),
        ])
        harness.clock.advance(by: 3_600)
        let first = try harness.sessions.startSession(from: chest)
        for (index, performed) in first.orderedExercises.enumerated() {
            harness.clock.advance(by: 120)
            try harness.sessions.completeSet(performed.orderedSetLogs[0], weightKg: Double(20 + index), reps: 10)
        }
        try harness.sessions.finishSession(first)

        harness.clock.advance(by: 86_400)
        let second = try harness.sessions.startFreeSession()
        try harness.sessions.addExercises([mid], to: second)
        try harness.sessions.completeSet(second.orderedExercises[0].orderedSetLogs[0], weightKg: 12, reps: 15)
        try harness.sessions.finishSession(second)

        harness.clock.advance(by: 86_400)
        let gluteHam = try #require(try exercise(Fixed.gluteHam, in: context))
        let third = try harness.sessions.startFreeSession()
        try harness.sessions.addExercises([gluteHam], to: third)
        try harness.sessions.completeSet(third.orderedExercises[0].orderedSetLogs[0], weightKg: 10, reps: 8)
        try harness.sessions.finishSession(third)

        let upright = try #require(try exercise(Fixed.uprightRow, in: context))
        let scissor = try #require(try exercise(Fixed.scissorKick, in: context))
        _ = try harness.makeWorkout(name: "Ombro", items: [(upright, [.reps(10, 12, kg: 30)]), (scissor, [.reps(15, 20)])])

        harness.clock.advance(by: 86_400)
        let deadBug = try #require(try exercise(Fixed.deadBug, in: context))
        let tibialis = try #require(try exercise(Fixed.tibialis, in: context))
        let active = try harness.sessions.startFreeSession()
        try harness.sessions.addExercises([deadBug, tibialis], to: active)
        for performed in active.orderedExercises {
            try harness.sessions.completeSet(performed.orderedSetLogs[0], weightKg: nil, reps: 12)
        }

        try harness.exercises.createCustomExercise(name: "Meu Exercício", muscleGroup: .other)
        try harness.exercises.createCustomExercise(name: "supino reto (kettlebell)", muscleGroup: .chest)
        try context.save()
        return OldStore(url: url, directory: directory)
    }

    // MARK: - The migration

    @Test("A store of 420 gets the base list: renamed exercises keep their records, history and workouts; the history shows the name of its day")
    func renamedExercises() throws {
        let store = try Self.makeOldStore()
        defer { removeTemporaryDirectory(store.directory) }
        let container = try ModelContainerFactory.makePersistent(at: store.url)
        let context = container.mainContext
        let result = try ExerciseLibrarySeeder(context: context).seed()

        #expect(result.skippedKeys.isEmpty)
        let highID = try Self.id(of: Fixed.crossoverHigh)
        let high = try #require(try Self.exercise(Fixed.crossoverHigh, in: context))
        #expect(high.id.uuidString == highID)
        #expect(high.name == "Crucifixo Alto (Polia)")
        #expect(result.updatedKeys.contains(Fixed.crossoverHigh))
        #expect(high.workoutExercises.count == 1)
        #expect(high.sessionExercises.map(\.exerciseNameSnapshot) == ["Crossover (Polia Alta)"])
        let history = try ExerciseHistoryLoader(context: context).history(of: high)
        #expect(history.entries.count == 1)

        // Remada Alta (Barra) becomes Remada Ombro (Barra), and the new Remada Alta (Barra) takes the name, active.
        let upright = try #require(try Self.exercise(Fixed.uprightRow, in: context))
        #expect(upright.name == "Remada Ombro (Barra)")
        #expect(upright.workoutExercises.first?.workout?.name == "Ombro")
        let highRowBarbell = try #require(try Self.exercise("remada-alta.barra.normal", in: context))
        #expect(highRowBarbell.name == "Remada Alta (Barra)")
        #expect(highRowBarbell.isArchived == false)
        #expect(highRowBarbell.sessionExercises.isEmpty && highRowBarbell.workoutExercises.isEmpty)
        #expect(result.keptNameKeys.isEmpty)
    }

    @Test("A junction: the history of both is in the combination, each session once with the sets of both; a workout with both keeps both items, with their planned sets; the merged record is deleted")
    func junction() throws {
        let store = try Self.makeOldStore()
        defer { removeTemporaryDirectory(store.directory) }
        let container = try ModelContainerFactory.makePersistent(at: store.url)
        let context = container.mainContext
        let before = try storeCounts(in: context)
        let result = try ExerciseLibrarySeeder(context: context).seed()

        #expect(result.mergedKeys == RetiredExercises.junctions.map(\.merged))
        let midID = try Self.id(of: Fixed.crossoverMid)
        let flyID = try Self.id(of: Fixed.flyCable)
        #expect(try Self.exercise(Fixed.crossoverMid, in: context) == nil)
        #expect(try Self.exercise(id: midID, in: context) == nil)
        let fly = try #require(try Self.exercise(Fixed.flyCable, in: context))
        #expect(fly.id.uuidString == flyID)
        #expect(fly.name == "Crucifixo (Polia)")
        // Every performed and planned item of both, none lost: 2 + 1 performed, 2 planned.
        #expect(fly.sessionExercises.count == 3)
        #expect(Set(fly.sessionExercises.map(\.exerciseNameSnapshot)) == ["Crucifixo (Polia)", "Crossover (Polia Média)"])
        let chest = try #require(fly.workoutExercises.first?.workout)
        #expect(chest.orderedExercises.count == 4)
        #expect(chest.orderedExercises.prefix(2).allSatisfy { $0.exercise?.id == fly.id })
        #expect(chest.orderedExercises.map { $0.orderedPlannedSets.count } == [2, 1, 1, 1])

        // The history: each session once, the first with the sets of both, in their order.
        let history = try ExerciseHistoryLoader(context: context).history(of: fly)
        #expect(history.entries.count == 2)
        let sets = history.entries.sorted { $0.startedAt < $1.startedAt }.map { $0.sets.map(\.weightKg) }
        #expect(sets == [[20, 21], [12]])

        // Nothing else is lost: one exercise less (the merged one) besides what the migration adds and deletes.
        let after = try storeCounts(in: context)
        for model in ["Workout", "WorkoutExercise", "PlannedSet", "Session", "SessionExercise", "SetLog"] {
            #expect(after[model] == before[model], "\(model)")
        }

        // In the session in progress, Elevação de Ponta dos Pés is now Panturrilha em Pé, with its set.
        let calf = try #require(try Self.exercise(Fixed.calfRaise, in: context))
        let active = try #require(calf.sessionExercises.first { $0.session?.isActive == true })
        #expect(active.exerciseNameSnapshot == "Elevação de Ponta dos Pés")
        #expect(active.orderedSetLogs.first?.reps == 12)
        #expect(try Self.exercise(Fixed.tibialis, in: context) == nil)
    }

    @Test("A junction waits while the exercise that stays is hidden, or its name is taken: the merged exercise keeps its history, and no two active exercises share a name")
    func junctionWaitsForAHiddenExercise() throws {
        for keptExists in [true, false] {
            let store = try Self.makeOldStore()
            defer { removeTemporaryDirectory(store.directory) }
            let container = try ModelContainerFactory.makePersistent(at: store.url)
            let context = container.mainContext
            // Panturrilha em Pé hidden by the person's exercise with its name, or not in the store at all.
            let calf = try #require(try Self.exercise(Fixed.calfRaise, in: context))
            if keptExists {
                calf.isArchived = true
            } else {
                context.delete(calf)
            }
            try ExerciseService(context: context).createCustomExercise(name: "Panturrilha em pé", muscleGroup: .calves)
            try context.save()

            let result = try ExerciseLibrarySeeder(context: context).seed()

            #expect(!result.mergedKeys.contains(Fixed.tibialis), "kept exists: \(keptExists)")
            let tibialis = try #require(try Self.exercise(Fixed.tibialis, in: context), "kept exists: \(keptExists)")
            #expect(tibialis.sessionExercises.count == 1, "kept exists: \(keptExists)")
            let hidden = try #require(try Self.exercise(Fixed.calfRaise, in: context))
            #expect(hidden.isArchived, "kept exists: \(keptExists)")
            #expect(hidden.sessionExercises.isEmpty, "kept exists: \(keptExists)")
            let active = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isArchived }))
            let names = active.map { Validation.comparisonKey(forName: $0.name) }
            #expect(Set(names).count == names.count, "Two active exercises share a name (kept exists: \(keptExists))")
            // The other junctions are done.
            #expect(result.mergedKeys.contains(Fixed.crossoverMid))
        }
    }

    @Test("Exercises that left the list: used ones (history, a planned workout or the session in progress) become the person's own with everything they had; unused ones are deleted")
    func retiredExercises() throws {
        let store = try Self.makeOldStore()
        defer { removeTemporaryDirectory(store.directory) }
        let container = try ModelContainerFactory.makePersistent(at: store.url)
        let context = container.mainContext
        let result = try ExerciseLibrarySeeder(context: context).seed()

        #expect(Set(result.convertedKeys) == [Fixed.guillotine, Fixed.gluteHam, Fixed.scissorKick, Fixed.deadBug])
        #expect(result.deletedKeys.count == 101)
        #expect(!result.deletedKeys.contains(Fixed.guillotine))
        let retired = Dictionary(uniqueKeysWithValues: RetiredExercises.all.map { ($0.key, $0) })
        for key in [Fixed.guillotine, Fixed.gluteHam, Fixed.scissorKick, Fixed.deadBug] {
            let entry = try #require(retired[key])
            let exercise = try #require(try Self.exercise(id: entry.id, in: context), "\(key)")
            #expect(exercise.isCustom && exercise.libraryKey == nil && !exercise.isArchived, "\(key)")
            #expect(exercise.name == entry.name && exercise.muscleGroup == entry.muscleGroup, "\(key)")
            #expect(exercise.equipment == entry.equipment, "\(key)")
            #expect(exercise.primaryMuscles == entry.primary && exercise.secondaryMuscles == entry.secondary, "\(key)")
            #expect(exercise.hasChosenMuscles, "\(key)")
            #expect(DefaultExerciseMuscles.muscles(of: exercise).primary == entry.primary, "\(key)")
        }
        // Done on a GHD bench: the kind of machine stays.
        let gluteHamID = try Self.id(of: Fixed.gluteHam)
        let gluteHam = try #require(try Self.exercise(id: gluteHamID, in: context))
        #expect(gluteHam.machineType == .ghd)
        #expect(DefaultExerciseMuscles.machine(of: gluteHam) == .ghd)
        // The history, the planned workout and the session in progress stay with the same records.
        let guillotineID = try Self.id(of: Fixed.guillotine)
        let guillotine = try #require(try Self.exercise(id: guillotineID, in: context))
        #expect(guillotine.sessionExercises.count == 1 && guillotine.workoutExercises.count == 1)
        let guillotineHistory = try ExerciseHistoryLoader(context: context).history(of: guillotine)
        #expect(guillotineHistory.entries.count == 1)
        let scissorID = try Self.id(of: Fixed.scissorKick)
        let scissor = try #require(try Self.exercise(id: scissorID, in: context))
        #expect(scissor.sessionExercises.isEmpty && scissor.workoutExercises.first?.workout?.name == "Ombro")
        let deadBugID = try Self.id(of: Fixed.deadBug)
        let deadBug = try #require(try Self.exercise(id: deadBugID, in: context))
        #expect(deadBug.sessionExercises.first?.session?.isActive == true)
        // An unused one is gone.
        let sissyID = try Self.id(of: Fixed.sissySquat)
        #expect(try Self.exercise(Fixed.sissySquat, in: context) == nil)
        #expect(try Self.exercise(id: sissyID, in: context) == nil)
        // No built-in record is left with a key the library does not have.
        let keys = Set(DefaultExerciseLibrary.all.map(\.key))
        let builtIn = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom }))
        #expect(builtIn.count == 1_525)
        #expect(builtIn.allSatisfy { $0.libraryKey.map(keys.contains) == true })
    }

    @Test("A new combination named like an exercise of the user's own is hidden; it comes back when the name is free, and the person's exercise is never changed")
    func combinationHiddenByACustomExercise() throws {
        let store = try Self.makeOldStore()
        defer { removeTemporaryDirectory(store.directory) }
        let container = try ModelContainerFactory.makePersistent(at: store.url)
        let context = container.mainContext
        let services = ServiceTestHarness(container: container)
        let result = try ExerciseLibrarySeeder(context: context).seed()

        let combination = try #require(try Self.exercise("supino-reto.kettlebell", in: context))
        #expect(combination.name == "Supino Reto (Kettlebell)")
        #expect(combination.isArchived)
        #expect(result.insertedKeys.contains("supino-reto.kettlebell"))
        let custom = try #require(try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "supino reto (kettlebell)" })).first)
        #expect(custom.isCustom && !custom.isArchived)

        // While the name is taken, the next launches keep it hidden and change nothing.
        #expect(try ExerciseLibrarySeeder(context: context).seed() == ExerciseLibrarySeedResult())
        #expect(combination.isArchived)

        // Renamed, the person's exercise frees the name: the combination comes back at once.
        let draft = ExerciseDraft(name: "Meu Supino Kettlebell", group: .chest, equipment: .other, primary: [.chest])
        try services.exercises.update(custom, with: draft)
        #expect(combination.isArchived == false)
        #expect(custom.name == "Meu Supino Kettlebell")
        #expect(try ModelContext(container).fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.libraryKey == "supino-reto.kettlebell" })).first?.isArchived == false)
    }

    @Test("Deleting the exercise of the user's own that hid a combination shows it again; archiving it keeps the name reserved and the combination hidden")
    func combinationComesBackWhenTheCustomIsDeleted() throws {
        let harness = try ServiceTestHarness()
        let custom = try harness.exercises.createCustomExercise(name: "Supino Reto (Kettlebell)", muscleGroup: .chest)
        try ExerciseLibrarySeeder(context: harness.context, now: harness.clock.now).seed()
        let combination = try #require(try Self.exercise("supino-reto.kettlebell", in: harness.context))
        #expect(combination.isArchived)

        // Without history, removing it deletes it: the name is free.
        #expect(try harness.exercises.remove(custom) == .deleted)
        #expect(combination.isArchived == false)
    }

    @Test("Archiving the exercise of the user's own keeps the combination hidden; the seeder shows it once the archived one is deleted")
    func archivedCustomKeepsTheNameReserved() throws {
        let harness = try ServiceTestHarness()
        let seeder = ExerciseLibrarySeeder(context: harness.context, now: harness.clock.now)
        let custom = try harness.exercises.createCustomExercise(name: "Supino Reto (Kettlebell)", muscleGroup: .chest)
        let workout = try harness.makeWorkout(name: "Push", items: [(custom, [.reps(8, 10)])])
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(session.orderedExercises[0].orderedSetLogs[0], weightKg: 20, reps: 8)
        try harness.sessions.finishSession(session)
        try seeder.seed()
        let combination = try #require(try Self.exercise("supino-reto.kettlebell", in: harness.context))

        #expect(try harness.exercises.remove(custom, confirmedWorkoutIDs: [workout.id]) == .archived)
        #expect(combination.isArchived)
        #expect(try seeder.seed() == ExerciseLibrarySeedResult())
        #expect(combination.isArchived)

        // Gone from the store some other way (no history left), the name is free for the next launch.
        harness.context.delete(session)
        harness.context.delete(custom)
        try harness.context.save()
        let result = try seeder.seed()
        #expect(result.revealedKeys == ["supino-reto.kettlebell"])
        #expect(combination.isArchived == false)
    }

    @Test("The migration runs once: the next launches change nothing and save nothing")
    func runsOnce() throws {
        let store = try Self.makeOldStore()
        defer { removeTemporaryDirectory(store.directory) }
        do {
            let container = try ModelContainerFactory.makePersistent(at: store.url)
            try ExerciseLibrarySeeder(context: container.mainContext).seed()
        }
        for _ in 0..<2 {
            let container = try ModelContainerFactory.makePersistent(at: store.url)
            let before = try storeCounts(in: container.mainContext)
            #expect(try ExerciseLibrarySeeder(context: container.mainContext).seed() == ExerciseLibrarySeedResult())
            #expect(container.mainContext.hasChanges == false)
            #expect(try storeCounts(in: container.mainContext) == before)
        }
    }

    @Test("If saving fails, or the app closes before saving, the store stays as it was, and the next launch migrates it as if nothing had happened")
    func interruptedMigration() throws {
        let store = try Self.makeOldStore()
        defer { removeTemporaryDirectory(store.directory) }
        let schema = ModelContainerFactory.schema
        let before: [String: Int]
        do {
            let container = try ModelContainerFactory.makePersistent(at: store.url)
            before = try storeCounts(in: container.mainContext)
        }

        // The same store, read-only: the whole migration is done in memory, and saving it is refused.
        do {
            let readOnly = try ModelContainer(
                for: schema,
                migrationPlan: IronFlowMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: store.url, allowsSave: false, cloudKitDatabase: .none)]
            )
            readOnly.mainContext.autosaveEnabled = false
            #expect(throws: SaveError.self) { try ExerciseLibrarySeeder(context: readOnly.mainContext).seed() }
            #expect(readOnly.mainContext.hasChanges == false)
            // Read again, nothing was written: the merged and the retired exercises are still there.
            let fresh = ModelContext(readOnly)
            #expect(try storeCounts(in: fresh) == before)
            #expect(try Self.exercise(Fixed.crossoverMid, in: fresh) != nil)
            #expect(try Self.exercise(Fixed.guillotine, in: fresh)?.isCustom == false)
        }

        // The app is opened again: the migration runs whole, once.
        let container = try ModelContainerFactory.makePersistent(at: store.url)
        let context = container.mainContext
        let result = try ExerciseLibrarySeeder(context: context).seed()
        #expect(result.mergedKeys == RetiredExercises.junctions.map(\.merged))
        #expect(result.convertedKeys.count == 4)
        let fly = try #require(try Self.exercise(Fixed.flyCable, in: context))
        #expect(fly.sessionExercises.count == 3)
        #expect(try ExerciseLibrarySeeder(context: context).seed() == ExerciseLibrarySeedResult())
    }

    @Test("Exercises of the user's own are never changed by the migration")
    func customExercisesUntouched() throws {
        let store = try Self.makeOldStore()
        defer { removeTemporaryDirectory(store.directory) }
        let container = try ModelContainerFactory.makePersistent(at: store.url)
        let context = container.mainContext
        let customsBefore = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom }))
            .map { [$0.id.uuidString, $0.name, $0.muscleGroupRaw, "\($0.updatedAt.timeIntervalSinceReferenceDate)", "\($0.isArchived)"] }
        try ExerciseLibrarySeeder(context: context).seed()
        let retiredIDs = Set(RetiredExercises.all.map(\.id))
        let customsAfter = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isCustom }))
            .filter { !retiredIDs.contains($0.id.uuidString) }
            .map { [$0.id.uuidString, $0.name, $0.muscleGroupRaw, "\($0.updatedAt.timeIntervalSinceReferenceDate)", "\($0.isArchived)"] }
        #expect(Set(customsAfter) == Set(customsBefore))
        #expect(customsAfter.count == 2)
    }

    @Test("The Graviton exercises stay out of the kg lifted, and the new Graviton combinations too")
    func gravitonStaysAssisted() throws {
        let harness = try ServiceTestHarness()
        try ExerciseLibrarySeeder(context: harness.context, now: harness.clock.now).seed()
        for key in ["assisted-pull-up", "assisted-chin-up", "assisted-chest-dips", "assisted-dips", "barra-fixa.graviton.fechada", "barra-fixa.graviton.neutra"] {
            let exercise = try #require(try Self.exercise(key, in: harness.context), "\(key)")
            #expect(DefaultExerciseMuscles.isAssisted(exercise), "\(key)")
        }
        let pullUp = try #require(try Self.exercise("pull-up", in: harness.context))
        #expect(DefaultExerciseMuscles.isAssisted(pullUp) == false)
    }

    // MARK: - Time

    /// Not a limit, a measure (the owner asked to be told if it passes 1 s): how long the first launch after
    /// the update takes to migrate a store of 420 with history, and a new install to insert the 1,525.
    @Test("The time of the migration on the first launch after the update, and of a new install, is printed")
    func migrationTime() throws {
        let clock = ContinuousClock()
        var migration: [Duration] = []
        var install: [Duration] = []
        for _ in 0..<5 {
            let store = try Self.makeOldStore()
            defer { removeTemporaryDirectory(store.directory) }
            let start = clock.now
            let container = try ModelContainerFactory.makePersistent(at: store.url)
            let result = try ExerciseLibrarySeeder(context: container.mainContext).seed()
            migration.append(start.duration(to: clock.now))
            #expect(result.insertedKeys.count == 1_214)

            let directory = try makeTemporaryDirectory()
            defer { removeTemporaryDirectory(directory) }
            let newStart = clock.now
            let newContainer = try ModelContainerFactory.makePersistent(at: directory.appending(path: "IronFlow.store"))
            let newResult = try ExerciseLibrarySeeder(context: newContainer.mainContext).seed()
            install.append(newStart.duration(to: clock.now))
            #expect(newResult.insertedKeys.count == 1_525)
        }
        let m = migration.sorted()
        let i = install.sorted()
        print("MEDIÇÃO migração na primeira abertura (420 → 1.525, com histórico, abrir o banco e semear, 5 vezes): mediana \(m[2]), mínimo \(m[0]), máximo \(m[4])")
        print("MEDIÇÃO instalação nova (banco vazio → 1.525, abrir o banco e semear, 5 vezes): mediana \(i[2]), mínimo \(i[0]), máximo \(i[4])")
    }
}
