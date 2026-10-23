import CoreData
import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// The store-compatibility fingerprint of every released schema version, in migration plan order.
///
/// Each entry is Core Data's version hash of every entity, exactly as it is written into the
/// metadata of a store created by that version. A store is recognised as a given version only while
/// these hashes match, so they are frozen when the version is released and never edited: changing a
/// stored model needs a new schema version and a migration stage.
///
/// Recorded from the metadata of the stores written by the models of each version, in CI (Xcode 26.6,
/// iOS 26.5): version 1 is the seven models unchanged since version 2 was added; version 2 adds the
/// body data models and keeps the version 1 hashes; version 3 adds the days trained outside the app
/// and keeps the version 2 hashes; version 4 adds the weekly plan and keeps the version 3 hashes;
/// version 5 adds the set type to `PlannedSet` and `SetLog`, which get new hashes, and keeps the
/// version 4 hashes of every other entity.
enum FrozenSchemaFingerprints {
    static let v1: [String: String] = [
        "Exercise": "1BkqgcXluhyBYJH33K97S2SIFYStucTz7S5w5iun+Jo=",
        "PlannedSet": "VrWeWezPhFsb7B+I4pxQZhr0/1xQZ8s8gsxwY1a3Z7Y=",
        "Session": "HNYoMs0B88OrlUPyl8IWVpum9Q+nhSawFatu08CW0Qc=",
        "SessionExercise": "A3XjHUXXqzx8QIAke0/FK5XUb4R/R0xT4w/hqTE8dxc=",
        "SetLog": "9SaoMXIfW/VowJo92dLQEdzqymBmtwyRabs/slWwvrA=",
        "Workout": "dJaZ5Te6/QwBv2X26ydCT8/LdJDgg62L3rCKFfOAxPo=",
        "WorkoutExercise": "SP+1dSWCM1Ixum4aJcztrcAI0UG6U5UQc1C4LpAUztw=",
    ]

    static let v2: [String: String] = [
        "BodyWeightEntry": "kGO75AdAUmfpekEnf0AsZdNSW0wGvtLcYRFbi7oB0nc=",
        "Exercise": "1BkqgcXluhyBYJH33K97S2SIFYStucTz7S5w5iun+Jo=",
        "PlannedSet": "VrWeWezPhFsb7B+I4pxQZhr0/1xQZ8s8gsxwY1a3Z7Y=",
        "Session": "HNYoMs0B88OrlUPyl8IWVpum9Q+nhSawFatu08CW0Qc=",
        "SessionExercise": "A3XjHUXXqzx8QIAke0/FK5XUb4R/R0xT4w/hqTE8dxc=",
        "SetLog": "9SaoMXIfW/VowJo92dLQEdzqymBmtwyRabs/slWwvrA=",
        "UserProfile": "zjds3JCP7cVCga1DEGaf0+f7hmyaNGFc9oPqOpsDg9w=",
        "Workout": "dJaZ5Te6/QwBv2X26ydCT8/LdJDgg62L3rCKFfOAxPo=",
        "WorkoutExercise": "SP+1dSWCM1Ixum4aJcztrcAI0UG6U5UQc1C4LpAUztw=",
    ]

    static let v3: [String: String] = [
        "BodyWeightEntry": "kGO75AdAUmfpekEnf0AsZdNSW0wGvtLcYRFbi7oB0nc=",
        "Exercise": "1BkqgcXluhyBYJH33K97S2SIFYStucTz7S5w5iun+Jo=",
        "ExternalWorkoutDay": "K9sh48mJ6F+Y/BbOXLaz5n1vJ0en9wZmSRoY+vmsH4o=",
        "PlannedSet": "VrWeWezPhFsb7B+I4pxQZhr0/1xQZ8s8gsxwY1a3Z7Y=",
        "Session": "HNYoMs0B88OrlUPyl8IWVpum9Q+nhSawFatu08CW0Qc=",
        "SessionExercise": "A3XjHUXXqzx8QIAke0/FK5XUb4R/R0xT4w/hqTE8dxc=",
        "SetLog": "9SaoMXIfW/VowJo92dLQEdzqymBmtwyRabs/slWwvrA=",
        "UserProfile": "zjds3JCP7cVCga1DEGaf0+f7hmyaNGFc9oPqOpsDg9w=",
        "Workout": "dJaZ5Te6/QwBv2X26ydCT8/LdJDgg62L3rCKFfOAxPo=",
        "WorkoutExercise": "SP+1dSWCM1Ixum4aJcztrcAI0UG6U5UQc1C4LpAUztw=",
    ]

