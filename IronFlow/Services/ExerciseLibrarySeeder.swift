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
    /// Entries whose corrected name is already used by another active exercise, or kept by an archived
    /// exercise of the user's own: the exercise keeps its current name (a corrected muscle group is still
    /// applied).
    var keptNameKeys: [String] = []
    /// Junctions applied: the key of the exercise merged into the one that stays (`RetiredExercises.junctions`).
    var mergedKeys: [String] = []
    /// Exercises that left the library and were used: they became exercises of the user's own.
    var convertedKeys: [String] = []
    /// Exercises that left the library unused: deleted (the merged ones are in `mergedKeys`, and deleted too).
    var deletedKeys: [String] = []
    /// Library exercises hidden because their name was taken, shown again because it is free.
    var revealedKeys: [String] = []
}

/// Installs and updates the built-in exercises in the store.
///
/// Idempotent: an entry is found by its `libraryKey`. Records are never replaced, and their ids are never
/// touched; only the name and muscle group of built-in exercises follow the library, except a corrected
/// name kept by another active exercise or by an archived exercise of the user's own. Custom exercises are
/// never changed.
///
/// Active exercise names stay unique (ignoring case and diacritics). Whether a name is free is decided with
/// the names the exercises hold once the run is over, never with those of the moment, so neither the order
/// of the library nor the order of the changes matters: an exercise can take the name another one leaves
/// in the same run, two exercises can swap names, and a new entry can take a name an existing exercise
/// leaves. A name is kept by an active exercise that still has it after the run, such as a custom
/// exercise of that name, and by an archived exercise of the user's own, whose name stays reserved for
/// restoring it: then a corrected exercise keeps its current name (`keptNameKeys`) and a new entry is
/// created hidden (archived). A hidden library exercise is shown again once its name is free.
///
/// The base list (26/11/2026) also migrates what left the library, before the rest, only for keys the
/// library seeded no longer has:
/// - a junction (`RetiredExercises.junctions`) moves the history, the planned workouts and the session in
///   progress of the merged exercise to the one that stays, then deletes the merged record, which holds
///   nothing else of the person's: a built-in exercise is never edited, and only this seeder hides one;
/// - a retired exercise (`RetiredExercises.all`) that was used (history, planned workout or session in
///   progress) becomes an exercise of the user's own, with its id, name, group, equipment, kind of machine
///   and muscles, so its history stays; an unused one is deleted.
///
/// Everything is saved at once: if saving fails, nothing changed and the next launch runs it again.
@MainActor
struct ExerciseLibrarySeeder {
    let context: ModelContext
    let now: @MainActor () -> Date

    init(context: ModelContext, now: @escaping @MainActor () -> Date = { Date.now }) {
        self.context = context
        self.now = now
    }

    @discardableResult
    func seed(
        _ entries: [DefaultExercise] = DefaultExerciseLibrary.all,
        retired: [RetiredExercise] = RetiredExercises.all,
        junctions: [(kept: String, merged: String)] = RetiredExercises.junctions
    ) throws -> ExerciseLibrarySeedResult {
        let library = try validated(entries)
        let libraryKeys = Set(entries.map(\.key))
        let timestamp = now()
        var result = ExerciseLibrarySeedResult()

        // Sorted so that, if a store ever holds two records with one key, the same (oldest) one is used.
        var stored = try context.fetch(FetchDescriptor<Exercise>()).sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id < rhs.id
        }

        // What left the library, first: the records it deletes no longer count for the names.
        let migration = migrateWhatLeft(
            stored: stored, library: library, libraryKeys: libraryKeys, retired: retired, junctions: junctions,
            timestamp: timestamp, result: &result
        )
        if !migration.deleted.isEmpty {
            stored.removeAll { migration.deleted.contains(ObjectIdentifier($0)) }
        }
        stored.append(contentsOf: migration.inserted)

