import Foundation
import SwiftData

/// Business rules for planned workouts, their exercises and planned sets.
///
/// Every workout item keeps at least one planned set, and `sortIndex` values stay 0...n-1.
@MainActor
struct WorkoutService {
    /// Planned sets of an exercise added from the picker: 3 sets of 8–12 reps, no load.
    static let defaultPlannedSets = Array(repeating: PlannedSetValues(weightKg: nil, repsMin: 8, repsMax: 12), count: 3)

    let context: ModelContext
    let now: @MainActor () -> Date

    init(context: ModelContext, now: @escaping @MainActor () -> Date = { Date.now }) {
        self.context = context
        self.now = now
    }

    // MARK: - Workout

    @discardableResult
    func createWorkout(name: String) throws -> Workout {
        let validName = try Validation.name(name)

        let timestamp = now()
        let workout = Workout(name: validName)
        workout.createdAt = timestamp
        workout.updatedAt = timestamp
        context.insert(workout)
        try context.saveOrRollback()
        return workout
    }

    /// Renames the plan. Sessions keep the name they were started with.
    func rename(_ workout: Workout, to name: String) throws {
        let validName = try Validation.name(name)

        workout.name = validName
        workout.updatedAt = now()
        try context.saveOrRollback()
    }

    /// Deletes the plan (its items and planned sets). Sessions are history and are
    /// kept: they only lose the link to the workout.
    func delete(_ workout: Workout) throws {
        context.delete(workout)
        try context.saveOrRollback()
    }

    // MARK: - Exercises

    /// Appends the exercise to the workout together with its first planned set.
    @discardableResult
    func addExercise(_ exercise: Exercise, to workout: Workout, firstSet: PlannedSetValues) throws -> WorkoutExercise {
        try firstSet.validate()
        guard !exercise.isArchived else { throw WorkoutError.exerciseArchived }

        let timestamp = now()
        let item = WorkoutExercise(sortIndex: workout.exercises.count)
        item.createdAt = timestamp
        item.updatedAt = timestamp
        context.insert(item)
        item.workout = workout
        item.exercise = exercise

        let plannedSet = makePlannedSet(sortIndex: 0, values: firstSet, at: timestamp)
        plannedSet.workoutExercise = item

        workout.updatedAt = timestamp
        try context.saveOrRollback()
        return item
    }

    /// Appends the exercises in the given order, each with `sets`. All or nothing: if any
    /// exercise is archived, already in the workout or repeated, or any set is invalid,
    /// nothing is changed.
    @discardableResult
    func addExercises(
        _ exercises: [Exercise],
        to workout: Workout,
        sets: [PlannedSetValues] = WorkoutService.defaultPlannedSets
    ) throws -> [WorkoutExercise] {
        guard !sets.isEmpty else { throw WorkoutError.plannedSetsMissing }
        for values in sets {
            try values.validate()
        }
        var usedIDs = Set(workout.exercises.compactMap { $0.exercise?.id })
        for exercise in exercises {
            guard !exercise.isArchived else { throw WorkoutError.exerciseArchived }
            guard usedIDs.insert(exercise.id).inserted else { throw WorkoutError.exerciseAlreadyInWorkout }
        }
        guard !exercises.isEmpty else { return [] }

        let timestamp = now()
        let firstIndex = workout.exercises.count
        let items = exercises.enumerated().map { offset, exercise in
            let item = WorkoutExercise(sortIndex: firstIndex + offset)
            item.createdAt = timestamp
            item.updatedAt = timestamp
            context.insert(item)
            item.workout = workout
            item.exercise = exercise
            for (setIndex, values) in sets.enumerated() {
                makePlannedSet(sortIndex: setIndex, values: values, at: timestamp).workoutExercise = item
            }
            return item
        }

        workout.updatedAt = timestamp
        try context.saveOrRollback()
        return items
    }

    /// Removes the item and its planned sets, then renumbers the remaining items.
    func removeExercise(_ item: WorkoutExercise) throws {
        let timestamp = now()
        if let workout = item.workout {
            let remaining = workout.orderedExercises.filter { $0.id != item.id }
            SortIndexing.renumber(remaining, at: timestamp)
            workout.updatedAt = timestamp
        }
        context.delete(item)
        try context.saveOrRollback()
    }

    /// Reorders the workout's items, like SwiftUI's `onMove`.
    func moveExercises(in workout: Workout, fromOffsets source: IndexSet, toOffset destination: Int) throws {
        let reordered = try SortIndexing.moved(workout.orderedExercises, fromOffsets: source, toOffset: destination)

        let timestamp = now()
        SortIndexing.renumber(reordered, at: timestamp)
        workout.updatedAt = timestamp
        try context.saveOrRollback()
    }

    // MARK: - Planned sets

    @discardableResult
    func addPlannedSet(to item: WorkoutExercise, values: PlannedSetValues) throws -> PlannedSet {
        try values.validate()

        let timestamp = now()
        let plannedSet = makePlannedSet(sortIndex: item.plannedSets.count, values: values, at: timestamp)
        plannedSet.workoutExercise = item
        item.workout?.updatedAt = timestamp
        try context.saveOrRollback()
        return plannedSet
    }

    func updatePlannedSet(_ plannedSet: PlannedSet, values: PlannedSetValues) throws {
        try values.validate()

        let timestamp = now()
        plannedSet.weightKg = values.weightKg
        plannedSet.repsMin = values.repsMin
        plannedSet.repsMax = values.repsMax
        plannedSet.updatedAt = timestamp
        plannedSet.workoutExercise?.workout?.updatedAt = timestamp
        try context.saveOrRollback()
    }

    /// Removes a planned set and renumbers the others. The last set cannot be removed:
    /// remove the whole exercise from the workout instead.
    func removePlannedSet(_ plannedSet: PlannedSet) throws {
        let timestamp = now()
        if let item = plannedSet.workoutExercise {
            guard item.plannedSets.count > 1 else { throw WorkoutError.lastPlannedSet }
            let remaining = item.orderedPlannedSets.filter { $0.id != plannedSet.id }
            SortIndexing.renumber(remaining, at: timestamp)
            item.workout?.updatedAt = timestamp
        }
        context.delete(plannedSet)
        try context.saveOrRollback()
    }

    /// Reorders an item's planned sets, like SwiftUI's `onMove`.
    func movePlannedSets(in item: WorkoutExercise, fromOffsets source: IndexSet, toOffset destination: Int) throws {
        let reordered = try SortIndexing.moved(item.orderedPlannedSets, fromOffsets: source, toOffset: destination)

        let timestamp = now()
        SortIndexing.renumber(reordered, at: timestamp)
        item.workout?.updatedAt = timestamp
        try context.saveOrRollback()
    }

    // MARK: - Private

    private func makePlannedSet(sortIndex: Int, values: PlannedSetValues, at timestamp: Date) -> PlannedSet {
        let plannedSet = PlannedSet(
            sortIndex: sortIndex,
            weightKg: values.weightKg,
            repsMin: values.repsMin,
            repsMax: values.repsMax
        )
        plannedSet.createdAt = timestamp
        plannedSet.updatedAt = timestamp
        context.insert(plannedSet)
        return plannedSet
    }
}
