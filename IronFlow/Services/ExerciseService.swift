import Foundation
import SwiftData

/// What removing an exercise of the user's own would do. A read-only check for the interface.
enum ExerciseRemovalImpact: Equatable {
    /// Built-in exercise: it cannot be removed.
    case notAllowedSystemExercise
    /// It has history, or is in the session in progress: it will be archived. It leaves these planned
    /// workouts (none, when it is in no workout).
    case willArchive([Workout])
    /// It has no history: it will be deleted. It leaves these planned workouts.
    case willDelete([Workout])

    /// The planned workouts the exercise leaves, in the order of the Treinos tab.
    var workouts: [Workout] {
        switch self {
        case .notAllowedSystemExercise: []
        case .willArchive(let workouts), .willDelete(let workouts): workouts
        }
    }
}

enum ExerciseRemovalOutcome: Equatable {
    case archived
    case deleted
}

/// Business rules for library exercises and the exercises of the user's own.
@MainActor
struct ExerciseService {
    let context: ModelContext
    let now: @MainActor () -> Date

    init(context: ModelContext, now: @escaping @MainActor () -> Date = { Date.now }) {
        self.context = context
        self.now = now
    }

    // MARK: - Create and edit

    /// Creates an exercise of the user's own from `draft`, once every rule of `validated(_:ignoring:)` holds.
    @discardableResult
    func create(_ draft: ExerciseDraft) throws -> Exercise {
        let valid = try validated(draft, ignoring: nil)
        let timestamp = now()
        let exercise = Exercise(name: valid.name, muscleGroup: valid.group, isCustom: true)
        exercise.createdAt = timestamp
        exercise.updatedAt = timestamp
        apply(valid, to: exercise)
        context.insert(exercise)
        try context.saveOrRollback()
        return exercise
    }

    /// Creates an exercise of the user's own with only a name and a group, as the exercises created before
    /// version 8: no equipment ("Outro") and no muscles of its own, so its screen shows the muscle of its
    /// group. For the interface tests' ready-made data and the tests; the app's form uses `create(_:)`.
    @discardableResult
    func createCustomExercise(name: String, muscleGroup: MuscleGroup) throws -> Exercise {
        let validName = try Validation.name(name)
        try ensureNameIsAvailable(validName, ignoring: nil)

        let timestamp = now()
        let exercise = Exercise(name: validName, muscleGroup: muscleGroup, isCustom: true)
        exercise.createdAt = timestamp
        exercise.updatedAt = timestamp
        context.insert(exercise)
        try context.saveOrRollback()
        return exercise
    }

    /// Changes an exercise of the user's own, archived or not, to `draft`. The history and the session in
    /// progress keep the name and group of their day; the planned workouts show the new ones.
    func update(_ exercise: Exercise, with draft: ExerciseDraft) throws {
        guard exercise.isCustom else { throw ExerciseError.systemExerciseNotEditable }
        let valid = try validated(draft, ignoring: exercise)
        let oldName = exercise.name
        exercise.name = valid.name
        exercise.muscleGroup = valid.group
        apply(valid, to: exercise)
        exercise.updatedAt = now()
        if Validation.comparisonKey(forName: oldName) != Validation.comparisonKey(forName: valid.name) {
            try revealOrRollBack(named: oldName, ignoring: nil)
        }
        try context.saveOrRollback()
    }

    /// The name offered for a copy of `name`: the name with " 2" (or " 3", " 4"…) after it, the first one
    /// no other exercise has, cut so it fits in `Validation.maxNameLength`.
    func copyName(for name: String) throws -> String {
        let taken = try takenNames(ignoring: nil)
        return Self.copyName(for: name, isTaken: { taken[Validation.comparisonKey(forName: $0)] != nil })
    }

    static func copyName(for name: String, isTaken: (String) -> Bool) -> String {
        let base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var number = 2
        while true {
            let suffix = " \(number)"
            let kept = String(base.prefix(max(0, Validation.maxNameLength - suffix.count)))
            let candidate = kept.trimmingCharacters(in: .whitespaces) + suffix
            if !isTaken(candidate) {
                return candidate
            }
            number += 1
        }
    }

