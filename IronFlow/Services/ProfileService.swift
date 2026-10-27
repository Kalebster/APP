import Foundation
import SwiftData

/// Business rules for the user's body data: body weight history, height and daily calorie goal.
@MainActor
struct ProfileService {
    let context: ModelContext
    let now: @MainActor () -> Date
    /// The calendar of the days: a body weight is recorded once per day of it.
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

    /// The most recent body weight measurement, if any.
    func latestWeight() throws -> BodyWeightEntry? {
        try context.fetch(Self.latestWeightDescriptor).first
    }

    /// The user's profile, if it was ever saved. If a store holds more than one, the oldest is used.
    func profile() throws -> UserProfile? {
        try context.fetch(Self.profileDescriptor).first
    }

    /// The most recent measurement only. Shared with the screens that observe it.
    nonisolated static var latestWeightDescriptor: FetchDescriptor<BodyWeightEntry> {
        var descriptor = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// How many records the body weight editor lists ("ÚLTIMOS REGISTROS").
    nonisolated static var recentWeightsLimit: Int { 4 }

    /// The latest measurements, the newest first, at most `recentWeightsLimit`. Shared with the editor.
    nonisolated static var recentWeightsDescriptor: FetchDescriptor<BodyWeightEntry> {
        var descriptor = latestWeightDescriptor
        descriptor.fetchLimit = recentWeightsLimit
        return descriptor
    }

    /// The profile in use: the oldest. Shared with the screens that observe it.
    nonisolated static var profileDescriptor: FetchDescriptor<UserProfile> {
        var descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// Records the body weight measured now. A day has one record: when today already has one, it is
    /// updated (its value and time); otherwise a new record is added. The records of the other days are
    /// the history and never change. Should today hold more than one (recorded before this rule), the
    /// latest is the one updated.
    @discardableResult
    func recordWeight(_ weightKg: Double) throws -> BodyWeightEntry {
        try Validation.bodyWeight(weightKg)

        let timestamp = now()
        let day = TrainingDay.dayInterval(of: timestamp, calendar: calendar)
        let start = day.start
        let end = day.end
        var todays = FetchDescriptor<BodyWeightEntry>(
            predicate: #Predicate { $0.measuredAt >= start && $0.measuredAt < end },
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        todays.fetchLimit = 1
        if let today = try context.fetch(todays).first {
            today.weightKg = weightKg
            today.measuredAt = timestamp
            today.updatedAt = timestamp
            try context.saveOrRollback()
            return today
        }

        let entry = BodyWeightEntry(weightKg: weightKg, measuredAt: timestamp)
        entry.createdAt = timestamp
        entry.updatedAt = timestamp
        context.insert(entry)
        try context.saveOrRollback()
        return entry
    }

    func setHeight(_ heightCm: Int) throws {
        try Validation.height(heightCm)
        let profile = try profileForChange()
        profile.heightCm = heightCm
        profile.updatedAt = now()
        try context.saveOrRollback()
    }

    func setDailyCalorieGoal(_ kcal: Int) throws {
        try Validation.dailyCalorieGoal(kcal)
        let profile = try profileForChange()
        profile.dailyCalorieGoalKcal = kcal
        profile.updatedAt = now()
        try context.saveOrRollback()
    }

    // MARK: - Private

    /// The existing profile, or a new one inserted (not saved) on the first change.
    private func profileForChange() throws -> UserProfile {
        if let profile = try profile() {
            return profile
        }
        let timestamp = now()
        let profile = UserProfile()
        profile.createdAt = timestamp
        profile.updatedAt = timestamp
        context.insert(profile)
        return profile
    }
}
