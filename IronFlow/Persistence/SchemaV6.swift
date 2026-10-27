import SwiftData

/// Version 6 of the Iron Flow data schema: the current one.
///
/// Adds to `UserProfile` what the BMR calculator asks: sex, date of birth, activity level and goal.
/// Only `UserProfile` is redeclared here (see `Models/`): it has no relationships, so every other
/// model of `SchemaV5` is unchanged and reused as it is. The migration from V5 only adds the new
/// attributes: they are optional or have a default, so every profile already stored keeps its values,
/// with no sex or date of birth, a moderate activity level and the goal of keeping the weight.
enum SchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(6, 0, 0)
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
            SchemaV6.UserProfile.self,
            SchemaV3.ExternalWorkoutDay.self,
            SchemaV4.WeeklyPlanDay.self,
        ]
    }
}
