import Foundation
import SwiftData

/// Version 2 of the Iron Flow data schema.
///
/// Adds the user's body data (`BodyWeightEntry`, `UserProfile`). The seven models of
/// `SchemaV1` are unchanged and reused as they are; the migration from V1 only adds tables.
/// Frozen: every model is named explicitly, never through the app's aliases. Its `UserProfile` is
/// declared below as it was released; `BodyWeightEntry`, unchanged since, is still the app's (see
/// `Models/`).
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        SchemaV1.models + [
            SchemaV2.BodyWeightEntry.self,
            SchemaV2.UserProfile.self,
        ]
    }
}

extension SchemaV2 {
    /// The user's profile exactly as version 2 released it, frozen since version 6 redeclared it. The
    /// app does not use this class; it only describes the stores to migrate. `SchemaFreezeTests` checks
    /// that it still writes the released store.
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
