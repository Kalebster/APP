import Foundation
import SwiftData
@testable import IronFlow

/// Creates a unique temporary folder for one test.
func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "IronFlowTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Deletes a folder created by `makeTemporaryDirectory()`.
func removeTemporaryDirectory(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

/// Writes with one on-disk container, then reads the same store with a new container.
///
/// Proves that data really reached the disk instead of only living in memory.
@MainActor
func roundTripThroughDisk(
    write: (ModelContext) throws -> Void,
    read: (ModelContext) throws -> Void
) throws {
    let directory = try makeTemporaryDirectory()
    defer { removeTemporaryDirectory(directory) }
    let storeURL = directory.appending(path: "IronFlow.store")

    do {
        let container = try ModelContainerFactory.makePersistent(at: storeURL)
        try write(container.mainContext)
        try container.mainContext.save()
    }

    let reopened = try ModelContainerFactory.makePersistent(at: storeURL)
    try read(reopened.mainContext)
}

/// Fetches the single model with `id`, or `nil`.
@MainActor
func fetchSession(id: UUID, in context: ModelContext) throws -> Session? {
    try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })).first
}

/// Number of stored models of `type`.
@MainActor
func count<Model: PersistentModel>(_ type: Model.Type, in context: ModelContext) throws -> Int {
    try context.fetchCount(FetchDescriptor<Model>())
}

/// A small but complete graph: library exercises, a planned workout and a finished session.
///
/// Plan: "Push" → [0] Supino Reto (2 planned sets), [1] Rosca Direta (1 planned set).
/// History: session of "Push" → [0] Supino Reto (one completed and one not completed set),
/// [1] Rosca Direta (one completed set without load).
@MainActor
struct SampleGraph {
    let benchPress: Exercise
    let curl: Exercise
    let workout: Workout
    let benchPlan: WorkoutExercise
    let curlPlan: WorkoutExercise
    let session: Session
    let benchPerformed: SessionExercise
    let curlPerformed: SessionExercise
    let completedSet: SetLog
    let notCompletedSet: SetLog
    let curlSet: SetLog

    static let sessionStart = Date(timeIntervalSinceReferenceDate: 800_000_000)
    static let sessionEnd = sessionStart.addingTimeInterval(3_600)
    static let completedAt = sessionStart.addingTimeInterval(600)

    static func insert(into context: ModelContext) -> SampleGraph {
        let benchPress = Exercise(name: "Supino Reto", muscleGroup: .chest, isCustom: false, libraryKey: "bench-press")
        let curl = Exercise(name: "Rosca Direta", muscleGroup: .biceps, isCustom: true)
        context.insert(benchPress)
        context.insert(curl)

        let workout = Workout(name: "Push")
        context.insert(workout)

        let benchPlan = WorkoutExercise(sortIndex: 0)
        context.insert(benchPlan)
        benchPlan.workout = workout
        benchPlan.exercise = benchPress
        for planned in [
            PlannedSet(sortIndex: 0, weightKg: 20, repsMin: 8, repsMax: 10),
            PlannedSet(sortIndex: 1, weightKg: 22.25, repsMin: 6, repsMax: 8),
        ] {
            context.insert(planned)
            planned.workoutExercise = benchPlan
        }

        let curlPlan = WorkoutExercise(sortIndex: 1)
        context.insert(curlPlan)
        curlPlan.workout = workout
        curlPlan.exercise = curl
        let curlPlanned = PlannedSet(sortIndex: 0, weightKg: nil, repsMin: 10, repsMax: 12)
        context.insert(curlPlanned)
        curlPlanned.workoutExercise = curlPlan

        let session = Session(startedAt: sessionStart, workoutNameSnapshot: "Push")
        context.insert(session)
        session.workout = workout
        session.endedAt = sessionEnd

        let benchPerformed = SessionExercise(sortIndex: 0, exerciseNameSnapshot: "Supino Reto", muscleGroupSnapshot: .chest)
        context.insert(benchPerformed)
        benchPerformed.session = session
        benchPerformed.exercise = benchPress

        let completedSet = SetLog(sortIndex: 0, weightKg: 20, reps: 10, targetWeightKg: 20, targetRepsMin: 8, targetRepsMax: 10)
        context.insert(completedSet)
        completedSet.sessionExercise = benchPerformed
        completedSet.isCompleted = true
        completedSet.completedAt = completedAt

        let notCompletedSet = SetLog(sortIndex: 1, targetWeightKg: 22.25, targetRepsMin: 6, targetRepsMax: 8)
        context.insert(notCompletedSet)
        notCompletedSet.sessionExercise = benchPerformed

        let curlPerformed = SessionExercise(sortIndex: 1, exerciseNameSnapshot: "Rosca Direta", muscleGroupSnapshot: .biceps)
        context.insert(curlPerformed)
        curlPerformed.session = session
        curlPerformed.exercise = curl

        let curlSet = SetLog(sortIndex: 0, reps: 12, targetRepsMin: 10, targetRepsMax: 12)
        context.insert(curlSet)
        curlSet.sessionExercise = curlPerformed
        curlSet.isCompleted = true
        curlSet.completedAt = completedAt

        return SampleGraph(
            benchPress: benchPress,
            curl: curl,
            workout: workout,
            benchPlan: benchPlan,
            curlPlan: curlPlan,
            session: session,
            benchPerformed: benchPerformed,
            curlPerformed: curlPerformed,
            completedSet: completedSet,
            notCompletedSet: notCompletedSet,
            curlSet: curlSet
        )
    }
}
