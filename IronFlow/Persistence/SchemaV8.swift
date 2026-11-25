import SwiftData

/// Version 8 of the Iron Flow data schema: the current one.
///
/// Adds to `Exercise` what an exercise of the user's own chooses: its equipment, its kind of machine and
/// its main and secondary muscles, as stable keys (`Equipment`, `MachineType`, `Muscle`). The seven main
/// models are redeclared here (see `Models/`), not only `Exercise`: their relationships point to each
/// other's classes, so a version 7 class reused here would still point to the version 7 ones. The models
/// without relationships (body data, profile, days trained outside the app, weekly plan) are unchanged
/// and reused as they are. The migration from V7 only adds the new attributes, optional or empty: every
/// exercise already stored has no equipment ("Outro"), no kind of machine and no muscles of its own, so
/// the exercise screen keeps showing the muscle of its group. Frozen once released: every model is named
/// explicitly, never through the app's aliases.
enum SchemaV8: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(8, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            SchemaV8.Exercise.self,
            SchemaV8.Workout.self,
            SchemaV8.WorkoutExercise.self,
            SchemaV8.PlannedSet.self,
            SchemaV8.Session.self,
            SchemaV8.SessionExercise.self,
            SchemaV8.SetLog.self,
            SchemaV2.BodyWeightEntry.self,
            SchemaV6.UserProfile.self,
            SchemaV3.ExternalWorkoutDay.self,
            SchemaV4.WeeklyPlanDay.self,
        ]
    }
}
