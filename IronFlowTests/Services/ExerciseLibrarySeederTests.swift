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

    // MARK: - Installation

    @Test("A new install gets the whole library, active, with the fixed ids, names and groups")
    func freshInstall() throws {
        let result = try seeder.seed()

        #expect(result.insertedKeys.count == 157)
        #expect(result.updatedKeys.isEmpty && result.skippedKeys.isEmpty)
        let stored = try systemExercises()
        #expect(stored.count == 157)
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
        #expect(try count(Exercise.self, in: harness.context) == 157)
        #expect(try systemExercises().map(\.updatedAt) == updatedAt)
    }

    @Test("Seeding after closing and reopening the store on disk does not duplicate")
    func idempotentAfterReopening() throws {
        try roundTripThroughDisk { context in
            try ExerciseLibrarySeeder(context: context).seed()
        } read: { context in
            #expect(try ExerciseLibrarySeeder(context: context).seed() == ExerciseLibrarySeedResult())
            let stored = try context.fetch(FetchDescriptor<Exercise>())
            #expect(stored.count == 157)
            #expect(Set(stored.map(\.id.uuidString)) == Set(library.map(\.id)))
        }
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
        #expect(try count(Exercise.self, in: harness.context) == 158)
    }

    @Test("A built-in exercise named like an active custom one is created archived")
    func nameClashWithActiveCustom() throws {
        let custom = try harness.exercises.createCustomExercise(name: "supino reto com barra", muscleGroup: .chest)

        try seeder.seed()

        let builtIn = try #require(try exercise(key: "bench-press-barbell"))
        #expect(builtIn.isArchived)
        #expect(custom.isArchived == false)
        #expect(custom.name == "supino reto com barra")
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
        let custom = try harness.exercises.createCustomExercise(name: "Supino Reto com Barra", muscleGroup: .chest)
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
        #expect(session.orderedExercises[0].exerciseNameSnapshot == "Supino Reto com Barra")
        #expect(session.orderedExercises[0].orderedSetLogs[0].reps == 9)
    }

    // MARK: - Library updates

    @Test("A store with the first library (71) gets the 157: 20 names and 3 groups corrected with the same ids, workouts and history linked as before, custom exercises untouched; seeding again changes nothing")
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
        try harness.sessions.completeSet(session.orderedExercises[0].orderedSetLogs[0], weightKg: nil, reps: 8)
        try harness.sessions.finishSession(session)
        harness.clock.advance(by: 3_600)

        let result = try seeder.seed()

        let oldKeys = Set(LibraryV1Fixture.entries.map(\.key))
        let newKeys = Set(library.map(\.key)).subtracting(oldKeys)
        #expect(newKeys.count == 86)
        #expect(Set(result.insertedKeys) == newKeys)
        let corrected = LibraryV1Fixture.entries.filter { old in
            let entry = DefaultExerciseLibrary.byKey[old.key]
            return entry?.name != old.name || entry?.muscleGroup != old.muscleGroup
        }
        #expect(corrected.count == 23)
        #expect(Set(result.updatedKeys) == Set(corrected.map(\.key)))
        #expect(result.skippedKeys.isEmpty && result.keptNameKeys.isEmpty)

        // Every built-in exercise follows the library, active, and the first 71 keep their ids.
        let stored = try systemExercises()
        #expect(stored.count == 157)
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
        #expect(pullUp.name == "Barra Fixa Pronada")
        #expect(deadlift.muscleGroup == .back)
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
        #expect(try count(Exercise.self, in: harness.context) == 158)
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
            try harness.exercises.createCustomExercise(name: "SUPINO RETO COM BARRA", muscleGroup: .chest)
        }
        try harness.exercises.archive(curl)
        try harness.exercises.unarchive(curl)
        #expect(curl.isArchived == false)

        let workout = try harness.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10, kg: 60)]), (curl, [.reps(10, 12)])])
        let session = try harness.sessions.startSession(from: workout)
        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Supino Reto com Barra", "Rosca Direta com Barra"])
        #expect(session.orderedExercises.map(\.muscleGroupSnapshot) == [.chest, .biceps])
        #expect(try count(Exercise.self, in: harness.context) == 157)
    }
}
