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
    /// Entries whose corrected name is already used by another active exercise: the exercise keeps
    /// its current name (a corrected muscle group is still applied).
    var keptNameKeys: [String] = []
}

/// Installs and updates the built-in exercises in the store.
///
/// Idempotent: an entry is found by its `libraryKey`. Existing records are never deleted,
/// never replaced, and their `isArchived`, ids and relationships are never touched; only the
/// name and muscle group of built-in exercises follow the library, except a corrected name kept by another
/// active exercise. Custom exercises are never changed.
///
/// Active exercise names stay unique (ignoring case and diacritics). Whether a name is free is decided with
/// the names the exercises hold once the run is over, never with those of the moment, so neither the order
/// of the library nor the order of the changes matters: an exercise can take the name another one leaves
/// in the same run, two exercises can swap names, and a new entry can take a name an existing exercise
/// leaves. A name is kept only by an active exercise that still has it after the run, such as a custom
/// exercise of that name: then a corrected exercise keeps its current name (`keptNameKeys`) and a new
/// entry is created hidden (archived).
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

        var result = ExerciseLibrarySeedResult()
        // The built-in exercises the library corrects, and the entries it adds.
        var corrections: [(exercise: Exercise, entry: DefaultExercise)] = []
        var additions: [(entry: DefaultExercise, id: UUID)] = []
        for (entry, id) in library {
            if let existing = storedByKey[entry.key] {
                if !existing.isCustom && (existing.name != entry.name || existing.muscleGroup != entry.muscleGroup) {
                    corrections.append((existing, entry))
                }
                continue
            }
            // Inserting a duplicate unique id would silently replace the other record.
            guard !storedIDs.contains(id) else {
                result.skippedKeys.append(entry.key)
                continue
            }
            additions.append((entry, id))
        }
        // Normal launches have nothing to change: the names are not even compared.
        guard !corrections.isEmpty || !additions.isEmpty else { return result }

        let names = Self.finalNames(of: stored, corrections: corrections)
        let timestamp = now()

        for (existing, entry) in corrections {
            var changed = false
            if existing.name != entry.name {
                if names.kept.contains(ObjectIdentifier(existing)) {
                    result.keptNameKeys.append(entry.key)
                } else {
                    existing.name = entry.name
                    changed = true
                }
            }
            if existing.muscleGroup != entry.muscleGroup {
                existing.muscleGroup = entry.muscleGroup
                changed = true
            }
            if changed {
                existing.updatedAt = timestamp
                result.updatedKeys.append(entry.key)
            }
        }

        for (entry, id) in additions {
            let exercise = Exercise(name: entry.name, muscleGroup: entry.muscleGroup, isCustom: false, libraryKey: entry.key)
            exercise.id = id
            exercise.createdAt = timestamp
            exercise.updatedAt = timestamp
            // A built-in exercise whose name another active exercise keeps is created hidden.
            exercise.isArchived = names.taken.contains(Validation.comparisonKey(forName: entry.name))
            context.insert(exercise)
            result.insertedKeys.append(entry.key)
        }

        if !result.insertedKeys.isEmpty || !result.updatedKeys.isEmpty {
            try context.saveOrRollback()
        }
        return result
    }

    // MARK: - Private

    /// The names the active exercises hold once the run is over (as `Validation.comparisonKey`), and the
    /// corrected exercises that keep their current name because another active exercise keeps the new one.
    ///
    /// Every correction of a name is applied at first. An active exercise that the run does not rename
    /// keeps its name: a custom exercise, one that left the library, the second record of a key, or one
    /// whose name does not change. A correction to a name one of those keeps is not applied, and that
    /// exercise then keeps its own name too, which may stop another correction: this goes on until no
    /// correction changes. An archived exercise takes any corrected name, as unarchiving checks the name
    /// again, and so does a correction of case or diacritics only.
    private static func finalNames(
        of stored: [Exercise],
        corrections: [(exercise: Exercise, entry: DefaultExercise)]
    ) -> (taken: Set<String>, kept: Set<ObjectIdentifier>) {
        // The renames that change an active exercise's name as names are compared: its current and new name.
        var renames: [ObjectIdentifier: (current: String, new: String)] = [:]
        for (exercise, entry) in corrections where !exercise.isArchived && exercise.name != entry.name {
            let current = Validation.comparisonKey(forName: exercise.name)
            let new = Validation.comparisonKey(forName: entry.name)
            if current != new {
                renames[ObjectIdentifier(exercise)] = (current, new)
            }
        }
        var taken = Set(stored.filter { !$0.isArchived && renames[ObjectIdentifier($0)] == nil }
            .map { Validation.comparisonKey(forName: $0.name) })
        var kept: Set<ObjectIdentifier> = []
        while true {
            let blocked = renames.filter { taken.contains($0.value.new) }
            guard !blocked.isEmpty else { break }
            for (exercise, names) in blocked {
                renames[exercise] = nil
                kept.insert(exercise)
                taken.insert(names.current)
            }
        }
        // The names the applied corrections give are taken too.
        taken.formUnion(renames.values.map { $0.new })
        return (taken, kept)
    }

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
