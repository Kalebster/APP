import SwiftData

/// Version 4 of the Iron Flow data schema.
///
/// Adds the weekly plan (`WeeklyPlanDay`). Every model of `SchemaV3` is unchanged and reused as it
/// is; the migration from V3 only adds a table.
enum SchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(4, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        SchemaV3.models + [
            WeeklyPlanDay.self,
        ]
    }
}
