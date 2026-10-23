import SwiftData

/// Version 3 of the Iron Flow data schema.
///
/// Adds the days the user marked as trained outside the app (`ExternalWorkoutDay`). Every model of
/// `SchemaV2` is unchanged and reused as it is; the migration from V2 only adds a table.
/// Frozen: every model is named explicitly, never through the app's aliases.
enum SchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        SchemaV2.models + [
            SchemaV3.ExternalWorkoutDay.self,
        ]
    }
}
