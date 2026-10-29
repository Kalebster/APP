import Foundation
import SwiftData

typealias UserProfile = SchemaV6.UserProfile

extension SchemaV6 {
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
        /// Stable storage key of the sex used by the BMR calculator; read and write it through `sex`.
        /// `nil` until the user chooses. Added in version 6, as every field below.
        var sexRaw: String?
        /// The date of birth as the user chose it in the calculator: day, month (1 = January) and year,
        /// each `nil` until chosen. Kept as calendar numbers, never as a moment, so the day never moves
        /// with the time zone.
        var birthDay: Int?
        var birthMonth: Int?
        var birthYear: Int?
        /// Stable storage key of the activity level; read and write it through `activityLevel`.
        var activityLevelRaw: String = ActivityLevel.moderate.rawValue
        /// Stable storage key of the weight goal; read and write it through `weightGoal`.
        var weightGoalRaw: String = WeightGoal.maintain.rawValue

        init() {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
        }

        var sex: BiologicalSex? {
            get { sexRaw.flatMap(BiologicalSex.init(rawValue:)) }
            set { sexRaw = newValue?.rawValue }
        }

        var activityLevel: ActivityLevel {
            get { ActivityLevel(storageKey: activityLevelRaw) }
            set { activityLevelRaw = newValue.rawValue }
        }

        var weightGoal: WeightGoal {
            get { WeightGoal(storageKey: weightGoalRaw) }
            set { weightGoalRaw = newValue.rawValue }
        }

        /// The date of birth chosen so far.
        var birthDate: BirthDate {
            BirthDate(day: birthDay, month: birthMonth, year: birthYear)
        }
    }
}