    static let v4: [String: String] = [
        "BodyWeightEntry": "kGO75AdAUmfpekEnf0AsZdNSW0wGvtLcYRFbi7oB0nc=",
        "Exercise": "1BkqgcXluhyBYJH33K97S2SIFYStucTz7S5w5iun+Jo=",
        "ExternalWorkoutDay": "K9sh48mJ6F+Y/BbOXLaz5n1vJ0en9wZmSRoY+vmsH4o=",
        "PlannedSet": "VrWeWezPhFsb7B+I4pxQZhr0/1xQZ8s8gsxwY1a3Z7Y=",
        "Session": "HNYoMs0B88OrlUPyl8IWVpum9Q+nhSawFatu08CW0Qc=",
        "SessionExercise": "A3XjHUXXqzx8QIAke0/FK5XUb4R/R0xT4w/hqTE8dxc=",
        "SetLog": "9SaoMXIfW/VowJo92dLQEdzqymBmtwyRabs/slWwvrA=",
        "UserProfile": "zjds3JCP7cVCga1DEGaf0+f7hmyaNGFc9oPqOpsDg9w=",
        "WeeklyPlanDay": "7w4IMQhG9NUouQpJpyY4GaJzs+iVRf9iOCMwk9z/0Rs=",
        "Workout": "dJaZ5Te6/QwBv2X26ydCT8/LdJDgg62L3rCKFfOAxPo=",
        "WorkoutExercise": "SP+1dSWCM1Ixum4aJcztrcAI0UG6U5UQc1C4LpAUztw=",
    ]

    static let v5: [String: String] = [
        "BodyWeightEntry": "kGO75AdAUmfpekEnf0AsZdNSW0wGvtLcYRFbi7oB0nc=",
        "Exercise": "1BkqgcXluhyBYJH33K97S2SIFYStucTz7S5w5iun+Jo=",
        "ExternalWorkoutDay": "K9sh48mJ6F+Y/BbOXLaz5n1vJ0en9wZmSRoY+vmsH4o=",
        "PlannedSet": "/ylbFYlVI2t38xF8Ae1EFCMXF4YtZ0kfuWQGMuzskag=",
        "Session": "HNYoMs0B88OrlUPyl8IWVpum9Q+nhSawFatu08CW0Qc=",
        "SessionExercise": "A3XjHUXXqzx8QIAke0/FK5XUb4R/R0xT4w/hqTE8dxc=",
        "SetLog": "xQoQ9isZV42wwZcmtpgbHxbF51LdBrAYwG7MGi95rGk=",
        "UserProfile": "zjds3JCP7cVCga1DEGaf0+f7hmyaNGFc9oPqOpsDg9w=",
        "WeeklyPlanDay": "7w4IMQhG9NUouQpJpyY4GaJzs+iVRf9iOCMwk9z/0Rs=",
        "Workout": "dJaZ5Te6/QwBv2X26ydCT8/LdJDgg62L3rCKFfOAxPo=",
        "WorkoutExercise": "SP+1dSWCM1Ixum4aJcztrcAI0UG6U5UQc1C4LpAUztw=",
    ]

    /// One fingerprint per version of `IronFlowMigrationPlan.schemas`, in the same order.
    static let byVersion: [[String: String]] = [v1, v2, v3, v4, v5]
}

/// The fingerprint written into the metadata of the store at `url`, by entity name.
func storeFingerprint(at url: URL) throws -> [String: String] {
    let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: url)
    let hashes = try #require(metadata[NSStoreModelVersionHashesKey] as? [String: Data], "No version hashes in the store metadata")
    return hashes.mapValues { $0.base64EncodedString() }
}

/// A fingerprint as a sorted Swift dictionary literal, so a failure shows the values to compare.
func fingerprintLiteral(_ fingerprint: [String: String]) -> String {
    let entries = fingerprint.keys.sorted().map { "\"\($0)\": \"\(fingerprint[$0] ?? "")\"" }
    return "[\(entries.joined(separator: ", "))]"
}

