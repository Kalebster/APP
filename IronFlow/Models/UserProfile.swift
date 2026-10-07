import Foundation
import SwiftData

typealias UserProfile = SchemaV2.UserProfile

extension SchemaV2 {
    /// The user's own data that has a single current value. The store holds at most one profile.
    @Model
    final class UserProfile {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        /// Height in centimeters; `nil` until the user enters it.
        var heightCm: Int?
        /// Daily calorie goal in kilocalories; `nil` until the user enters it.
        var dailyCalorieGoalKcal: Int?

        init() {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
        }
    }
}
