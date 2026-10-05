import Foundation
import SwiftData

typealias Exercise = SchemaV1.Exercise

extension SchemaV1 {
    /// An exercise in the library: built into the app or created by the user.
    @Model
    final class Exercise {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var name: String = ""
        /// Stable storage key of the muscle group; read and write it through `muscleGroup`.
        var muscleGroupRaw: String = MuscleGroup.other.rawValue
        var isCustom: Bool = false
        var isArchived: Bool = false
        /// Stable key of a built-in exercise; `nil` for custom exercises.
        var libraryKey: String?

        /// Planned uses of this exercise. Deleting the exercise only clears the reference.
        @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
        var workoutExercises: [WorkoutExercise] = []

        /// Performed uses of this exercise (history). Deleting the exercise only clears
        /// the reference; the history stays readable through its snapshots.
        @Relationship(deleteRule: .nullify, inverse: \SessionExercise.exercise)
        var sessionExercises: [SessionExercise] = []

        init(name: String, muscleGroup: MuscleGroup, isCustom: Bool, libraryKey: String? = nil) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.name = name
            self.muscleGroupRaw = muscleGroup.rawValue
            self.isCustom = isCustom
            self.libraryKey = libraryKey
        }

        var muscleGroup: MuscleGroup {
            get { MuscleGroup(storageKey: muscleGroupRaw) }
            set { muscleGroupRaw = newValue.rawValue }
        }
    }
}