/// Creates a store of exactly the given schema version at `url`, independent of the current schema.
///
/// Versions 1 to 4 share the seven main models of `SchemaV1`, so the records of their stores are
/// written by `LegacyRecords` and read by `legacyHistorySnapshot`, with those classes. A migrated store
/// is read with the app's models (the version 5 classes) by `historySnapshot`.
@MainActor
func makeStore(of version: any VersionedSchema.Type, at url: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: version)
    return try ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
    )
}

/// The records of a store written by versions 1 to 4, with the seven main models of `SchemaV1`: the
/// same graph as `SampleGraph` (library exercises, the "Push" plan and a finished session), plus
/// records whose optional values and relationships are empty, as real stores can hold them: an
/// archived custom exercise, a finished session whose workout and exercise were deleted, and a
/// session still in progress.
@MainActor
enum LegacyRecords {
    static let oldSessionStart = Date(timeIntervalSinceReferenceDate: 790_000_000)

    /// What the tests look for after the migration.
    struct IDs {
        let workout: UUID
        let session: UUID
    }

    /// Planned sets and performed sets written by `insert(into:)`.
    static let plannedSetCount = 3
    static let setLogCount = 5

    static func insert(into context: ModelContext) -> IDs {
        let benchPress = SchemaV1.Exercise(name: "Supino Reto", muscleGroup: .chest, isCustom: false, libraryKey: "bench-press")
        let curl = SchemaV1.Exercise(name: "Rosca Direta", muscleGroup: .biceps, isCustom: true)
        context.insert(benchPress)
        context.insert(curl)

        let workout = SchemaV1.Workout(name: "Push")
        context.insert(workout)

        let benchPlan = SchemaV1.WorkoutExercise(sortIndex: 0)
        context.insert(benchPlan)
        benchPlan.workout = workout
        benchPlan.exercise = benchPress
        for planned in [
            SchemaV1.PlannedSet(sortIndex: 0, weightKg: 20, repsMin: 8, repsMax: 10),
            SchemaV1.PlannedSet(sortIndex: 1, weightKg: 22.25, repsMin: 6, repsMax: 8),
        ] {
            context.insert(planned)
            planned.workoutExercise = benchPlan
        }

        let curlPlan = SchemaV1.WorkoutExercise(sortIndex: 1)
        context.insert(curlPlan)
        curlPlan.workout = workout
        curlPlan.exercise = curl
        let curlPlanned = SchemaV1.PlannedSet(sortIndex: 0, weightKg: nil, repsMin: 10, repsMax: 12)
        context.insert(curlPlanned)
        curlPlanned.workoutExercise = curlPlan

        let session = SchemaV1.Session(startedAt: SampleGraph.sessionStart, workoutNameSnapshot: "Push")
        context.insert(session)
        session.workout = workout
        session.endedAt = SampleGraph.sessionEnd

        let benchPerformed = SchemaV1.SessionExercise(sortIndex: 0, exerciseNameSnapshot: "Supino Reto", muscleGroupSnapshot: .chest)
        context.insert(benchPerformed)
        benchPerformed.session = session
        benchPerformed.exercise = benchPress

        let completedSet = SchemaV1.SetLog(sortIndex: 0, weightKg: 20, reps: 10, targetWeightKg: 20, targetRepsMin: 8, targetRepsMax: 10)
        context.insert(completedSet)
        completedSet.sessionExercise = benchPerformed
        completedSet.isCompleted = true
        completedSet.completedAt = SampleGraph.completedAt

        let notCompletedSet = SchemaV1.SetLog(sortIndex: 1, targetWeightKg: 22.25, targetRepsMin: 6, targetRepsMax: 8)
        context.insert(notCompletedSet)
        notCompletedSet.sessionExercise = benchPerformed

        let curlPerformed = SchemaV1.SessionExercise(sortIndex: 1, exerciseNameSnapshot: "Rosca Direta", muscleGroupSnapshot: .biceps)
        context.insert(curlPerformed)
        curlPerformed.session = session
        curlPerformed.exercise = curl

        let curlSet = SchemaV1.SetLog(sortIndex: 0, reps: 12, targetRepsMin: 10, targetRepsMax: 12)
        context.insert(curlSet)
        curlSet.sessionExercise = curlPerformed
        curlSet.isCompleted = true
        curlSet.completedAt = SampleGraph.completedAt

        let archived = SchemaV1.Exercise(name: "Remada Antiga", muscleGroup: .back, isCustom: true)
        archived.isArchived = true
        context.insert(archived)

        let orphan = SchemaV1.Session(startedAt: oldSessionStart, workoutNameSnapshot: "Treino Antigo")
        context.insert(orphan)
        orphan.endedAt = oldSessionStart.addingTimeInterval(1_800)
        let orphanExercise = SchemaV1.SessionExercise(sortIndex: 0, exerciseNameSnapshot: "Remada Curvada", muscleGroupSnapshot: .back)
        context.insert(orphanExercise)
        orphanExercise.session = orphan
        let orphanSet = SchemaV1.SetLog(sortIndex: 0, reps: 15)
        context.insert(orphanSet)
        orphanSet.sessionExercise = orphanExercise
        orphanSet.isCompleted = true
        orphanSet.completedAt = oldSessionStart.addingTimeInterval(600)

        let active = SchemaV1.Session(startedAt: SampleGraph.sessionEnd.addingTimeInterval(86_400), workoutNameSnapshot: workout.name)
        context.insert(active)
        active.workout = workout
        let activeExercise = SchemaV1.SessionExercise(sortIndex: 0, exerciseNameSnapshot: benchPress.name, muscleGroupSnapshot: .chest)
        context.insert(activeExercise)
        activeExercise.session = active
        activeExercise.exercise = benchPress
        let activeSet = SchemaV1.SetLog(sortIndex: 0, weightKg: 20, targetWeightKg: 20, targetRepsMin: 8, targetRepsMax: 10)
        context.insert(activeSet)
        activeSet.sessionExercise = activeExercise

        return IDs(workout: workout.id, session: session.id)
    }
}

