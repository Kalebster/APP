import Foundation
import SwiftData

/// Version 1 of the Iron Flow data schema. Frozen: released stores were written by it.
///
/// Its seven models are declared below exactly as they were released: the same stored properties,
/// relationships, delete rules and unique ids. Every type is named explicitly (`SchemaV1.PlannedSet`),
/// never through the app's aliases, which point to the latest version, so a later version never
/// changes this one. The app does not use these classes; they only describe the stores to migrate.
/// `SchemaFreezeTests` checks that they still write the released store.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            SchemaV1.Exercise.self,
            SchemaV1.Workout.self,
            SchemaV1.WorkoutExercise.self,
            SchemaV1.PlannedSet.self,
            SchemaV1.Session.self,
            SchemaV1.SessionExercise.self,
            SchemaV1.SetLog.self,
        ]
    }
}

extension SchemaV1 {
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

        @Relationship(deleteRule: .nullify, inverse: \SchemaV1.WorkoutExercise.exercise)
        var workoutExercises: [SchemaV1.WorkoutExercise] = []

        @Relationship(deleteRule: .nullify, inverse: \SchemaV1.SessionExercise.exercise)
        var sessionExercises: [SchemaV1.SessionExercise] = []

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

        @Relationship(deleteRule: .cascade, inverse: \SchemaV1.WorkoutExercise.workout)
        var exercises: [SchemaV1.WorkoutExercise] = []

        @Relationship(deleteRule: .nullify, inverse: \SchemaV1.Session.workout)
        var sessions: [SchemaV1.Session] = []

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

        var workout: SchemaV1.Workout?
        var exercise: SchemaV1.Exercise?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV1.PlannedSet.workoutExercise)
        var plannedSets: [SchemaV1.PlannedSet] = []

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

        var workoutExercise: SchemaV1.WorkoutExercise?

        init(sortIndex: Int, weightKg: Double?, repsMin: Int, repsMax: Int) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.sortIndex = sortIndex
            self.weightKg = weightKg
            self.repsMin = repsMin
            self.repsMax = repsMax
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

        var workout: SchemaV1.Workout?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV1.SessionExercise.session)
        var exercises: [SchemaV1.SessionExercise] = []

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

        var session: SchemaV1.Session?
        var exercise: SchemaV1.Exercise?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV1.SetLog.sessionExercise)
        var setLogs: [SchemaV1.SetLog] = []

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

        var sessionExercise: SchemaV1.SessionExercise?

        init(
            sortIndex: Int,
            weightKg: Double? = nil,
            reps: Int? = nil,
            targetWeightKg: Double? = nil,
            targetRepsMin: Int? = nil,
            targetRepsMax: Int? = nil
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
        }
    }
}
