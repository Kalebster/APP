import SwiftData

/// Migration plan of the data store. New schema versions are appended to `schemas`,
/// each with the stage that migrates from the previous version.
enum IronFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
