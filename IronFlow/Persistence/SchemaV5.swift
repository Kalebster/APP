import Foundation
import SwiftData

/// Version 5 of the Iron Flow data schema.
///
/// Adds the set type (`setTypeRaw`) to `PlannedSet` and `SetLog`. The seven models of `SchemaV1` are
/// redeclared here (below, as they were released; the app's own are those of `SchemaV7`), not only
/// those two: their relationships point to each other's
/// classes, so a version 1 class reused here would still point to the version 1 sets. The models
/// without relationships (body data, days trained outside the app, weekly plan) are unchanged and
/// reused as they are. The migration from V4 only adds the type, as a working set for every set
/// already stored. Frozen: every model is named explicitly, never through the app's aliases.
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

// The seven main models exactly as version 5 released them (they were the app's models until version 7):
// the same stored properties, relationships, delete rules and unique ids, every type named explicitly.
// The app does not use these classes; they only describe the stores to migrate. `SchemaFreezeTests`
// checks that they still write the released store.
extension SchemaV5 {
    @Model
    final class Exercise {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var name: String = ""
        var muscleGroupRaw: String = MuscleGroup.other.rawValue
        var isCustom: Bool = false
        var isArchived: Bool = false
        var libraryKey: String?

        @Relationship(deleteRule: .nullify, inverse: \SchemaV5.WorkoutExercise.exercise)
        var workoutExercises: [SchemaV5.WorkoutExercise] = []

        @Relationship(deleteRule: .nullify, inverse: \SchemaV5.SessionExercise.exercise)
        var sessionExercises: [SchemaV5.SessionExercise] = []

        init(name: String, muscleGroup: MuscleGroup, isCustom: Bool, libraryKey: String? = nil) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.name = name
            self.muscleGroupRaw = muscleGroup.rawValue
            self.isCustom = isCustom
            self.libraryKey = libraryKey
        }
    }

    @Model
    final class Workout {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var name: String = ""

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.WorkoutExercise.workout)
        var exercises: [SchemaV5.WorkoutExercise] = []

        @Relationship(deleteRule: .nullify, inverse: \SchemaV5.Session.workout)
        var sessions: [SchemaV5.Session] = []

        init(name: String) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.name = name
        }
    }

    @Model
    final class WorkoutExercise {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var sortIndex: Int = 0

        var workout: SchemaV5.Workout?
        var exercise: SchemaV5.Exercise?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.PlannedSet.workoutExercise)
        var plannedSets: [SchemaV5.PlannedSet] = []

        init(sortIndex: Int) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.sortIndex = sortIndex
        }
    }

    @Model
    final class PlannedSet {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var sortIndex: Int = 0
        var weightKg: Double?
        var repsMin: Int = 1
        var repsMax: Int = 1
        var setTypeRaw: String = SetType.working.rawValue

        var workoutExercise: SchemaV5.WorkoutExercise?

        init(sortIndex: Int, weightKg: Double?, repsMin: Int, repsMax: Int, setType: SetType = .working) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.sortIndex = sortIndex
            self.weightKg = weightKg
            self.repsMin = repsMin
            self.repsMax = repsMax
            self.setTypeRaw = setType.rawValue
        }
    }

    @Model
    final class Session {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var startedAt: Date = Date.now
        var endedAt: Date?
        var workoutNameSnapshot: String = ""

        var workout: SchemaV5.Workout?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.SessionExercise.session)
        var exercises: [SchemaV5.SessionExercise] = []

        init(startedAt: Date, workoutNameSnapshot: String) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.startedAt = startedAt
            self.workoutNameSnapshot = workoutNameSnapshot
        }
    }

    @Model
    final class SessionExercise {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var sortIndex: Int = 0
        var exerciseNameSnapshot: String = ""
        var muscleGroupSnapshotRaw: String = MuscleGroup.other.rawValue

        var session: SchemaV5.Session?
        var exercise: SchemaV5.Exercise?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.SetLog.sessionExercise)
        var setLogs: [SchemaV5.SetLog] = []

        init(sortIndex: Int, exerciseNameSnapshot: String, muscleGroupSnapshot: MuscleGroup) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.sortIndex = sortIndex
            self.exerciseNameSnapshot = exerciseNameSnapshot
            self.muscleGroupSnapshotRaw = muscleGroupSnapshot.rawValue
        }
    }

    @Model
    final class SetLog {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var sortIndex: Int = 0
        var weightKg: Double?
        var reps: Int?
        var isCompleted: Bool = false
        var completedAt: Date?
        var targetWeightKg: Double?
        var targetRepsMin: Int?
        var targetRepsMax: Int?
        var setTypeRaw: String = SetType.working.rawValue

        var sessionExercise: SchemaV5.SessionExercise?

        init(
            sortIndex: Int,
            weightKg: Double? = nil,
            reps: Int? = nil,
            targetWeightKg: Double? = nil,
            targetRepsMin: Int? = nil,
            targetRepsMax: Int? = nil,
            setType: SetType = .working
        ) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.sortIndex = sortIndex
            self.weightKg = weightKg
            self.reps = reps
            self.targetWeightKg = targetWeightKg
            self.targetRepsMin = targetRepsMin
            self.targetRepsMax = targetRepsMax
            self.setTypeRaw = setType.rawValue
        }
    }
}
