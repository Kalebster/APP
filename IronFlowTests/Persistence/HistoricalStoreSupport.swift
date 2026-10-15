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
/// and keeps the version 2 hashes; version 4 adds the weekly plan and keeps the version 3 hashes.
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

    /// One fingerprint per version of `IronFlowMigrationPlan.schemas`, in the same order.
    static let byVersion: [[String: String]] = [v1, v2, v3, v4]
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
/// The records written into it (`SampleGraph`, `HistoricalRecords`) and the snapshots use the app's
/// model aliases, which are the version 1 to 4 classes today. When a later version redeclares a
/// model, these writers must use that version's own classes (`SchemaV1.SetLog`, ...) and the
/// snapshot of the migrated store must read the new ones.
@MainActor
func makeStore(of version: any VersionedSchema.Type, at url: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: version)
    return try ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
    )
}

/// Records whose optional values and relationships are empty, as real stores can hold them, added
/// next to `SampleGraph`: an archived custom exercise, a finished session whose workout and exercise
/// were deleted, and a session still in progress.
@MainActor
enum HistoricalRecords {
    static let oldSessionStart = Date(timeIntervalSinceReferenceDate: 790_000_000)

    static func insert(into context: ModelContext, workout: Workout, exercise: Exercise) {
        let archived = Exercise(name: "Remada Antiga", muscleGroup: .back, isCustom: true)
        archived.isArchived = true
        context.insert(archived)

        let orphan = Session(startedAt: oldSessionStart, workoutNameSnapshot: "Treino Antigo")
        context.insert(orphan)
        orphan.endedAt = oldSessionStart.addingTimeInterval(1_800)
        let orphanExercise = SessionExercise(sortIndex: 0, exerciseNameSnapshot: "Remada Curvada", muscleGroupSnapshot: .back)
        context.insert(orphanExercise)
        orphanExercise.session = orphan
        let orphanSet = SetLog(sortIndex: 0, reps: 15)
        context.insert(orphanSet)
        orphanSet.sessionExercise = orphanExercise
        orphanSet.isCompleted = true
        orphanSet.completedAt = oldSessionStart.addingTimeInterval(600)

        let active = Session(startedAt: SampleGraph.sessionEnd.addingTimeInterval(86_400), workoutNameSnapshot: workout.name)
        context.insert(active)
        active.workout = workout
        let activeExercise = SessionExercise(sortIndex: 0, exerciseNameSnapshot: exercise.name, muscleGroupSnapshot: exercise.muscleGroup)
        context.insert(activeExercise)
        activeExercise.session = active
        activeExercise.exercise = exercise
        let activeSet = SetLog(sortIndex: 0, weightKg: 20, targetWeightKg: 20, targetRepsMin: 8, targetRepsMax: 10)
        context.insert(activeSet)
        activeSet.sessionExercise = activeExercise
    }
}

/// Every stored value and to-one relationship of the version 1 models, one sorted line per record,
/// so two stores can be compared field by field (optional values included).
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