/// Every stored value and to-one relationship of the seven main models, except the set type added in
/// version 5, one sorted line per record, so a migrated store can be compared field by field with the
/// store it came from (optional values included). The set types are read by `storedSetTypeKeys`.
@MainActor
func historySnapshot(_ context: ModelContext) throws -> [String] {
    var lines: [String] = []
    for item in try context.fetch(FetchDescriptor<Exercise>()) {
        lines.append("Exercise \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) name=\(item.name) group=\(item.muscleGroupRaw) custom=\(item.isCustom) archived=\(item.isArchived) key=\(text(item.libraryKey))")
    }
    for item in try context.fetch(FetchDescriptor<Workout>()) {
        lines.append("Workout \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) name=\(item.name)")
    }
    for item in try context.fetch(FetchDescriptor<WorkoutExercise>()) {
        lines.append("WorkoutExercise \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) index=\(item.sortIndex) workout=\(text(item.workout?.id)) exercise=\(text(item.exercise?.id))")
    }
    for item in try context.fetch(FetchDescriptor<PlannedSet>()) {
        lines.append("PlannedSet \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) index=\(item.sortIndex) kg=\(text(item.weightKg)) reps=\(item.repsMin)-\(item.repsMax) item=\(text(item.workoutExercise?.id))")
    }
    for item in try context.fetch(FetchDescriptor<Session>()) {
        lines.append("Session \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) start=\(text(item.startedAt)) end=\(text(item.endedAt)) name=\(item.workoutNameSnapshot) workout=\(text(item.workout?.id))")
    }
    for item in try context.fetch(FetchDescriptor<SessionExercise>()) {
        lines.append("SessionExercise \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) index=\(item.sortIndex) name=\(item.exerciseNameSnapshot) group=\(item.muscleGroupSnapshotRaw) session=\(text(item.session?.id)) exercise=\(text(item.exercise?.id))")
    }
    for item in try context.fetch(FetchDescriptor<SetLog>()) {
        lines.append("SetLog \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) index=\(item.sortIndex) kg=\(text(item.weightKg)) reps=\(text(item.reps)) done=\(item.isCompleted) at=\(text(item.completedAt)) target=\(text(item.targetWeightKg))/\(text(item.targetRepsMin))-\(text(item.targetRepsMax)) item=\(text(item.sessionExercise?.id))")
    }
    return lines.sorted()
}