        var storedByKey: [String: Exercise] = [:]
        for exercise in stored {
            if let key = exercise.libraryKey, storedByKey[key] == nil {
                storedByKey[key] = exercise
            }
        }
        let storedIDs = Set(stored.map(\.id))

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
        // The library exercises hidden because their name was taken.
        let hidden = stored.filter { exercise in
            exercise.isArchived && !exercise.isCustom && exercise.libraryKey.map(libraryKeys.contains) == true
        }
        // Normal launches have nothing to change: the names are not even compared.
        guard migration.changed || !corrections.isEmpty || !additions.isEmpty || !hidden.isEmpty else {
            return result
        }

        var names = Self.finalNames(of: stored, corrections: corrections)
        var changed = migration.changed

        for (existing, entry) in corrections {
            var corrected = false
            if existing.name != entry.name {
                if names.kept.contains(ObjectIdentifier(existing)) {
                    result.keptNameKeys.append(entry.key)
                } else {
                    existing.name = entry.name
                    corrected = true
                }
            }
            if existing.muscleGroup != entry.muscleGroup {
                existing.muscleGroup = entry.muscleGroup
                corrected = true
            }
            if corrected {
                existing.updatedAt = timestamp
                result.updatedKeys.append(entry.key)
                changed = true
            }
        }

        // A hidden library exercise whose name is free again is shown (with its name corrected above, if it was).
        for exercise in hidden {
            let name = Validation.comparisonKey(forName: exercise.name)
            guard !names.taken.contains(name) else { continue }
            exercise.isArchived = false
            exercise.updatedAt = timestamp
            names.taken.insert(name)
            result.revealedKeys.append(exercise.libraryKey ?? "")
            changed = true
        }

        for (entry, id) in additions {
            let exercise = Self.makeExercise(entry, id: id, at: timestamp)
            // A built-in exercise whose name another active exercise, or an archived one of the user's own,
            // keeps is created hidden.
            exercise.isArchived = names.taken.contains(Validation.comparisonKey(forName: entry.name))
            context.insert(exercise)
            result.insertedKeys.append(entry.key)
            changed = true
        }

