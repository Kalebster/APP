import SwiftData

/// Version 2 of the Iron Flow data schema.
///
/// Adds the user's body data (`BodyWeightEntry`, `UserProfile`). The seven models of
/// `SchemaV1` are unchanged and reused as they are; the migration from V1 only adds tables.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        SchemaV1.models + [
            BodyWeightEntry.self,
            UserProfile.self,
        ]
    }
}
