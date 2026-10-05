import Foundation
import SwiftData

typealias WorkoutExercise = SchemaV1.WorkoutExercise

extension SchemaV1 {
    /// An exercise inside a planned workout, with its planned sets.
    @Model
    final class WorkoutExercise {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        /// Position inside the workout; the plan order is defined by this value only.
        var sortIndex: Int = 0

        var workout: Workout?
        var exercise: Exercise?

        /// The planned sets. They belong to this item and are deleted with it.
        @Relationship(deleteRule: .cascade, inverse: \PlannedSet.workoutExercise)
        var plannedSets: [PlannedSet] = []

        init(sortIndex: Int) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.sortIndex = sortIndex
        }

        /// `plannedSets` in set order.
        var orderedPlannedSets: [PlannedSet] {
            plannedSets.sortedByPosition()
        }
    }
}