        if changed {
            try context.saveOrRollback()
        }
        return result
    }

    // MARK: - What left the library

    /// What `migrateWhatLeft` did, not saved yet.
    private struct Migration {
        /// The records deleted: unused retired exercises and merged ones.
        var deleted: Set<ObjectIdentifier> = []
        /// The exercises that stay in a junction, created because the store had only the merged one.
        var inserted: [Exercise] = []
        var changed = false
    }

    /// Applies the junctions and the retired exercises whose keys the library seeded no longer has. Only
    /// built-in records are touched; nothing is saved here.
    private func migrateWhatLeft(
        stored: [Exercise],
        library: [(entry: DefaultExercise, id: UUID)],
        libraryKeys: Set<String>,
        retired: [RetiredExercise],
        junctions: [(kept: String, merged: String)],
        timestamp: Date,
        result: inout ExerciseLibrarySeedResult
    ) -> Migration {
        var builtInByKey: [String: [Exercise]] = [:]
        for exercise in stored where !exercise.isCustom {
            if let key = exercise.libraryKey {
                builtInByKey[key, default: []].append(exercise)
            }
        }
        var migration = Migration()

        // Junctions: the history, the planned workouts and the session in progress of the merged exercise go
        // to the one that stays. A session or workout that had both keeps both items, now of one exercise.
        let entries = Dictionary(library.map { ($0.entry.key, $0) }) { first, _ in first }
        for junction in junctions where !libraryKeys.contains(junction.merged) {
            guard let mergedRecords = builtInByKey[junction.merged], !mergedRecords.isEmpty,
                  let keptEntry = entries[junction.kept] else { continue }
            let kept: Exercise
            if let existing = builtInByKey[junction.kept]?.first {
                kept = existing
            } else {
                // The store never had the exercise that stays: it is created now, with its fixed id, unless
                // another record has that id (then nothing of this junction changes).
                guard !stored.contains(where: { $0.id == keptEntry.id }) else {
                    result.skippedKeys.append(junction.kept)
                    continue
                }
                kept = Self.makeExercise(keptEntry.entry, id: keptEntry.id, at: timestamp)
                context.insert(kept)
                builtInByKey[junction.kept] = [kept]
                migration.inserted.append(kept)
                result.insertedKeys.append(junction.kept)
            }
            for merged in mergedRecords {
                for performed in merged.sessionExercises {
                    performed.exercise = kept
                    performed.updatedAt = timestamp
                }
                for planned in merged.workoutExercises {
                    planned.exercise = kept
                    planned.updatedAt = timestamp
                }
                context.delete(merged)
                migration.deleted.insert(ObjectIdentifier(merged))
            }
            result.mergedKeys.append(junction.merged)
            migration.changed = true
        }

        // Retired exercises: the person's own when used, deleted when not.
        for exercise in retired where !libraryKeys.contains(exercise.key) {
            for record in builtInByKey[exercise.key] ?? [] {
                migration.changed = true
                if record.sessionExercises.isEmpty && record.workoutExercises.isEmpty {
                    context.delete(record)
                    migration.deleted.insert(ObjectIdentifier(record))
                    result.deletedKeys.append(exercise.key)
                    continue
                }
                // The same record, so its history, planned workouts and session in progress stay with it; its
                // name, group and whether it is archived stay as they are.
                record.isCustom = true
                record.libraryKey = nil
                record.equipment = exercise.equipment
                record.machineType = exercise.equipment == .machine ? exercise.machine : nil
                record.primaryMuscles = exercise.primary
                record.secondaryMuscles = exercise.secondary
                record.updatedAt = timestamp
                result.convertedKeys.append(exercise.key)
            }
        }
        return migration
    }

    // MARK: - Private

    private static func makeExercise(_ entry: DefaultExercise, id: UUID, at timestamp: Date) -> Exercise {
        let exercise = Exercise(name: entry.name, muscleGroup: entry.muscleGroup, isCustom: false, libraryKey: entry.key)
        exercise.id = id
        exercise.createdAt = timestamp
        exercise.updatedAt = timestamp
        return exercise
    }

    /// The names taken once the run is over (as `Validation.comparisonKey`): those the active exercises hold
    /// and those the archived exercises of the user's own keep reserved, as `ExerciseService` counts them
    /// (restoring one is the way to use its name). Also the corrected exercises that keep their current name
    /// because one of those names is the new one.
    ///
    /// Every correction of a name is applied at first. An active exercise that the run does not rename
    /// keeps its name: a custom exercise, one that left the library, the second record of a key, or one
    /// whose name does not change. A correction to a name one of those keeps, or an archived exercise of the
    /// user's own keeps, is not applied, and that exercise then keeps its own name too, which may stop
    /// another correction: this goes on until no correction changes. An archived built-in exercise takes any
    /// corrected name, as unarchiving checks the name again, and so does a correction of case or diacritics
    /// only.
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
        var taken = Set(stored.filter { (!$0.isArchived || $0.isCustom) && renames[ObjectIdentifier($0)] == nil }
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

    /// Checks the whole definition before the store is touched. A library name has up to
    /// `DefaultExerciseLibrary.maxNameLength` characters, without spaces around it.
    private func validated(_ entries: [DefaultExercise]) throws -> [(entry: DefaultExercise, id: UUID)] {
        var keys = Set<String>()
        var ids = Set<UUID>()
        var names = Set<String>()
        var result: [(entry: DefaultExercise, id: UUID)] = []
        for entry in entries {
            guard let id = UUID(uuidString: entry.id) else { throw ExerciseLibraryError.invalidID(key: entry.key) }
            let trimmed = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed == entry.name, trimmed.count <= DefaultExerciseLibrary.maxNameLength else {
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
