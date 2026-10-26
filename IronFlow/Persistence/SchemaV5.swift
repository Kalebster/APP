import SwiftData

/// Version 5 of the Iron Flow data schema: the current one.
///
/// Adds the set type (`setTypeRaw`) to `PlannedSet` and `SetLog`. The seven models of `SchemaV1` are
/// redeclared here (see `Models/`), not only those two: their relationships point to each other's
/// classes, so a version 1 class reused here would still point to the version 1 sets. The models
/// without relationships (body data, days trained outside the app, weekly plan) are unchanged and
/// reused as they are. The migration from V4 only adds the type, as a working set for every set
/// already stored.
enum SchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(5, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            SchemaV5.Exercise.self,
            SchemaV5.Workout.self,
            SchemaV5.WorkoutExercise.self,
            SchemaV5.PlannedSet.self,
            SchemaV5.Session.self,
            SchemaV5.SessionExercise.self,
            SchemaV5.SetLog.self,
            SchemaV2.BodyWeightEntry.self,
            SchemaV2.UserProfile.self,
            SchemaV3.ExternalWorkoutDay.self,
            SchemaV4.WeeklyPlanDay.self,
        ]
    }
}
