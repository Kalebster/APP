import Foundation

/// The exercises chosen in the picker, in the order they were chosen.
/// Exercises already in the workout and archived exercises cannot be chosen.
/// Pure logic: no UI and no store access.
struct ExerciseSelection {
    /// Library exercises already in the workout.
    let workoutExerciseIDs: Set<UUID>
    private(set) var selectedIDs: [UUID] = []

    var count: Int { selectedIDs.count }

    func isInWorkout(_ exercise: Exercise) -> Bool {
        workoutExerciseIDs.contains(exercise.id)
    }

    func isSelected(_ exercise: Exercise) -> Bool {
        selectedIDs.contains(exercise.id)
    }

    /// Selects the exercise, or deselects it when it is already selected.
    mutating func toggle(_ exercise: Exercise) {
        guard !isInWorkout(exercise), !exercise.isArchived else { return }
        if let index = selectedIDs.firstIndex(of: exercise.id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(exercise.id)
        }
    }

    /// The selected exercises found in `exercises`, in selection order.
    func selectedExercises(from exercises: [Exercise]) -> [Exercise] {
        let exercisesByID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return selectedIDs.compactMap { exercisesByID[$0] }
    }
}
