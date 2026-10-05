import Foundation
import SwiftData

typealias Workout = SchemaV1.Workout

extension SchemaV1 {
    /// A planned workout (template).
    @Model
    final class Workout {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var name: String = ""

        /// The plan's exercises. They belong to this workout and are deleted with it.
        @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
        var exercises: [WorkoutExercise] = []

        /// Sessions started from this workout. Deleting the workout only clears
        /// `Session.workout`: sessions are history and are never deleted with it.
        @Relationship(deleteRule: .nullify, inverse: \Session.workout)
        var sessions: [Session] = []

        init(name: String) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.name = name
        }

        /// `exercises` in plan order.
        var orderedExercises: [WorkoutExercise] {
            exercises.sortedByPosition()
        }
    }
}