/// The same lines as `historySnapshot`, read with the version 1 classes from a store of versions 1 to 4.
@MainActor
func legacyHistorySnapshot(_ context: ModelContext) throws -> [String] {
    var lines: [String] = []
    for item in try context.fetch(FetchDescriptor<SchemaV1.Exercise>()) {
        lines.append("Exercise \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) name=\(item.name) group=\(item.muscleGroupRaw) custom=\(item.isCustom) archived=\(item.isArchived) key=\(text(item.libraryKey))")
    }
    for item in try context.fetch(FetchDescriptor<SchemaV1.Workout>()) {
        lines.append("Workout \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) name=\(item.name)")
    }
    for item in try context.fetch(FetchDescriptor<SchemaV1.WorkoutExercise>()) {
        lines.append("WorkoutExercise \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) index=\(item.sortIndex) workout=\(text(item.workout?.id)) exercise=\(text(item.exercise?.id))")
    }
    for item in try context.fetch(FetchDescriptor<SchemaV1.PlannedSet>()) {
        lines.append("PlannedSet \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) index=\(item.sortIndex) kg=\(text(item.weightKg)) reps=\(item.repsMin)-\(item.repsMax) item=\(text(item.workoutExercise?.id))")
    }
    for item in try context.fetch(FetchDescriptor<SchemaV1.Session>()) {
        lines.append("Session \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) start=\(text(item.startedAt)) end=\(text(item.endedAt)) name=\(item.workoutNameSnapshot) workout=\(text(item.workout?.id))")
    }
    for item in try context.fetch(FetchDescriptor<SchemaV1.SessionExercise>()) {
        lines.append("SessionExercise \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) index=\(item.sortIndex) name=\(item.exerciseNameSnapshot) group=\(item.muscleGroupSnapshotRaw) session=\(text(item.session?.id)) exercise=\(text(item.exercise?.id))")
    }
    for item in try context.fetch(FetchDescriptor<SchemaV1.SetLog>()) {
        lines.append("SetLog \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) index=\(item.sortIndex) kg=\(text(item.weightKg)) reps=\(text(item.reps)) done=\(item.isCompleted) at=\(text(item.completedAt)) target=\(text(item.targetWeightKg))/\(text(item.targetRepsMin))-\(text(item.targetRepsMax)) item=\(text(item.sessionExercise?.id))")
    }
    return lines.sorted()
}

/// The stored type key of every planned set and every performed set, as written in the store (not
/// read through `setType`, which reads an unknown key as working).
@MainActor
func storedSetTypeKeys(_ context: ModelContext) throws -> (planned: [String], performed: [String]) {
    (
        try context.fetch(FetchDescriptor<PlannedSet>()).map(\.setTypeRaw),
        try context.fetch(FetchDescriptor<SetLog>()).map(\.setTypeRaw)
    )
}

/// Every stored value of the body data models added in version 2, one sorted line per record.
@MainActor
func bodyDataSnapshot(_ context: ModelContext) throws -> [String] {
    var lines: [String] = []
    for item in try context.fetch(FetchDescriptor<BodyWeightEntry>()) {
        lines.append("BodyWeightEntry \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) measured=\(text(item.measuredAt)) kg=\(item.weightKg)")
    }
    for item in try context.fetch(FetchDescriptor<UserProfile>()) {
        lines.append("UserProfile \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) height=\(text(item.heightCm)) goal=\(text(item.dailyCalorieGoalKcal))")
    }
    return lines.sorted()
}

/// Every stored value of the days trained outside the app, added in version 3, one sorted line per record.
@MainActor
func externalWorkoutDaySnapshot(_ context: ModelContext) throws -> [String] {
    try context.fetch(FetchDescriptor<ExternalWorkoutDay>()).map { item in
        "ExternalWorkoutDay \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) day=\(item.day)"
    }
    .sorted()
}

/// Every stored value of the weekly plan, added in version 4, one sorted line per record.
@MainActor
func weeklyPlanSnapshot(_ context: ModelContext) throws -> [String] {
    try context.fetch(FetchDescriptor<WeeklyPlanDay>()).map { item in
        "WeeklyPlanDay \(item.id) \(text(item.createdAt)) \(text(item.updatedAt)) weekday=\(item.weekday) workout=\(item.workoutID)"
    }
    .sorted()
}

private func text(_ date: Date?) -> String {
    date.map { "\($0.timeIntervalSinceReferenceDate)" } ?? "nil"
}

private func text<Value>(_ value: Value?) -> String {
    value.map { "\($0)" } ?? "nil"
}
