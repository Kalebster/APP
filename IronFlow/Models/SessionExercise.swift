import Foundation
import SwiftData

typealias SessionExercise = SchemaV1.SessionExercise

extension SchemaV1 {
    /// An exercise performed in a session. Keeps snapshots so the history stays
    /// readable after the original exercise is renamed, archived or deleted.
    @Model
    final class SessionExercise {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        /// Position inside the session; the order is defined by this value only.
        var sortIndex: Int = 0
        /// Name of the exercise when it was performed.
        var exerciseNameSnapshot: String = ""
        /// Stable storage key of the muscle group when it was performed.
        var muscleGroupSnapshotRaw: String = MuscleGroup.other.rawValue

        var session: Session?
        /// The library exercise; `nil` once that exercise is deleted.
        var exercise: Exercise?

        /// The performed sets. They belong to this item and are deleted with it.
        @Relationship(deleteRule: .cascade, inverse: \SetLog.sessionExercise)
        var setLogs: [SetLog] = []

        init(sortIndex: Int, exerciseNameSnapshot: String, muscleGroupSnapshot: MuscleGroup) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.sortIndex = sortIndex
            self.exerciseNameSnapshot = exerciseNameSnapshot
            self.muscleGroupSnapshotRaw = muscleGroupSnapshot.rawValue
        }

        var muscleGroupSnapshot: MuscleGroup {
            MuscleGroup(storageKey: muscleGroupSnapshotRaw)
        }

        /// `setLogs` in set order.
        var orderedSetLogs: [SetLog] {
            setLogs.sortedByPosition()
        }
    }
}