    /// The names an exercise cannot take, by `Validation.comparisonKey`: those of the active exercises
    /// and of the archived exercises of the user's own (an archived built-in exercise is hidden because its
    /// name was taken, and does not keep it), except `excluded`'s own. The value says whether the name is an archived one.
    func takenNames(ignoring excluded: Exercise?) throws -> [String: ExerciseNameOwner] {
        let exercises = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isArchived || $0.isCustom }))
        var taken: [String: ExerciseNameOwner] = [:]
        for exercise in exercises where exercise.id != excluded?.id {
            let key = Validation.comparisonKey(forName: exercise.name)
            // An active exercise wins over an archived one with the same name: its message comes first.
            if taken[key]?.isArchived == false { continue }
            taken[key] = ExerciseNameOwner(name: exercise.name, isArchived: exercise.isArchived)
        }
        return taken
    }

    // MARK: - Archive and restore

    /// Hides the exercise from the library and from the picker. Its history stays.
    func archive(_ exercise: Exercise) throws {
        guard !exercise.isArchived else { return }
        exercise.isArchived = true
        exercise.updatedAt = now()
        try context.saveOrRollback()
    }

    /// Shows an archived exercise again, in the list and the picker; it does not go back to any workout.
    /// Refused when an active exercise has the same name (ignoring case and diacritics), with its name.
    func unarchive(_ exercise: Exercise) throws {
        guard exercise.isArchived else { return }
        let key = Validation.comparisonKey(forName: exercise.name)
        let exerciseID = exercise.id
        let active = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isArchived && $0.id != exerciseID }))
        if let other = active.first(where: { Validation.comparisonKey(forName: $0.name) == key }) {
            throw ExerciseError.nameTakenByActiveExercise(name: other.name)
        }

        exercise.isArchived = false
        exercise.updatedAt = now()
        try context.saveOrRollback()
    }

    // MARK: - Removal

    /// What removing the exercise would do: an exercise with history (a finished session or the one in
    /// progress) is archived, one without is deleted; both leave every planned workout they are in.
    func removalImpact(of exercise: Exercise) -> ExerciseRemovalImpact {
        guard exercise.isCustom else { return .notAllowedSystemExercise }
        let workouts = workoutsUsing(exercise)
        return exercise.sessionExercises.isEmpty ? .willDelete(workouts) : .willArchive(workouts)
    }

    /// Applies the removal rules: built-in → error; with history → archived; without → deleted. Either
    /// way the exercise leaves its planned workouts, whose other exercises are renumbered; the history
    /// keeps the name of its day. Only when `confirmedWorkoutIDs` are exactly the workouts affected now
    /// (the ones the user was shown); otherwise `confirmationRequired` is thrown with the current list and
    /// nothing changes.
    @discardableResult
    func remove(_ exercise: Exercise, confirmedWorkoutIDs: Set<UUID> = []) throws -> ExerciseRemovalOutcome {
        let impact = removalImpact(of: exercise)
        if impact == .notAllowedSystemExercise {
            throw ExerciseError.systemExerciseNotDeletable
        }
        let workouts = impact.workouts
        let affectedIDs = workouts.map(\.id)
        guard Set(affectedIDs) == confirmedWorkoutIDs else {
            throw ExerciseError.confirmationRequired(workoutIDs: affectedIDs)
        }

        let timestamp = now()
        let removedItems = exercise.workoutExercises
        let removedIDs = Set(removedItems.map(\.id))
        for workout in workouts {
            let remaining = workout.orderedExercises.filter { !removedIDs.contains($0.id) }
            SortIndexing.renumber(remaining, at: timestamp)
            workout.updatedAt = timestamp
        }
        for item in removedItems {
            context.delete(item)
        }

        let outcome: ExerciseRemovalOutcome
        if case .willArchive = impact {
            exercise.isArchived = true
            exercise.updatedAt = timestamp
            outcome = .archived
        } else {
            try revealOrRollBack(named: exercise.name, ignoring: exercise)
            context.delete(exercise)
            outcome = .deleted
        }
        try context.saveOrRollback()
        return outcome
    }

    // MARK: - Private

    /// A draft that passed every rule: the name trimmed and the group chosen.
    private struct ValidDraft {
        let name: String
        let group: MuscleGroup
        let draft: ExerciseDraft
    }

    /// The rules of an exercise of the user's own: a name of up to 60 characters that no other exercise
    /// has (`takenNames`); a group; an equipment ("Outro" counts); at least one main muscle, except for
    /// "Corpo inteiro"; no muscle both main and secondary. Thrown before anything changes.
    private func validated(_ draft: ExerciseDraft, ignoring excluded: Exercise?) throws -> ValidDraft {
        let name = try Validation.name(draft.name)
        guard let group = draft.group else { throw ExerciseError.muscleGroupMissing }
        guard draft.equipment != nil else { throw ExerciseError.equipmentMissing }
        if draft.needsPrimaryMuscle && draft.primary.isEmpty {
            throw ExerciseError.primaryMuscleMissing
        }
        guard Set(draft.primary).isDisjoint(with: draft.secondary) else {
            throw ExerciseError.muscleInBothLists
        }
        try ensureNameIsAvailable(name, ignoring: excluded)
        return ValidDraft(name: name, group: group, draft: draft)
    }

    private func apply(_ valid: ValidDraft, to exercise: Exercise) {
        exercise.equipment = valid.draft.equipment?.equipment
        exercise.machineType = valid.draft.storedMachine
        exercise.primaryMuscles = Self.unique(valid.draft.primary)
        exercise.secondaryMuscles = Self.unique(valid.draft.secondary)
    }

    private static func unique(_ muscles: [Muscle]) -> [Muscle] {
        var seen = Set<Muscle>()
        return muscles.filter { seen.insert($0).inserted }
    }

    /// Planned workouts that contain the exercise, each once, in the order of the Treinos tab.
    private func workoutsUsing(_ exercise: Exercise) -> [Workout] {
        var seen = Set<UUID>()
        var result: [Workout] = []
        for item in exercise.workoutExercises {
            if let workout = item.workout, seen.insert(workout.id).inserted {
                result.append(workout)
            }
        }
        return result.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return lhs.id < rhs.id
        }
    }

    /// Shows again the library exercise hidden because an exercise of the user's own had `freedName`, now that
    /// the user's exercise has another name or is being deleted (`excluded`), unless another exercise still
    /// keeps the name (`takenNames`). Not saved here: it goes with the change that freed the name.
    /// `revealLibraryExercise`, after the changes of `update` or `remove` were made: if it fails, they are
    /// undone too, so nothing of the failed operation is left to a later save.
    private func revealOrRollBack(named freedName: String, ignoring excluded: Exercise?) throws {
        do {
            try revealLibraryExercise(named: freedName, ignoring: excluded)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func revealLibraryExercise(named freedName: String, ignoring excluded: Exercise?) throws {
        let key = Validation.comparisonKey(forName: freedName)
        let hidden = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isArchived && !$0.isCustom }))
        guard let exercise = hidden.first(where: { exercise in
            Validation.comparisonKey(forName: exercise.name) == key
                && exercise.libraryKey.map { DefaultExerciseLibrary.byKey[$0] != nil } == true
        }) else { return }
        guard try takenNames(ignoring: excluded)[key] == nil else { return }
        exercise.isArchived = false
        exercise.updatedAt = now()
    }

    /// The name must not be taken (`takenNames`): by an active exercise, `duplicateExerciseName`; by an
    /// archived exercise of the user's own, `archivedExerciseHasName` with its name, to restore it.
    private func ensureNameIsAvailable(_ name: String, ignoring excluded: Exercise?) throws {
        guard let owner = try takenNames(ignoring: excluded)[Validation.comparisonKey(forName: name)] else { return }
        if owner.isArchived {
            throw ExerciseError.archivedExerciseHasName(name: owner.name)
        }
        throw ValidationError.duplicateExerciseName
    }
}

/// The exercise that has a name: its name as written and whether it is archived.
struct ExerciseNameOwner: Equatable, Sendable {
    let name: String
    let isArchived: Bool
}
