import SwiftData

/// Migration plan of the data store. New schema versions are appended to `schemas`,
/// each with the stage that migrates from the previous version.
enum IronFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            // V2 only adds the body data tables; every V1 record is kept as it is.
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
        ]
    }
}
