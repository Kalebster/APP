import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// When saving fails, every unsaved change is discarded, so the objects and the store keep their
/// previous state, and the error reaches the caller. The failure is a real one: the store is opened
/// read-only, so SwiftData refuses to write to it.
@MainActor
struct SaveOrRollbackTests {
    @Test("A failed save brings the changed and removed data back to their previous state and reports the error")
    func failedSaveRollsBack() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")

        do {
            let services = ServiceTestHarness(container: try ModelContainerFactory.makePersistent(at: storeURL))
            let bench = try services.exercises.createCustomExercise(name: "Supino", muscleGroup: .chest)
            let curl = try services.exercises.createCustomExercise(name: "Rosca", muscleGroup: .biceps)
            _ = try services.makeWorkout(name: "Push", items: [(bench, [.reps(8, 10)]), (curl, [.reps(10, 12)])])
        }

        // The same store, opened read-only. Nothing is saved behind the test's back.
        let schema = ModelContainerFactory.schema
        let readOnly = try ModelContainer(
            for: schema,
            migrationPlan: IronFlowMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL, allowsSave: false, cloudKitDatabase: .none)]
        )
        readOnly.mainContext.autosaveEnabled = false
        let services = ServiceTestHarness(container: readOnly)
        let workout = try #require(try services.context.fetch(FetchDescriptor<Workout>()).first)
        let updatedAt = workout.updatedAt
        let before = try storeCounts(in: services.context)

        // A change: the workout keeps its name.
        #expect(throws: SaveError.self) { try services.workouts.rename(workout, to: "Pull") }
        #expect(workout.name == "Push")
        #expect(workout.updatedAt == updatedAt)

        // A removal with a renumbering: the exercise, its planned set and the order come back.
        let first = workout.orderedExercises[0]
        #expect(throws: SaveError.self) { try services.workouts.removeExercise(first) }
        #expect(workout.orderedExercises.map { $0.exercise?.name } == ["Supino", "Rosca"])
        #expect(workout.orderedExercises.map(\.sortIndex) == [0, 1])
        #expect(workout.updatedAt == updatedAt)

        #expect(services.context.hasChanges == false)
        #expect(try storeCounts(in: services.context) == before)
    }
}
