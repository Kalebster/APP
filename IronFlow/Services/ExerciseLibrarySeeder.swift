import Foundation
import SwiftData

/// The library definition itself is invalid. Thrown before anything is changed.
enum ExerciseLibraryError: Error, Equatable {
    case invalidID(key: String)
    case invalidName(key: String)
    case duplicateKey(String)
    case duplicateID(String)
    case duplicateName(key: String)
}

/// What a seeding run changed.
struct ExerciseLibrarySeedResult: Equatable {
    var insertedKeys: [String] = []
    var updatedKeys: [String] = []
    /// Entries not inserted because their fixed id is already used by another record.
    var skippedKeys: [String] = []
}

/// Installs and updates the built-in exercises in the store.
///
/// Idempotent: an entry is found by its `libraryKey`. Existing records are never deleted,
/// never replaced, and their `isArchived`, ids and relationships are never touched; only the
/// name and muscle group of built-in exercises follow the library. Custom exercises are never changed.
@MainActor
struct ExerciseLibrarySeeder {
    let context: ModelContext
    let now: @MainActor () -> Date

    init(context: ModelContext, now: @escaping @MainActor () -> Date = { Date.now }) {
        self.context = context
        self.now = now
    }

    @discardableResult
    func seed(_ entries: [DefaultExercise] = DefaultExerciseLibrary.all) throws -> ExerciseLibrarySeedResult {
        let library = try validated(entries)

        // Sorted so that, if a store ever holds two records with one key, the same (oldest) one is used.
        let stored = try context.fetch(FetchDescriptor<Exercise>()).sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id < rhs.id
        }
        var storedByKey: [String: Exercise] = [:]
        for exercise in stored {
            if let key = exercise.libraryKey, storedByKey[key] == nil {
                storedByKey[key] = exercise
            }
        }
        let storedIDs = Set(stored.map(\.id))
        var activeNames = Set(stored.filter { !$0.isArchived }.map { Validation.comparisonKey(forName: $0.name) })

        let timestamp = now()
        var result = ExerciseLibrarySeedResult()

        for (entry, id) in library {
            if let existing = storedByKey[entry.key] {
                guard !existing.isCustom else { continue }
                if existing.name != entry.name || existing.muscleGroup != entry.muscleGroup {
                    existing.name = entry.name
                    existing.muscleGroup = entry.muscleGroup
                    existing.updatedAt = timestamp
                    result.updatedKeys.append(entry.key)
                }
                continue
            }

            // Inserting a duplicate unique id would silently replace the other record.
            guard !storedIDs.contains(id) else {
                result.skippedKeys.append(entry.key)
                continue
            }

            let exercise = Exercise(name: entry.name, muscleGroup: entry.muscleGroup, isCustom: false, libraryKey: entry.key)
            exercise.id = id
            exercise.createdAt = timestamp
            exercise.updatedAt = timestamp
            // Active exercise names stay unique: a built-in exercise whose name is already used
            // by an active exercise is created hidden.
            let nameKey = Validation.comparisonKey(forName: entry.name)
            exercise.isArchived = activeNames.contains(nameKey)
            if !exercise.isArchived {
                activeNames.insert(nameKey)
            }
            context.insert(exercise)
            result.insertedKeys.append(entry.key)
        }

        if !result.insertedKeys.isEmpty || !result.updatedKeys.isEmpty {
            try context.saveOrRollback()
        }
        return result
    }

    // MARK: - Private

    /// Checks the whole definition before the store is touched.
    private func validated(_ entries: [DefaultExercise]) throws -> [(entry: DefaultExercise, id: UUID)] {
        var keys = Set<String>()
        var ids = Set<UUID>()
        var names = Set<String>()
        var result: [(entry: DefaultExercise, id: UUID)] = []
        for entry in entries {
            guard let id = UUID(uuidString: entry.id) else { throw ExerciseLibraryError.invalidID(key: entry.key) }
            guard (try? Validation.name(entry.name)) == entry.name else {
                throw ExerciseLibraryError.invalidName(key: entry.key)
            }
            guard keys.insert(entry.key).inserted else { throw ExerciseLibraryError.duplicateKey(entry.key) }
            guard ids.insert(id).inserted else { throw ExerciseLibraryError.duplicateID(entry.id) }
            guard names.insert(Validation.comparisonKey(forName: entry.name)).inserted else {
                throw ExerciseLibraryError.duplicateName(key: entry.key)
            }
            result.append((entry, id))
        }
        return result
    }
}
