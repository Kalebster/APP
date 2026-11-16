import Foundation
import SwiftData
import Testing
@testable import IronFlow

@MainActor
struct ExerciseLibrarySeederTests {
    let harness: ServiceTestHarness
    let seeder: ExerciseLibrarySeeder
    let library = DefaultExerciseLibrary.all

    init() throws {
        harness = try ServiceTestHarness()
        seeder = ExerciseLibrarySeeder(context: harness.context, now: harness.clock.now)
    }

    private func systemExercises() throws -> [Exercise] {
        try harness.context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom }))
    }

    private func exercise(key: String) throws -> Exercise? {
        try harness.context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.libraryKey == key })).first
    }

    private static let entryA = DefaultExercise(key: "test-a", id: "0A000000-0000-4000-8000-00000000000A", name: "Teste A", muscleGroup: .chest)
    private static let entryB = DefaultExercise(key: "test-b", id: "0B000000-0000-4000-8000-00000000000B", name: "Teste B", muscleGroup: .back)
    private static let entryC = DefaultExercise(key: "test-c", id: "0C000000-0000-4000-8000-00000000000C", name: "Teste C", muscleGroup: .biceps)

    /// Seeds `first` and then `second` in a store of its own, with a custom exercise named `customName`
    /// created between the two runs. Returns the store, its built-in exercises by key, the custom exercise,
    /// the second run's result and the result of seeding `second` once more.
    private static func upgrade(
        from first: [DefaultExercise],
        to second: [DefaultExercise],
        customName: String? = nil
    ) throws -> (
        harness: ServiceTestHarness,
        exercises: [String: Exercise],
        custom: Exercise?,
        result: ExerciseLibrarySeedResult,
        again: ExerciseLibrarySeedResult
    ) {
        let harness = try ServiceTestHarness()
        let seeder = ExerciseLibrarySeeder(context: harness.context, now: harness.clock.now)
        try seeder.seed(first)
        let custom = try customName.map { try harness.exercises.createCustomExercise(name: $0, muscleGroup: .other) }
        harness.clock.advance(by: 60)
        let result = try seeder.seed(second)
        let again = try seeder.seed(second)
        let stored = try harness.context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom }))
        let exercises = Dictionary(uniqueKeysWithValues: stored.map { ($0.libraryKey ?? "", $0) })
        return (harness, exercises, custom, result, again)
    }

    // MARK: - Installation

    @Test("A new install gets the whole library, active, with the fixed ids, names and groups")
    func freshInstall() throws {
        let result = try seeder.seed()

        #expect(result.insertedKeys.count == 420)
        #expect(result.updatedKeys.isEmpty && result.skippedKeys.isEmpty)
        let stored = try systemExercises()
        #expect(stored.count == 420)
        let byKey = Dictionary(uniqueKeysWithValues: stored.map { ($0.libraryKey ?? "", $0) })
        for entry in library {
            let exercise = try #require(byKey[entry.key])
            #expect(exercise.id.uuidString == entry.id)
            #expect(exercise.name == entry.name)
            #expect(exercise.muscleGroup == entry.muscleGroup)
            #expect(exercise.isCustom == false)
            #expect(exercise.isArchived == false)
            #expect(exercise.createdAt == harness.clock.current)
            #expect(exercise.updatedAt == harness.clock.current)
        }
        #expect(harness.context.hasChanges == false)
    }

    @Test("Seeding again creates or changes nothing and does not save")
    func idempotent() throws {
        try seeder.seed()
        let updatedAt = try systemExercises().map(\.updatedAt)
        harness.clock.advance(by: 3_600)

        for _ in 0..<3 {
            #expect(try seeder.seed() == ExerciseLibrarySeedResult())
            #expect(harness.context.hasChanges == false)
        }
        #expect(try count(Exercise.self, in: harness.context) == 420)
        #expect(try systemExercises().map(\.updatedAt) == updatedAt)
    }

    @Test("Seeding after closing and reopening the store on disk does not duplicate")
    func idempotentAfterReopening() throws {
        try roundTripThroughDisk { context in
            try ExerciseLibrarySeeder(context: context).seed()
        } read: { context in
            #expect(try ExerciseLibrarySeeder(context: context).seed() == ExerciseLibrarySeedResult())
            let stored = try context.fetch(FetchDescriptor<Exercise>())
            #expect(stored.count == 420)
            #expect(Set(stored.map(\.id.uuidString)) == Set(library.map(\.id)))
        }
    }

    /// Not a limit, a measure: how long seeding takes when the app opens with the library already
    /// installed (nothing to insert or correct), each time from a store on disk opened again.
    @Test("Seeding on a normal launch, with the 420 already in the store on disk, changes nothing (its time is printed)")
    func seedTimeOnANormalLaunch() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let url = directory.appending(path: "IronFlow.store")
        do {
            let container = try ModelContainerFactory.makePersistent(at: url)
            try ExerciseLibrarySeeder(context: container.mainContext).seed()
        }
        let clock = ContinuousClock()
        var durations: [Duration] = []
        for _ in 0..<5 {
            let container = try ModelContainerFactory.makePersistent(at: url)
            let seeder = ExerciseLibrarySeeder(context: container.mainContext)
            let start = clock.now
            let result = try seeder.seed()
            durations.append(start.duration(to: clock.now))
            #expect(result == ExerciseLibrarySeedResult())
            #expect(container.mainContext.hasChanges == false)
            #expect(try count(Exercise.self, in: container.mainContext) == 420)
        }
        let sorted = durations.sorted()
        print("Medição do seed numa abertura normal (\(library.count) exercícios, 5 aberturas): mediana \(sorted[2]), mínimo \(sorted[0]), máximo \(sorted[4])")
    }

    // MARK: - User data

    @Test("Custom exercises are not changed")
    func customExercisesPreserved() throws {
        let custom = try harness.exercises.createCustomExercise(name: "Meu Exercício", muscleGroup: .other)
        let workout = try harness.makeWorkout(name: "Meu Treino", items: [(custom, [.reps(8, 10)])])
        harness.clock.advance(by: 60)

        try seeder.seed()

        #expect(custom.name == "Meu Exercício")
        #expect(custom.isCustom)
        #expect(custom.libraryKey == nil)
        #expect(custom.updatedAt == custom.createdAt)
        #expect(workout.orderedExercises.first?.exercise?.id == custom.id)
        #expect(try count(Exercise.self, in: harness.context) == 421)
    }

    @Test("A built-in exercise named like an active custom one is created archived")
    func nameClashWithActiveCustom() throws {
        let custom = try harness.exercises.createCustomExercise(name: "supino reto (barra)", muscleGroup: .chest)

        try seeder.seed()

        let builtIn = try #require(try exercise(key: "bench-press-barbell"))
        #expect(builtIn.isArchived)
        #expect(custom.isArchived == false)
        #expect(custom.name == "supino reto (barra)")
        let others = try systemExercises().filter { $0.libraryKey != "bench-press-barbell" }
        #expect(others.allSatisfy { !$0.isArchived })
    }

    @Test("A built-in exercise named like an active built-in exercise kept from an older library is created archived")
    func nameClashWithKeptBuiltIn() throws {
        // "test-a" left the library in a later version but stays active in the store.
        try seeder.seed([Self.entryA])
        let kept = try #require(try exercise(key: "test-a"))
        let renamedSuccessor = DefaultExercise(key: "test-b", id: Self.entryB.id, name: "teste a", muscleGroup: .chest)

        try seeder.seed([renamedSuccessor])

        #expect(try exercise(key: "test-b")?.isArchived == true)
        #expect(kept.isArchived == false)
    }

    @Test("A built-in exercise named like an archived custom one is created active")
    func nameClashWithArchivedCustom() throws {
        let custom = try harness.exercises.createCustomExercise(name: "Supino Reto (Barra)", muscleGroup: .chest)
        try harness.exercises.archive(custom)

        try seeder.seed()

        #expect(try exercise(key: "bench-press-barbell")?.isArchived == false)
        #expect(custom.isArchived)
    }

    @Test("A built-in exercise hidden by the user stays hidden")
    func userArchivePreserved() throws {
        try seeder.seed()
        let bench = try #require(try exercise(key: "bench-press-barbell"))
        try harness.exercises.archive(bench)

        try seeder.seed()
        #expect(bench.isArchived)
    }

    @Test("Built-in exercises used in workouts and sessions keep their links and history")
    func usedExercisesPreserved() throws {
        try seeder.seed()
        let bench = try #require(try exercise(key: "bench-press-barbell"))
        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10, kg: 40)])])
        let session = try harness.sessions.startSession(from: workout)
        try harness.sessions.completeSet(session.orderedExercises[0].orderedSetLogs[0], weightKg: 40, reps: 9)
        let before = try storeCounts(in: harness.context)

        try seeder.seed()

        #expect(try storeCounts(in: harness.context) == before)
        #expect(workout.orderedExercises[0].exercise?.id == bench.id)
        #expect(session.orderedExercises[0].exercise?.id == bench.id)
        #expect(session.orderedExercises[0].exerciseNameSnapshot == "Supino Reto (Barra)")
        #expect(session.orderedExercises[0].orderedSetLogs[0].reps == 9)
    }

    // MARK: - Library updates

    @Test("A store with the first library (71) gets the 420: 67 names and 5 groups corrected with the same ids, the new Agachamento Búlgaro active with the name the old one leaves, workouts and history linked as before, custom exercises untouched; seeding again changes nothing")
    func upgradeFromTheFirstLibrary() throws {
        try seeder.seed(LibraryV1Fixture.entries)
        let idsBefore = Dictionary(uniqueKeysWithValues: try systemExercises().map { ($0.libraryKey ?? "", $0.id) })
        #expect(idsBefore.count == 71)
        // A renamed exercise and a regrouped one in a workout with a custom one, and a session of it.
        let pullUp = try #require(try exercise(key: "pull-up"))
        let deadlift = try #require(try exercise(key: "deadlift"))
        let custom = try harness.exercises.createCustomExercise(name: "Meu Terra", muscleGroup: .hamstrings)
        let customUpdatedAt = custom.updatedAt
        let workout = try harness.makeWorkout(name: "Costas", items: [
            (pullUp, [.reps(6, 8)]), (deadlift, [.reps(5, 5, kg: 100)]), (custom, [.reps(8, 10)]),
        ])
        let session = try harness.sessions.startSession(from: workout)
        // A set of each exercise done, so the history keeps all three.
        for (performed, reps) in zip(session.orderedExercises, [8, 5, 10]) {
            try harness.sessions.completeSet(performed.orderedSetLogs[0], weightKg: nil, reps: reps)
        }
        try harness.sessions.finishSession(session)
        harness.clock.advance(by: 3_600)

        let result = try seeder.seed()

        let oldKeys = Set(LibraryV1Fixture.entries.map(\.key))
        let newKeys = Set(library.map(\.key)).subtracting(oldKeys)
        #expect(newKeys.count == 349)
        #expect(Set(result.insertedKeys) == newKeys)
        let corrected = LibraryV1Fixture.entries.filter { old in
            let entry = DefaultExerciseLibrary.byKey[old.key]
            return entry?.name != old.name || entry?.muscleGroup != old.muscleGroup
        }
        #expect(corrected.count == 67)
        #expect(Set(result.updatedKeys) == Set(corrected.map(\.key)))
        #expect(result.skippedKeys.isEmpty && result.keptNameKeys.isEmpty)

        // Every built-in exercise follows the library, active, and the first 71 keep their ids.
        let stored = try systemExercises()
        #expect(stored.count == 420)
        let byKey = Dictionary(uniqueKeysWithValues: stored.map { ($0.libraryKey ?? "", $0) })
        for entry in library {
            let exercise = try #require(byKey[entry.key])
            #expect(exercise.id.uuidString == entry.id)
            #expect(exercise.name == entry.name)
            #expect(exercise.muscleGroup == entry.muscleGroup)
            #expect(exercise.isArchived == false)
        }
        for (key, id) in idsBefore {
            #expect(byKey[key]?.id == id)
        }

        // The workout uses the same records, now with the corrected name and group.
        #expect(workout.orderedExercises.map { $0.exercise?.id } == [pullUp.id, deadlift.id, custom.id])
        #expect(pullUp.name == "Barra Fixa (Pegada Aberta)")
        #expect(deadlift.muscleGroup == .lowerBack)
        // The first library's "Agachamento Búlgaro" takes the name with its equipment, and the new bodyweight
        // one takes the name it leaves, active: the names are decided with those of the end of the run.
        #expect(byKey["bulgarian-split-squat"]?.name == "Agachamento Búlgaro (Halter)")
        #expect(byKey["bulgarian-split-squat-bodyweight"]?.name == "Agachamento Búlgaro")
        #expect(byKey["bulgarian-split-squat-bodyweight"]?.isArchived == false)
        // The history keeps what was recorded then, linked to the same records.
        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Barra Fixa", "Levantamento Terra", "Meu Terra"])
        #expect(session.orderedExercises.map(\.muscleGroupSnapshot) == [.back, .hamstrings, .hamstrings])
        #expect(session.orderedExercises.map { $0.exercise?.id } == [pullUp.id, deadlift.id, custom.id])
        #expect(session.orderedExercises[0].orderedSetLogs[0].reps == 8)
        // The custom exercise is untouched.
        #expect(custom.name == "Meu Terra")
        #expect(custom.muscleGroup == .hamstrings)
        #expect(custom.isCustom && custom.libraryKey == nil && !custom.isArchived)
        #expect(custom.updatedAt == customUpdatedAt)

        harness.clock.advance(by: 3_600)
        #expect(try seeder.seed() == ExerciseLibrarySeedResult())
        #expect(harness.context.hasChanges == false)
        #expect(try count(Exercise.self, in: harness.context) == 421)
    }

    @Test("A store with the library of 157, with workouts, sessions and a custom exercise stored with back, gets the 420: 144 names and 13 groups corrected, the 263 new ones active, nothing skipped, kept with the old name, archived or deleted, the same ids, workouts and history; seeding again changes nothing")
    func upgradeFromTheLibraryOf157() throws {
        try seeder.seed(Library157Fixture.entries)
        let before = try systemExercises()
        #expect(before.count == 157)
        let idsBefore = Dictionary(uniqueKeysWithValues: before.map { ($0.libraryKey ?? "", $0.id) })
        let createdBefore = Dictionary(uniqueKeysWithValues: before.map { ($0.libraryKey ?? "", $0.createdAt) })
        let updatedBefore = Dictionary(uniqueKeysWithValues: before.map { ($0.libraryKey ?? "", $0.updatedAt) })

        // Exercises renamed only, renamed and moved to another group (Dorsais, Costas superiores, Lombar
        // and Adutores) and unchanged, with a custom exercise stored with back, in two workouts.
        let pullUp = try #require(try exercise(key: "pull-up"))
        let row = try #require(try exercise(key: "bent-over-row-barbell"))
        let pullover = try #require(try exercise(key: "pullover-dumbbell"))
        let deadlift = try #require(try exercise(key: "deadlift"))
        let adduction = try #require(try exercise(key: "hip-adduction-machine"))
        let bridge = try #require(try exercise(key: "glute-bridge"))
        let custom = try harness.exercises.createCustomExercise(name: "Minha Remada", muscleGroup: .back)
        let customUpdatedAt = custom.updatedAt
        let pull = try harness.makeWorkout(name: "Pull", items: [
            (pullUp, [.reps(6, 8)]), (row, [.reps(8, 10, kg: 60)]), (pullover, [.reps(10, 12, kg: 20)]),
            (custom, [.reps(10, 12)]),
        ])
        let legs = try harness.makeWorkout(name: "Pernas", items: [
            (deadlift, [.reps(5, 5, kg: 100), .reps(5, 5, kg: 100)]), (adduction, [.reps(12, 15, kg: 40)]),
            (bridge, [.reps(12, 15)]),
        ])
        // A finished session of each workout, with a set of every exercise done.
        var sessions: [Session] = []
        for workout in [pull, legs] {
            let session = try harness.sessions.startSession(from: workout)
            for performed in session.orderedExercises {
                try harness.sessions.completeSet(performed.orderedSetLogs[0], weightKg: 30, reps: 8)
            }
            try harness.sessions.finishSession(session)
            sessions.append(session)
        }
        let countsBefore = try storeCounts(in: harness.context)
        harness.clock.advance(by: 3_600)

        let result = try seeder.seed()

        let oldKeys = Set(Library157Fixture.entries.map(\.key))
        let newKeys = Set(library.map(\.key)).subtracting(oldKeys)
        #expect(newKeys.count == 263)
        #expect(result.insertedKeys.count == 263)
        #expect(Set(result.insertedKeys) == newKeys)
        let corrected = Library157Fixture.entries.filter { old in
            let entry = DefaultExerciseLibrary.byKey[old.key]
            return entry?.name != old.name || entry?.muscleGroup != old.muscleGroup
        }
        #expect(corrected.count == 144)
        #expect(result.updatedKeys.count == 144)
        #expect(Set(result.updatedKeys) == Set(corrected.map(\.key)))
        #expect(result.skippedKeys.isEmpty)
        #expect(result.keptNameKeys.isEmpty)

        // Every built-in exercise follows the library, active; the 157 keep their records and ids, and
        // only the corrected ones change their update time.
        let stored = try systemExercises()
        #expect(stored.count == 420)
        let byKey = Dictionary(uniqueKeysWithValues: stored.map { ($0.libraryKey ?? "", $0) })
        let correctedKeys = Set(corrected.map(\.key))
        for entry in library {
            let exercise = try #require(byKey[entry.key])
            #expect(exercise.id.uuidString == entry.id)
            #expect(exercise.name == entry.name)
            #expect(exercise.muscleGroup == entry.muscleGroup)
            #expect(exercise.isArchived == false, "Archived: \(entry.key)")
            #expect(exercise.isCustom == false)
            if let id = idsBefore[entry.key] {
                #expect(exercise.id == id)
                #expect(exercise.createdAt == createdBefore[entry.key])
                let expectedUpdate = correctedKeys.contains(entry.key) ? harness.clock.current : updatedBefore[entry.key]
                #expect(exercise.updatedAt == expectedUpdate, "Update time of \(entry.key)")
            } else {
                #expect(exercise.createdAt == harness.clock.current)
            }
        }

        // Nothing deleted or added besides the 263 exercises.
        var countsAfter = countsBefore
        countsAfter["Exercise", default: 0] += 263
        #expect(try storeCounts(in: harness.context) == countsAfter)

        // The workouts use the same records, with the same planned sets, now with the new names and groups.
        let pullIDs: [UUID?] = [pullUp.id, row.id, pullover.id, custom.id]
        let legsIDs: [UUID?] = [deadlift.id, adduction.id, bridge.id]
        #expect(pull.orderedExercises.map { $0.exercise?.id } == pullIDs)
        #expect(legs.orderedExercises.map { $0.exercise?.id } == legsIDs)
        #expect(legs.orderedExercises.map { $0.orderedPlannedSets.count } == [2, 1, 1])
        #expect([pullUp, row, pullover, deadlift, adduction, bridge].map(\.name) == [
            "Barra Fixa (Pegada Aberta)", "Remada Curvada (Barra)", "Pullover (Halter)", "Levantamento Terra (Barra)",
            "Cadeira Adutora (Máquina)", "Ponte de Glúteo",
        ])
        #expect([pullUp, row, pullover, deadlift, adduction, bridge].map(\.muscleGroup) == [
            .back, .upperBack, .back, .lowerBack, .adductors, .glutes,
        ])

        // The history keeps what was recorded that day, linked to the same records.
        #expect(sessions[0].orderedExercises.map(\.exerciseNameSnapshot) == [
            "Barra Fixa Pronada", "Remada Curvada com Barra", "Pullover com Halter", "Minha Remada",
        ])
        #expect(sessions[0].orderedExercises.map(\.muscleGroupSnapshot) == [.back, .back, .chest, .back])
        #expect(sessions[1].orderedExercises.map(\.exerciseNameSnapshot) == ["Levantamento Terra", "Cadeira Adutora", "Ponte de Glúteo"])
        #expect(sessions[1].orderedExercises.map(\.muscleGroupSnapshot) == [.back, .glutes, .glutes])
        #expect(sessions[0].orderedExercises.map { $0.exercise?.id } == pullIDs)
        #expect(sessions[1].orderedExercises.map { $0.exercise?.id } == legsIDs)
        for session in sessions {
            #expect(session.orderedExercises.allSatisfy { $0.orderedSetLogs[0].reps == 8 && $0.orderedSetLogs[0].weightKg == 30 })
        }

        // The custom exercise is untouched, still stored as back, and read as Dorsais.
        #expect(custom.name == "Minha Remada")
        #expect(custom.muscleGroupRaw == "back")
        #expect(String(localized: custom.muscleGroup.displayName) == "Dorsais")
        #expect(custom.isCustom && custom.libraryKey == nil && !custom.isArchived)
        #expect(custom.updatedAt == customUpdatedAt)

        harness.clock.advance(by: 3_600)
        #expect(try seeder.seed() == ExerciseLibrarySeedResult())
        #expect(harness.context.hasChanges == false)
        #expect(try count(Exercise.self, in: harness.context) == 421)
    }


    @Test("A store with the library of 220, with a workout, a session and a custom exercise, gets the 420: the 200 new ones active, Remada Alta (Máquina) renamed, nothing skipped, kept, archived or deleted, ids and history as before; seeding again changes nothing")
    func upgradeFromTheLibraryOf220() throws {
        try seeder.seed(Library220Fixture.entries)
        let before = try systemExercises()
        #expect(before.count == 220)
        let idsBefore = Dictionary(uniqueKeysWithValues: before.map { ($0.libraryKey ?? "", $0.id) })
        let createdBefore = Dictionary(uniqueKeysWithValues: before.map { ($0.libraryKey ?? "", $0.createdAt) })
        let updatedBefore = Dictionary(uniqueKeysWithValues: before.map { ($0.libraryKey ?? "", $0.updatedAt) })

        // The renamed exercise and an unchanged one in a workout with a custom exercise, and a session of it.
        let highRow = try #require(try exercise(key: "high-row-machine"))
        let bench = try #require(try exercise(key: "bench-press-barbell"))
        let custom = try harness.exercises.createCustomExercise(name: "Minha Remada Alta", muscleGroup: .back)
        let customUpdatedAt = custom.updatedAt
        let workout = try harness.makeWorkout(name: "Costas", items: [
            (highRow, [.reps(8, 10, kg: 50)]), (bench, [.reps(6, 8, kg: 80)]), (custom, [.reps(10, 12)]),
        ])
        let session = try harness.sessions.startSession(from: workout)
        for performed in session.orderedExercises {
            try harness.sessions.completeSet(performed.orderedSetLogs[0], weightKg: 30, reps: 8)
        }
        try harness.sessions.finishSession(session)
        let countsBefore = try storeCounts(in: harness.context)
        harness.clock.advance(by: 3_600)

        let result = try seeder.seed()

        let newKeys = Set(library.map(\.key)).subtracting(idsBefore.keys)
        #expect(newKeys.count == 200)
        #expect(result.insertedKeys == library.map(\.key).filter { newKeys.contains($0) })
        #expect(result.updatedKeys == ["high-row-machine"])
        #expect(result.skippedKeys.isEmpty)
        #expect(result.keptNameKeys.isEmpty)

        // Every built-in exercise follows the library, active; the 220 keep their records and ids, and only
        // the renamed one changes its update time.
        let stored = try systemExercises()
        #expect(stored.count == 420)
        let byKey = Dictionary(uniqueKeysWithValues: stored.map { ($0.libraryKey ?? "", $0) })
        for entry in library {
            let exercise = try #require(byKey[entry.key])
            #expect(exercise.id.uuidString == entry.id)
            #expect(exercise.name == entry.name)
            #expect(exercise.muscleGroup == entry.muscleGroup)
            #expect(exercise.isArchived == false, "Archived: \(entry.key)")
            #expect(exercise.isCustom == false)
            if let id = idsBefore[entry.key] {
                #expect(exercise.id == id)
                #expect(exercise.createdAt == createdBefore[entry.key])
                let expectedUpdate = entry.key == "high-row-machine" ? harness.clock.current : updatedBefore[entry.key]
                #expect(exercise.updatedAt == expectedUpdate, "Update time of \(entry.key)")
            } else {
                #expect(exercise.createdAt == harness.clock.current)
            }
        }

        // Nothing deleted or added besides the 200 exercises.
        var countsAfter = countsBefore
        countsAfter["Exercise", default: 0] += 200
        #expect(try storeCounts(in: harness.context) == countsAfter)

        // The workout uses the same records; the history keeps the name of that day.
        #expect(highRow.name == "Remada Alta Articulada (Máquina)")
        #expect(workout.orderedExercises.map { $0.exercise?.id } == [highRow.id, bench.id, custom.id])
        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Remada Alta (Máquina)", "Supino Reto (Barra)", "Minha Remada Alta"])
        #expect(session.orderedExercises.map { $0.exercise?.id } == [highRow.id, bench.id, custom.id])
        #expect(session.orderedExercises.allSatisfy { $0.orderedSetLogs[0].reps == 8 && $0.orderedSetLogs[0].weightKg == 30 })
        #expect(custom.name == "Minha Remada Alta")
        #expect(custom.isCustom && custom.libraryKey == nil && !custom.isArchived)
        #expect(custom.updatedAt == customUpdatedAt)

        harness.clock.advance(by: 3_600)
        #expect(try seeder.seed() == ExerciseLibrarySeedResult())
        #expect(harness.context.hasChanges == false)
        #expect(try count(Exercise.self, in: harness.context) == 421)
    }

    @Test("A corrected name or group in a later library updates the built-in exercise, not the history")
    func libraryCorrection() throws {
        try seeder.seed([Self.entryA])
        let exercise = try #require(try exercise(key: "test-a"))
        let workout = try harness.makeWorkout(name: "Push", items: [(exercise, [.reps(8, 10)])])
        let session = try harness.sessions.startSession(from: workout)
        harness.clock.advance(by: 60)

        let corrected = DefaultExercise(key: "test-a", id: Self.entryA.id, name: "Teste A Corrigido", muscleGroup: .shoulders)
        let result = try seeder.seed([corrected])

        #expect(result.updatedKeys == ["test-a"])
        #expect(exercise.name == "Teste A Corrigido")
        #expect(exercise.muscleGroup == .shoulders)
        #expect(exercise.updatedAt == harness.clock.current)
        #expect(exercise.id.uuidString == Self.entryA.id)
        #expect(session.orderedExercises[0].exerciseNameSnapshot == "Teste A")
        #expect(session.orderedExercises[0].muscleGroupSnapshot == .chest)
    }

    @Test("A correction never changes whether the user archived the exercise")
    func correctionKeepsArchive() throws {
        try seeder.seed([Self.entryA])
        let exercise = try #require(try exercise(key: "test-a"))
        try harness.exercises.archive(exercise)

        try seeder.seed([DefaultExercise(key: "test-a", id: Self.entryA.id, name: "Outro Nome", muscleGroup: .back)])
        #expect(exercise.isArchived)
    }

    @Test("A corrected name already used by another active exercise is not applied: the old name stays, the group is still corrected, and it is reported")
    func correctedNameClash() throws {
        try seeder.seed([Self.entryA])
        let exercise = try #require(try exercise(key: "test-a"))
        let custom = try harness.exercises.createCustomExercise(name: "Teste A Corrigido", muscleGroup: .biceps)
        harness.clock.advance(by: 60)

        // Only the name is corrected: nothing changes or is saved, and the clash is reported.
        let nameOnly = try seeder.seed([DefaultExercise(key: "test-a", id: Self.entryA.id, name: "Teste A Corrigido", muscleGroup: .chest)])
        #expect(nameOnly == ExerciseLibrarySeedResult(keptNameKeys: ["test-a"]))
        #expect(exercise.name == "Teste A")
        #expect(harness.context.hasChanges == false)

        // The name and the group are corrected: the group is applied, the name is kept.
        let both = try seeder.seed([DefaultExercise(key: "test-a", id: Self.entryA.id, name: "Teste A Corrigido", muscleGroup: .shoulders)])
        #expect(both.updatedKeys == ["test-a"])
        #expect(both.keptNameKeys == ["test-a"])
        #expect(exercise.name == "Teste A")
        #expect(exercise.muscleGroup == .shoulders)
        #expect(exercise.updatedAt == harness.clock.current)
        #expect(custom.name == "Teste A Corrigido")
        #expect(exercise.isArchived == false && custom.isArchived == false)
    }

    @Test("A corrected name used only by an archived exercise is applied, and an archived built-in exercise takes any corrected name")
    func correctedNameWithoutActiveClash() throws {
        try seeder.seed([Self.entryA, Self.entryB])
        let first = try #require(try exercise(key: "test-a"))
        let second = try #require(try exercise(key: "test-b"))
        let archivedCustom = try harness.exercises.createCustomExercise(name: "Nome Livre", muscleGroup: .biceps)
        try harness.exercises.archive(archivedCustom)
        try harness.exercises.createCustomExercise(name: "Nome Usado", muscleGroup: .biceps)
        try harness.exercises.archive(second)

        let result = try seeder.seed([
            DefaultExercise(key: "test-a", id: Self.entryA.id, name: "Nome Livre", muscleGroup: .chest),
            DefaultExercise(key: "test-b", id: Self.entryB.id, name: "Nome Usado", muscleGroup: .back),
        ])

        #expect(result.updatedKeys == ["test-a", "test-b"])
        #expect(result.keptNameKeys.isEmpty)
        #expect(first.name == "Nome Livre")
        #expect(second.name == "Nome Usado")
        #expect(second.isArchived)
    }

    @Test("An exercise takes the name another one leaves in the same run, whatever their order in the library")
    func nameLeftByAnotherInTheSameRun() throws {
        let takes = DefaultExercise(key: "test-a", id: Self.entryA.id, name: "Teste B", muscleGroup: .chest)
        let leaves = DefaultExercise(key: "test-b", id: Self.entryB.id, name: "Teste B Novo", muscleGroup: .back)
        for library in [[takes, leaves], [leaves, takes]] {
            let run = try Self.upgrade(from: [Self.entryA, Self.entryB], to: library)
            #expect(Set(run.result.updatedKeys) == ["test-a", "test-b"])
            #expect(run.result.keptNameKeys.isEmpty && run.result.insertedKeys.isEmpty)
            #expect(run.exercises["test-a"]?.name == "Teste B")
            #expect(run.exercises["test-b"]?.name == "Teste B Novo")
            #expect(run.exercises.values.allSatisfy { !$0.isArchived })
            #expect(run.again == ExerciseLibrarySeedResult())
            #expect(run.harness.context.hasChanges == false)
        }
    }

    @Test("Two exercises swap their names in one run")
    func swappedNames() throws {
        let run = try Self.upgrade(from: [Self.entryA, Self.entryB], to: [
            DefaultExercise(key: "test-a", id: Self.entryA.id, name: "Teste B", muscleGroup: .chest),
            DefaultExercise(key: "test-b", id: Self.entryB.id, name: "teste a", muscleGroup: .back),
        ])
        #expect(run.result.updatedKeys == ["test-a", "test-b"])
        #expect(run.result.keptNameKeys.isEmpty)
        #expect(run.exercises["test-a"]?.name == "Teste B")
        #expect(run.exercises["test-b"]?.name == "teste a")
        #expect(run.exercises["test-a"]?.id.uuidString == Self.entryA.id)
        #expect(run.exercises["test-b"]?.id.uuidString == Self.entryB.id)
        #expect(run.exercises.values.allSatisfy { !$0.isArchived })
        #expect(run.again == ExerciseLibrarySeedResult())
    }

    @Test("A new entry takes, active, a name an existing exercise leaves in the same run, whatever their order in the library")
    func newEntryTakesALeftName() throws {
        // As the first library's "Agachamento Búlgaro", which becomes "(Halter)" when a bodyweight one comes.
        let old = DefaultExercise(key: "test-a", id: Self.entryA.id, name: "Agachamento Búlgaro", muscleGroup: .quadriceps)
        let renamed = DefaultExercise(key: "test-a", id: Self.entryA.id, name: "Agachamento Búlgaro (Halter)", muscleGroup: .quadriceps)
        let new = DefaultExercise(key: "test-b", id: Self.entryB.id, name: "Agachamento Búlgaro", muscleGroup: .quadriceps)
        for library in [[renamed, new], [new, renamed]] {
            let run = try Self.upgrade(from: [old], to: library)
            #expect(run.result == ExerciseLibrarySeedResult(insertedKeys: ["test-b"], updatedKeys: ["test-a"]))
            #expect(run.exercises["test-a"]?.name == "Agachamento Búlgaro (Halter)")
            #expect(run.exercises["test-b"]?.name == "Agachamento Búlgaro")
            #expect(run.exercises["test-a"]?.isArchived == false)
            #expect(run.exercises["test-b"]?.isArchived == false)
            #expect(run.again == ExerciseLibrarySeedResult())
        }
    }

    @Test("A name an active custom exercise keeps stays kept: the corrected exercise keeps its name, which then stops the next correction and hides a new entry")
    func customExerciseKeepsItsName() throws {
        let run = try Self.upgrade(from: [Self.entryA, Self.entryB], to: [
            DefaultExercise(key: "test-a", id: Self.entryA.id, name: "Meu Nome", muscleGroup: .chest),
            DefaultExercise(key: "test-b", id: Self.entryB.id, name: "Teste A", muscleGroup: .back),
            DefaultExercise(key: "test-c", id: Self.entryC.id, name: "Teste B", muscleGroup: .biceps),
        ], customName: "meu nome")
        #expect(run.result == ExerciseLibrarySeedResult(insertedKeys: ["test-c"], keptNameKeys: ["test-a", "test-b"]))
        #expect(run.exercises["test-a"]?.name == "Teste A")
        #expect(run.exercises["test-b"]?.name == "Teste B")
        #expect(run.exercises["test-c"]?.isArchived == true)
        #expect(run.exercises["test-a"]?.isArchived == false && run.exercises["test-b"]?.isArchived == false)
        #expect(run.custom?.name == "meu nome")
        #expect(run.custom?.isArchived == false)
        // Nothing changes on the next run, and the kept names are reported again.
        #expect(run.again == ExerciseLibrarySeedResult(keptNameKeys: ["test-a", "test-b"]))
        #expect(run.harness.context.hasChanges == false)
    }

    @Test("A new entry in a later library is inserted and the others are untouched")
    func newEntryInserted() throws {
        try seeder.seed([Self.entryA])
        let existing = try #require(try exercise(key: "test-a"))
        let updatedAt = existing.updatedAt
        harness.clock.advance(by: 60)

        let result = try seeder.seed([Self.entryA, Self.entryB])

        #expect(result.insertedKeys == ["test-b"])
        #expect(try count(Exercise.self, in: harness.context) == 2)
        #expect(existing.updatedAt == updatedAt)
    }

    @Test("An entry removed from the library stays in the store")
    func removedEntryStays() throws {
        try seeder.seed([Self.entryA, Self.entryB])

        let result = try seeder.seed([Self.entryA])

        #expect(result == ExerciseLibrarySeedResult())
        #expect(try exercise(key: "test-b") != nil)
        #expect(try count(Exercise.self, in: harness.context) == 2)
    }

    // MARK: - Inconsistent stores

    @Test("An existing record with the same key but another id is kept and not duplicated")
    func sameKeyDifferentID() throws {
        let old = Exercise(name: "Teste A", muscleGroup: .chest, isCustom: false, libraryKey: "test-a")
        harness.context.insert(old)
        try harness.context.save()
        let oldID = old.id

        try seeder.seed([Self.entryA])

        #expect(try count(Exercise.self, in: harness.context) == 1)
        #expect(old.id == oldID)
        #expect(old.id.uuidString != Self.entryA.id)
    }

    @Test("Two records with the same key: nothing is inserted or deleted")
    func duplicatedKeyInStore() throws {
        for _ in 0..<2 {
            harness.context.insert(Exercise(name: "Teste A", muscleGroup: .chest, isCustom: false, libraryKey: "test-a"))
        }
        try harness.context.save()

        try seeder.seed([Self.entryA])

        #expect(try count(Exercise.self, in: harness.context) == 2)
    }

    @Test("A fixed id already used by another record is skipped, never overwritten")
    func idConflictSkipped() throws {
        let other = Exercise(name: "Outro Registro", muscleGroup: .calves, isCustom: true)
        other.id = try #require(UUID(uuidString: Self.entryA.id))
        harness.context.insert(other)
        try harness.context.save()

        let result = try seeder.seed([Self.entryA, Self.entryB])

        #expect(result.skippedKeys == ["test-a"])
        #expect(result.insertedKeys == ["test-b"])
        #expect(try count(Exercise.self, in: harness.context) == 2)
        #expect(other.name == "Outro Registro")
        #expect(other.isCustom)
        #expect(other.libraryKey == nil)
    }

    @Test("An invalid library definition is rejected before anything is changed")
    func invalidLibraryChangesNothing() throws {
        let invalidLists: [([DefaultExercise], ExerciseLibraryError)] = [
            ([Self.entryA, DefaultExercise(key: "bad-id", id: "not-a-uuid", name: "X", muscleGroup: .other)], .invalidID(key: "bad-id")),
            ([Self.entryA, DefaultExercise(key: "test-a", id: Self.entryB.id, name: "Y", muscleGroup: .other)], .duplicateKey("test-a")),
            ([Self.entryA, DefaultExercise(key: "test-c", id: Self.entryA.id, name: "Z", muscleGroup: .other)], .duplicateID(Self.entryA.id)),
            ([Self.entryA, DefaultExercise(key: "test-d", id: Self.entryB.id, name: " Espaço ", muscleGroup: .other)], .invalidName(key: "test-d")),
            ([Self.entryA, DefaultExercise(key: "test-e", id: Self.entryB.id, name: "TESTE Á", muscleGroup: .other)], .duplicateName(key: "test-e")),
        ]
        for (entries, expectedError) in invalidLists {
            #expect(throws: expectedError) { try seeder.seed(entries) }
            #expect(try count(Exercise.self, in: harness.context) == 0)
            #expect(harness.context.hasChanges == false)
        }
    }

    // MARK: - Services

    @Test("Seeded exercises follow the existing service rules")
    func compatibilityWithServices() throws {
        try seeder.seed()
        let bench = try #require(try exercise(key: "bench-press-barbell"))
        let curl = try #require(try exercise(key: "curl-barbell"))

        #expect(throws: ExerciseError.systemExerciseNotEditable) {
            try harness.exercises.updateCustomExercise(bench, name: "Outro", muscleGroup: .chest)
        }
        #expect(throws: ExerciseError.systemExerciseNotDeletable) { try harness.exercises.remove(bench) }
        #expect(throws: ValidationError.duplicateExerciseName) {
            try harness.exercises.createCustomExercise(name: "SUPINO RETO (BARRA)", muscleGroup: .chest)
        }
        try harness.exercises.archive(curl)
        try harness.exercises.unarchive(curl)
        #expect(curl.isArchived == false)

        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10, kg: 60)]), (curl, [.reps(10, 12)])])
        let session = try harness.sessions.startSession(from: workout)
        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Supino Reto (Barra)", "Rosca Direta (Barra)"])
        #expect(session.orderedExercises.map(\.muscleGroupSnapshot) == [.chest, .biceps])
        #expect(try count(Exercise.self, in: harness.context) == 420)
    }
}
