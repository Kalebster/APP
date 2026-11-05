import SwiftData

/// Version 7 of the Iron Flow data schema: the current one.
///
/// Adds the rest between sets (`restSeconds`) to `WorkoutExercise` and `SessionExercise`. The seven
/// main models are redeclared here (see `Models/`), not only those two: their relationships point to
/// each other's classes, so a version 5 class reused here would still point to the version 5 ones. The
/// models without relationships (body data, profile, days trained outside the app, weekly plan) are
/// unchanged and reused as they are. The migration from V6 only adds the rest, 1 min 30 s for every
/// exercise already stored. Frozen once released: every model is named explicitly, never through the
/// app's aliases.
enum SchemaV7: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(7, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            SchemaV7.Exercise.self,
            SchemaV7.Workout.self,
            SchemaV7.WorkoutExercise.self,
            SchemaV7.PlannedSet.self,
            SchemaV7.Session.self,
            SchemaV7.SessionExercise.self,
            SchemaV7.SetLog.self,
            SchemaV2.BodyWeightEntry.self,
            SchemaV6.UserProfile.self,
            SchemaV3.ExternalWorkoutDay.self,
            SchemaV4.WeeklyPlanDay.self,
        ]
    }
}
