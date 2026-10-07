import Foundation
import SwiftData

/// Business rules for the user's body data: body weight history, height and daily calorie goal.
@MainActor
struct ProfileService {
    let context: ModelContext
    let now: @MainActor () -> Date

    init(context: ModelContext, now: @escaping @MainActor () -> Date = { Date.now }) {
        self.context = context
        self.now = now
    }

    /// The most recent body weight measurement, if any.
    func latestWeight() throws -> BodyWeightEntry? {
        var descriptor = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\.measuredAt, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// The user's profile, if it was ever saved. If a store holds more than one, the oldest is used.
    func profile() throws -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Records a new body weight measured now. Earlier measurements are kept as history.
    @discardableResult
    func recordWeight(_ weightKg: Double) throws -> BodyWeightEntry {
        try Validation.bodyWeight(weightKg)

        let timestamp = now()
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
