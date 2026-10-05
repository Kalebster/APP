import Foundation
import SwiftData

/// What removing an exercise would do. A read-only check for the interface.
enum ExerciseRemovalImpact: Equatable {
    /// Built-in exercise: it can only be archived (hidden).
    case notAllowedSystemExercise
    /// It has history, so it will be archived instead of deleted.
    case willArchive
    /// Used in these workouts (no history): removal needs confirmation and removes it from them.
    case willRemoveFromWorkouts([Workout])
    /// Not used anywhere: it will be deleted.
    case willDelete
}

enum ExerciseRemovalOutcome: Equatable {
    case archived
    case deleted
}

/// Business rules for library exercises.
@MainActor
struct ExerciseService {
    let context: ModelContext
    let now: @MainActor () -> Date

    init(context: ModelContext, now: @escaping @MainActor () -> Date = { Date.now }) {
        self.context = context
        self.now = now
    }

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

    /// Renames or regroups a custom exercise. History keeps its own snapshots.
    func updateCustomExercise(_ exercise: Exercise, name: String, muscleGroup: MuscleGroup) throws {
        guard exercise.isCustom else { throw ExerciseError.systemExerciseNotEditable }
        let validName = try Validation.name(name)
        if !exercise.isArchived {
            try ensureNameIsAvailable(validName, ignoring: exercise)
        }

        exercise.name = validName
        exercise.muscleGroup = muscleGroup
        exercise.updatedAt = now()
        try context.saveOrRollback()
    }

    /// Hides the exercise from the library. It stays in existing workouts and history.
    func archive(_ exercise: Exercise) throws {
        guard !exercise.isArchived else { return }
        exercise.isArchived = true
        exercise.updatedAt = now()
        try context.saveOrRollback()
    }

    /// Shows an archived exercise again, if no other active exercise has the same name.
    func unarchive(_ exercise: Exercise) throws {
        guard exercise.isArchived else { return }
        try ensureNameIsAvailable(exercise.name, ignoring: exercise)

        exercise.isArchived = false
        exercise.updatedAt = now()
        try context.saveOrRollback()
    }

    func removalImpact(of exercise: Exercise) -> ExerciseRemovalImpact {
        guard exercise.isCustom else { return .notAllowedSystemExercise }
        guard exercise.sessionExercises.isEmpty else { return .willArchive }
        let workouts = workoutsUsing(exercise)
        guard workouts.isEmpty else { return .willRemoveFromWorkouts(workouts) }
        return .willDelete
    }

    /// Applies the removal rules: built-in → error; with history → archived; unused → deleted;
    /// used in workouts → removed from them only when `confirmedWorkoutIDs` are exactly the
    /// workouts currently affected (the ones the user was shown), otherwise
    /// `confirmationRequired` is thrown with the current list.
    @discardableResult
    func remove(_ exercise: Exercise, confirmedWorkoutIDs: Set<UUID> = []) throws -> ExerciseRemovalOutcome {
        switch removalImpact(of: exercise) {
        case .notAllowedSystemExercise:
            throw ExerciseError.systemExerciseNotDeletable

        case .willArchive:
            try archive(exercise)
            return .archived

        case .willRemoveFromWorkouts(let workouts):
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
            context.delete(exercise)
            try context.saveOrRollback()
            return .deleted

        case .willDelete:
            context.delete(exercise)
            try context.saveOrRollback()
            return .deleted
        }
    }

    // MARK: - Private

    /// Workouts that contain the exercise, each once, in creation order.
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
            return lhs.id < rhs.id
        }
    }

    /// Active (non-archived) exercise names must be unique, ignoring case and diacritics.
    private func ensureNameIsAvailable(_ name: String, ignoring excluded: Exercise?) throws {
        let key = Validation.comparisonKey(forName: name)
        let active = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isArchived }))
        let taken = active.contains { other in
            other.id != excluded?.id && Validation.comparisonKey(forName: other.name) == key
        }
        if taken {
            throw ValidationError.duplicateExerciseName
        }
    }
}
