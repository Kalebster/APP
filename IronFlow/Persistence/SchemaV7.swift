import Foundation
import SwiftData

/// Version 7 of the Iron Flow data schema.
///
/// Adds the rest between sets (`restSeconds`) to `WorkoutExercise` and `SessionExercise`. The seven
/// main models are redeclared here (below, as they were released; the app's own are those of
/// `SchemaV8`), not only those two: their relationships point to each other's classes, so a version 5
/// class reused here would still point to the version 5 ones. The models without relationships (body
/// data, profile, days trained outside the app, weekly plan) are unchanged and reused as they are. The
/// migration from V6 only adds the rest, 1 min 30 s for every exercise already stored. Frozen: every
/// model is named explicitly, never through the app's aliases.
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

// The seven main models exactly as version 7 released them (they were the app's models until version 8):
// the same stored properties, relationships, delete rules and unique ids, every type named explicitly.
// The app does not use these classes; they only describe the stores to migrate. `SchemaFreezeTests`
// checks that they still write the released store.
extension SchemaV7 {
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

        @Relationship(deleteRule: .nullify, inverse: \SchemaV7.WorkoutExercise.exercise)
        var workoutExercises: [SchemaV7.WorkoutExercise] = []

        @Relationship(deleteRule: .nullify, inverse: \SchemaV7.SessionExercise.exercise)
        var sessionExercises: [SchemaV7.SessionExercise] = []

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

        @Relationship(deleteRule: .cascade, inverse: \SchemaV7.WorkoutExercise.workout)
        var exercises: [SchemaV7.WorkoutExercise] = []

        @Relationship(deleteRule: .nullify, inverse: \SchemaV7.Session.workout)
        var sessions: [SchemaV7.Session] = []

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
        var restSeconds: Int = 90

        var workout: SchemaV7.Workout?
        var exercise: SchemaV7.Exercise?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV7.PlannedSet.workoutExercise)
        var plannedSets: [SchemaV7.PlannedSet] = []

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

        var workoutExercise: SchemaV7.WorkoutExercise?

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

        var workout: SchemaV7.Workout?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV7.SessionExercise.session)
        var exercises: [SchemaV7.SessionExercise] = []

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
        var restSeconds: Int = 90

        var session: SchemaV7.Session?
        var exercise: SchemaV7.Exercise?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV7.SetLog.sessionExercise)
        var setLogs: [SchemaV7.SetLog] = []

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

        var sessionExercise: SchemaV7.SessionExercise?

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
