import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// When saving fails, the error reaches the caller and the store keeps its previous state. The failure
/// is a real one: the store is opened read-only, so SwiftData refuses to write to it.
@MainActor
struct SaveOrRollbackTests {
    @Test("A failed save reports the error and leaves the stored data in its previous state")
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
        services.clock.advance(by: 60)

        // A change and a removal with a renumbering: both are refused with the error.
        #expect(throws: SaveError.self) { try services.workouts.rename(workout, to: "Pull") }
        let first = workout.orderedExercises[0]
        #expect(throws: SaveError.self) { try services.workouts.removeExercise(first) }

        // Nothing is left pending, and the removed exercise and its planned set are back.
        #expect(services.context.hasChanges == false)
        #expect(try storeCounts(in: services.context) == before)
        #expect(workout.orderedExercises.map { $0.exercise?.name } == ["Supino", "Rosca"])

        // Found by this test: SwiftData's rollback does not put back the values changed in the
        // objects that stay in memory. The renamed workout still shows the new name and the
        // renumbered exercise its new position, although neither was written (the store, read
        // below, has neither).
        withKnownIssue("ModelContext.rollback() keeps the changed values in the objects in memory") {
            #expect(workout.name == "Push")
            #expect(workout.orderedExercises.map(\.sortIndex) == [0, 1])
        }

        // The stored data, read with a new context, is exactly as before.
        let stored = try #require(try ModelContext(readOnly).fetch(FetchDescriptor<Workout>()).first)
        #expect(stored.name == "Push")
        #expect(stored.updatedAt == updatedAt)
        #expect(stored.orderedExercises.map { $0.exercise?.name } == ["Supino", "Rosca"])
        #expect(stored.orderedExercises.map(\.sortIndex) == [0, 1])
        #expect(stored.orderedExercises.map { $0.plannedSets.count } == [1, 1])
    }
}
