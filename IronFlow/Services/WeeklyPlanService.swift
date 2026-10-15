import Foundation
import SwiftData

/// Business rules for the weekly plan: the workout of each day of the week, or a rest day.
///
/// A weekday holds at most one record. The rule is kept here, by looking before inserting, and not
/// by a uniqueness constraint in the store, which would replace a record silently. The same workout
/// can be planned on several days.
@MainActor
struct WeeklyPlanService {
    let context: ModelContext
    let now: @MainActor () -> Date

    init(context: ModelContext, now: @escaping @MainActor () -> Date = { Date.now }) {
        self.context = context
        self.now = now
    }

    /// Plans `workout` for `weekday` (1 = Monday to 7 = Sunday), replacing the workout of that day.
    /// Planning the workout the day already has changes nothing. Should the store hold more than one
    /// record of the weekday, the oldest is kept and the others are removed.
    @discardableResult
    func setWorkout(_ workout: Workout, for weekday: Int) throws -> WeeklyPlanDay {
        guard TrainingDay.planWeekdays.contains(weekday) else { throw WeeklyPlanError.invalidWeekday }

        let found = try records(of: weekday)
        guard let kept = found.first else {
            let timestamp = now()
            let record = WeeklyPlanDay(weekday: weekday, workoutID: workout.id)
            record.createdAt = timestamp
            record.updatedAt = timestamp
            context.insert(record)
            try context.saveOrRollback()
            return record
        }
        guard kept.workoutID != workout.id || found.count > 1 else { return kept }

        if kept.workoutID != workout.id {
            kept.workoutID = workout.id
            kept.updatedAt = now()
        }
        for extra in found.dropFirst() {
            context.delete(extra)
        }
        try context.saveOrRollback()
        return kept
    }

    /// Makes `weekday` a rest day. A day without a workout is left as it is.
    func clear(weekday: Int) throws {
        guard TrainingDay.planWeekdays.contains(weekday) else { throw WeeklyPlanError.invalidWeekday }

        let found = try records(of: weekday)
        guard !found.isEmpty else { return }
        for record in found {
            context.delete(record)
        }
        try context.saveOrRollback()
    }

    // MARK: - Private

    /// The records of `weekday`, the oldest first.
    private func records(of weekday: Int) throws -> [WeeklyPlanDay] {
        try context.fetch(FetchDescriptor<WeeklyPlanDay>(predicate: #Predicate { $0.weekday == weekday }))
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }
}
