import Foundation
import SwiftData

typealias PlannedSet = SchemaV1.PlannedSet

extension SchemaV1 {
    /// One planned set of an exercise in a workout.
    @Model
    final class PlannedSet {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        /// Position inside the exercise; the set order is defined by this value only.
        var sortIndex: Int = 0
        /// Planned load in kilograms; `nil` when no load is planned.
        var weightKg: Double?
        var repsMin: Int = 1
        var repsMax: Int = 1

        var workoutExercise: WorkoutExercise?

        init(sortIndex: Int, weightKg: Double?, repsMin: Int, repsMax: Int) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.sortIndex = sortIndex
            self.weightKg = weightKg
            self.repsMin = repsMin
            self.repsMax = repsMax
        }
    }
}
