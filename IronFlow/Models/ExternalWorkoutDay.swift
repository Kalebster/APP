import Foundation
import SwiftData

typealias ExternalWorkoutDay = SchemaV3.ExternalWorkoutDay

extension SchemaV3 {
    /// A day the user marked as trained outside the app.
    ///
    /// The day is a calendar date ("2026-10-15"), so it stays the same day in any time zone. A day has
    /// at most one marking: `ExternalWorkoutService` looks before inserting. There is no uniqueness
    /// constraint on `day`, because a constraint would make the store replace a record silently.
    @Model
    final class ExternalWorkoutDay {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        /// The calendar date, "AAAA-MM-DD" (see `TrainingDay.key(for:calendar:)`).
        var day: String = ""

        init(day: String) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.day = day
        }
    }
}
