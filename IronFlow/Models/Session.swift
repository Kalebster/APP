import Foundation
import SwiftData

typealias Session = SchemaV1.Session

extension SchemaV1 {
    /// A performed workout. Part of the history: it keeps its own snapshots and
    /// does not depend on the planned workout still existing.
    @Model
    final class Session {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var startedAt: Date = Date.now
        /// `nil` while the session is in progress.
        var endedAt: Date?
        /// Name of the workout when the session was started.
        var workoutNameSnapshot: String = ""

        /// The planned workout this session came from; `nil` once that workout is deleted.
        var workout: Workout?

        /// The performed exercises. They belong to this session and are deleted with it.
        @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
        var exercises: [SessionExercise] = []

        init(startedAt: Date, workoutNameSnapshot: String) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.startedAt = startedAt
            self.workoutNameSnapshot = workoutNameSnapshot
        }

        var isActive: Bool {
            endedAt == nil
        }

        /// Total duration (`endedAt - startedAt`); `nil` while the session is in progress.
        var duration: TimeInterval? {
            endedAt.map { $0.timeIntervalSince(startedAt) }
        }

        /// `exercises` in performed order.
        var orderedExercises: [SessionExercise] {
            exercises.sortedByPosition()
        }
    }
}
