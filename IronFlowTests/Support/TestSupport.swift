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

/// A clock that tests control, so service timestamps are exact.
@MainActor
final class TestClock {
    private(set) var current: Date

    init(start: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)) {
        current = start
    }

    func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }

    var now: @MainActor () -> Date {
        { self.current }
    }
}

/// Number of stored records of every model, to prove that a failed operation changed nothing.
@MainActor
func storeCounts(in context: ModelContext) throws -> [String: Int] {
    [
        "Exercise": try count(Exercise.self, in: context),
        "Workout": try count(Workout.self, in: context),
        "WorkoutExercise": try count(WorkoutExercise.self, in: context),
        "PlannedSet": try count(PlannedSet.self, in: context),
        "Session": try count(Session.self, in: context),
        "SessionExercise": try count(SessionExercise.self, in: context),
        "SetLog": try count(SetLog.self, in: context),
    ]
}

/// Services sharing one isolated in-memory store and one test clock.
@MainActor
struct ServiceTestHarness {
    let container: ModelContainer
    let clock: TestClock
    let exercises: ExerciseService
    let workouts: WorkoutService
    let sessions: SessionService

    var context: ModelContext { container.mainContext }

    init() throws {
        try self.init(container: ModelContainerFactory.makeInMemory())
    }

    init(container: ModelContainer) {
        let clock = TestClock()
        self.container = container
        self.clock = clock
        exercises = ExerciseService(context: container.mainContext, now: clock.now)
        workouts = WorkoutService(context: container.mainContext, now: clock.now)
        sessions = SessionService(context: container.mainContext, now: clock.now)
    }

    /// Inserts a built-in (system) exercise directly; there is no service for them yet.
    func insertSystemExercise(name: String, muscleGroup: MuscleGroup, libraryKey: String) throws -> Exercise {
        let exercise = Exercise(name: name, muscleGroup: muscleGroup, isCustom: false, libraryKey: libraryKey)
        context.insert(exercise)
        try context.save()
        return exercise
    }

    /// A valid workout built through the services: one item per entry, with the given planned sets.
    func makeWorkout(name: String, items: [(Exercise, [PlannedSetValues])]) throws -> Workout {
        let workout = try workouts.createWorkout(name: name)
        for (exercise, sets) in items {
            let item = try workouts.addExercise(exercise, to: workout, firstSet: sets[0])
            for values in sets.dropFirst() {
                try workouts.addPlannedSet(to: item, values: values)
            }
        }
        return workout
    }
}

extension PlannedSetValues {
    static func reps(_ min: Int, _ max: Int, kg: Double? = nil) -> PlannedSetValues {
        PlannedSetValues(weightKg: kg, repsMin: min, repsMax: max)
    }
}
