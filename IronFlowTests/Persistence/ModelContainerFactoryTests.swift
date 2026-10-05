import Foundation
import SwiftData
import Testing
@testable import IronFlow

@MainActor
struct ModelContainerFactoryTests {
    @Test("Store uses schema V1 with exactly the seven models")
    func schemaV1() throws {
        let container = try ModelContainerFactory.makeInMemory()

        let entityNames = Set(container.schema.entities.map(\.name))
        #expect(entityNames == [
            "Exercise", "Workout", "WorkoutExercise", "PlannedSet",
            "Session", "SessionExercise", "SetLog",
        ])
        #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(IronFlowMigrationPlan.schemas.map { ObjectIdentifier($0) } == [ObjectIdentifier(SchemaV1.self)])
        #expect(IronFlowMigrationPlan.stages.isEmpty)
    }

    @Test("In-memory stores are isolated from each other")
    func inMemoryStoresAreIsolated() throws {
        let first = try ModelContainerFactory.makeInMemory()
        first.mainContext.insert(Exercise(name: "Supino Reto", muscleGroup: .chest, isCustom: false))
        try first.mainContext.save()

        let second = try ModelContainerFactory.makeInMemory()

        #expect(try count(Exercise.self, in: first.mainContext) == 1)
        #expect(try count(Exercise.self, in: second.mainContext) == 0)
    }

    @Test("Persistent store is created at the requested location")
    func persistentStoreCreatesFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")

        let container = try ModelContainerFactory.makePersistent(at: storeURL)
        container.mainContext.insert(Workout(name: "Push"))
        try container.mainContext.save()

        #expect(FileManager.default.fileExists(atPath: storeURL.path(percentEncoded: false)))
    }

    @Test("App store lives in Application Support")
    func defaultStoreLocation() {
        #expect(ModelContainerFactory.defaultStoreURL == URL.applicationSupportDirectory.appending(path: "IronFlow.store"))
    }

    @Test("A store that cannot be opened throws and is left untouched")
    func unreadableStoreIsNotModified() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")
        let corruptContents = Data(String(repeating: "not a database ", count: 300).utf8)
        try corruptContents.write(to: storeURL)

        #expect(throws: (any Error).self) {
            _ = try ModelContainerFactory.makePersistent(at: storeURL)
        }
        #expect(try Data(contentsOf: storeURL) == corruptContents)
    }
}
