import Foundation

/// The exercises chosen in the picker, by id, in the order they were chosen.
/// Exercises already in the workout cannot be chosen, and archived exercises are never returned.
/// Pure logic: no UI and no store access.
struct ExerciseSelection {
    /// Library exercises already in the workout.
    let workoutExerciseIDs: Set<UUID>
    private(set) var selectedIDs: [UUID] = []

    var count: Int { selectedIDs.count }

    func isInWorkout(_ id: UUID) -> Bool {
        workoutExerciseIDs.contains(id)
    }

    func isSelected(_ id: UUID) -> Bool {
        selectedIDs.contains(id)
    }

    /// Selects the exercise, or deselects it when it is already selected.
    mutating func toggle(_ id: UUID) {
        guard !isInWorkout(id) else { return }
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(id)
        }
    }

    /// The selected exercises found in `exercises`, in selection order, without the archived ones.
    func selectedExercises(from exercises: [Exercise]) -> [Exercise] {
        let exercisesByID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return selectedIDs.compactMap { exercisesByID[$0] }.filter { !$0.isArchived }
    }
}
