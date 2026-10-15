import Foundation
import SwiftData

/// Business rules for the days the user trained outside the app: marking and unmarking a day.
///
/// A day holds at most one marking. The rule is kept here, by looking before inserting, and not by
/// a uniqueness constraint in the store, which would replace a record silently.
@MainActor
struct ExternalWorkoutService {
    let context: ModelContext
    let now: @MainActor () -> Date
    let calendar: Calendar

    init(
        context: ModelContext,
        now: @escaping @MainActor () -> Date = { Date.now },
        calendar: Calendar = TrainingDay.calendar
    ) {
        self.context = context
        self.now = now
        self.calendar = calendar
    }

    /// Marks the day of `date` (any moment of it) as trained outside the app. Today and past days
    /// only; a day already marked is not marked again.
    @discardableResult
    func mark(_ date: Date) throws -> ExternalWorkoutDay {
        let timestamp = now()
        let day = TrainingDay.key(for: date, calendar: calendar)
        // Keys are "AAAA-MM-DD", so their order is the order of the days.
        guard day <= TrainingDay.key(for: timestamp, calendar: calendar) else { throw ExternalWorkoutError.futureDay }
        guard try markings(of: day).isEmpty else { throw ExternalWorkoutError.alreadyMarked }

        let marking = ExternalWorkoutDay(day: day)
        marking.createdAt = timestamp
        marking.updatedAt = timestamp
        context.insert(marking)
        try context.saveOrRollback()
        return marking
    }

    /// Removes the marking of the day of `date`. A day without a marking is left as it is; should
    /// the store hold more than one marking of the day, all of them are removed.
    func unmark(_ date: Date) throws {
        let found = try markings(of: TrainingDay.key(for: date, calendar: calendar))
        guard !found.isEmpty else { return }
        for marking in found {
            context.delete(marking)
        }
        try context.saveOrRollback()
    }

    // MARK: - Private

    private func markings(of day: String) throws -> [ExternalWorkoutDay] {
        try context.fetch(FetchDescriptor<ExternalWorkoutDay>(predicate: #Predicate { $0.day == day }))
    }
}
