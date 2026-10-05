import Foundation
import SwiftData

typealias SetLog = SchemaV1.SetLog

extension SchemaV1 {
    /// One set of a performed exercise. A set that was not done stays recorded with
    /// `isCompleted == false` and `completedAt == nil`.
    @Model
    final class SetLog {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        /// Position inside the exercise; the set order is defined by this value only.
        var sortIndex: Int = 0
        /// Load used, in kilograms.
        var weightKg: Double?
        /// Repetitions performed.
        var reps: Int?
        var isCompleted: Bool = false
        var completedAt: Date?
        /// Planned targets copied when the session was created, so the history keeps them.
        var targetWeightKg: Double?
        var targetRepsMin: Int?
        var targetRepsMax: Int?

        var sessionExercise: SessionExercise?

        init(
            sortIndex: Int,
            weightKg: Double? = nil,
            reps: Int? = nil,
            targetWeightKg: Double? = nil,
            targetRepsMin: Int? = nil,
            targetRepsMax: Int? = nil
        ) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.sortIndex = sortIndex
            self.weightKg = weightKg
            self.reps = reps
            self.targetWeightKg = targetWeightKg
            self.targetRepsMin = targetRepsMin
            self.targetRepsMax = targetRepsMax
        }
    }
}
