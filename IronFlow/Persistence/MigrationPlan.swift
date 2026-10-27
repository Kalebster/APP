import SwiftData

/// Migration plan of the data store. New schema versions are appended to `schemas`,
/// each with the stage that migrates from the previous version.
enum IronFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self, SchemaV6.self]
    }

    static var stages: [MigrationStage] {
        [
            // V2 only adds the body data tables; every V1 record is kept as it is.
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            // V3 only adds the table of days trained outside the app; every V2 record is kept as it is.
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
            // V4 only adds the weekly plan table; every V3 record is kept as it is.
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
            // V5 only adds the set type to planned and performed sets. The new attribute has a default,
            // so every set already stored becomes a working set; every other V4 record is kept as it is.
            .lightweight(fromVersion: SchemaV4.self, toVersion: SchemaV5.self),
            // V6 only adds the choices of the BMR calculator to the profile. The new attributes are
            // optional or have a default, so a profile already stored has no sex or date of birth, a
            // moderate activity level and the goal of keeping the weight; every other V5 record is kept
            // as it is.
            .lightweight(fromVersion: SchemaV5.self, toVersion: SchemaV6.self),
        ]
    }
}
