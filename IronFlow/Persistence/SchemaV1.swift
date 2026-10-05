import SwiftData

/// Version 1 of the Iron Flow data schema.
///
/// The model classes are declared inside this namespace (see `Models/`) and used
/// through global aliases. A future `SchemaV2` redeclares the changed classes while
/// this version stays intact for migration.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            Workout.self,
            WorkoutExercise.self,
            PlannedSet.self,
            Session.self,
            SessionExercise.self,
            SetLog.self,
        ]
    }
}
