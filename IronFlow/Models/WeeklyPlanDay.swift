import Foundation
import SwiftData

typealias WeeklyPlanDay = SchemaV4.WeeklyPlanDay

extension SchemaV4 {
    /// The workout planned for one day of the week. A day without a record is a rest day.
    ///
    /// The workout is kept as its `id`, not as a relationship: `Workout` is a model of released schema
    /// versions and must not change. A day whose workout no longer exists is a rest day too, and
    /// `WorkoutService.delete` removes the days of the workout it deletes. A weekday has at most one
    /// record: `WeeklyPlanService` looks before inserting. There is no uniqueness constraint on
    /// `weekday`, because a constraint would make the store replace a record silently.
    @Model
    final class WeeklyPlanDay {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        /// 1 = Monday to 7 = Sunday (`TrainingDay.planWeekdays`). Not the `Calendar` weekday, where
        /// 1 is Sunday.
        var weekday: Int = 1
        /// The `id` of the planned `Workout`.
        var workoutID: UUID = UUID()

        init(weekday: Int, workoutID: UUID) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.weekday = weekday
            self.workoutID = workoutID
        }
    }
}
