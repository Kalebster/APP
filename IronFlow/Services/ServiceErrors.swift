import Foundation

/// Invalid input. Always thrown before anything is changed.
enum ValidationError: Error, Equatable {
    case emptyName
    case nameTooLong
    case duplicateExerciseName
    case invalidRepsMin
    case invalidRepsMax
    /// More repetitions than a planned set allows.
    case repsTooHigh
    case repsMinGreaterThanMax
    case negativeWeight
    case invalidWeight
    case tooManyDecimals
    /// More load than a planned set allows.
    case weightTooHigh
    case invalidReps
    /// A body weight outside the allowed range or with more than two decimal places.
    case invalidBodyWeight
    /// A height that is not a whole number of centimeters within the allowed range.
    case invalidHeight
    /// A daily calorie goal that is not a whole number of kilocalories within the allowed range.
    case invalidCalorieGoal
}

/// An exercise operation that the business rules do not allow.
enum ExerciseError: Error, Equatable {
    case systemExerciseNotEditable
    case systemExerciseNotDeletable
    /// The exercise is used in these workouts; removing it needs explicit confirmation.
    case confirmationRequired(workoutIDs: [UUID])
}

/// A workout operation that the business rules do not allow.
enum WorkoutError: Error, Equatable {
    case exerciseArchived
    /// The exercise is already in the workout (or chosen twice in the same request).
    case exerciseAlreadyInWorkout
    case lastPlannedSet
    case workoutHasNoExercises
    /// A workout item has no library exercise.
    case exerciseMissing
    /// A workout item has no planned sets.
    case plannedSetsMissing
    case invalidPosition
}

/// A session operation that conflicts with the current state.
enum SessionError: Error, Equatable {
    case activeSessionExists
    /// More than one session without `endedAt` exists; the store is inconsistent.
    case multipleActiveSessions
    case sessionNotActive
    case noCompletedSets
    case repsRequired
}

/// Saving failed. All unsaved changes of the operation were discarded.
enum SaveError: Error, Equatable {
    case saveFailed(String)
}
