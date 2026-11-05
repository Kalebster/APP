import Foundation
import SwiftData

typealias WorkoutExercise = SchemaV7.WorkoutExercise

extension SchemaV7 {
    /// An exercise inside a planned workout, with its planned sets.
    @Model
    final class WorkoutExercise {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        /// Position inside the workout; the plan order is defined by this value only.
        var sortIndex: Int = 0
        /// The rest between sets, in seconds, copied to the session when it starts; 0 is "Sem timer".
        /// Added in version 7; the exercises of older stores are migrated with the default, 1 min 30 s.
        var restSeconds: Int = RestDuration.defaultSeconds

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
