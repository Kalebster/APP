import Foundation
import SwiftData
import Testing
@testable import IronFlow

@MainActor
struct ModelContainerFactoryTests {
    @Test("Store uses schema V5: the seven main models with the set type, the body data, the days trained outside the app and the weekly plan")
    func schemaV5() throws {
        let container = try ModelContainerFactory.makeInMemory()

        let entityNames = Set(container.schema.entities.map(\.name))
        #expect(entityNames == [
            "Exercise", "Workout", "WorkoutExercise", "PlannedSet",
            "Session", "SessionExercise", "SetLog",
            "BodyWeightEntry", "UserProfile",
            "ExternalWorkoutDay",
            "WeeklyPlanDay",
        ])
        let setEntities = container.schema.entities.filter { ["PlannedSet", "SetLog"].contains($0.name) }
        #expect(setEntities.count == 2)
        for entity in setEntities {
            #expect(entity.attributes.contains { $0.name == "setTypeRaw" }, "\(entity.name) has no set type")
        }

        // Versions 1 to 4 add tables only: each one reuses every model of the one before.
        #expect(Set(SchemaV1.models.map { ObjectIdentifier($0) }).isSubset(of: Set(SchemaV2.models.map { ObjectIdentifier($0) })))
        #expect(Set(SchemaV2.models.map { ObjectIdentifier($0) }).isSubset(of: Set(SchemaV3.models.map { ObjectIdentifier($0) })))
        #expect(Set(SchemaV3.models.map { ObjectIdentifier($0) }).isSubset(of: Set(SchemaV4.models.map { ObjectIdentifier($0) })))
        // Version 5 redeclares the seven main models and reuses only the four added by versions 2 to 4.
        let v4 = Set(SchemaV4.models.map { ObjectIdentifier($0) })
        let v5 = Set(SchemaV5.models.map { ObjectIdentifier($0) })
        let reusedModels: [any PersistentModel.Type] = [
            SchemaV2.BodyWeightEntry.self, SchemaV2.UserProfile.self, SchemaV3.ExternalWorkoutDay.self, SchemaV4.WeeklyPlanDay.self,
        ]
        let reused = Set(reusedModels.map { ObjectIdentifier($0) })
        #expect(v4.intersection(v5) == reused)
        #expect(SchemaV5.models.count == 11)
        // The app's models are the version 5 ones.
        #expect(ObjectIdentifier(PlannedSet.self) == ObjectIdentifier(SchemaV5.PlannedSet.self))
        #expect(ObjectIdentifier(SetLog.self) == ObjectIdentifier(SchemaV5.SetLog.self))
        #expect(ObjectIdentifier(Workout.self) == ObjectIdentifier(SchemaV5.Workout.self))

        #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(SchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(SchemaV3.versionIdentifier == Schema.Version(3, 0, 0))
        #expect(SchemaV4.versionIdentifier == Schema.Version(4, 0, 0))
        #expect(SchemaV5.versionIdentifier == Schema.Version(5, 0, 0))
        #expect(IronFlowMigrationPlan.schemas.map { ObjectIdentifier($0) } == [
            ObjectIdentifier(SchemaV1.self), ObjectIdentifier(SchemaV2.self), ObjectIdentifier(SchemaV3.self),
            ObjectIdentifier(SchemaV4.self), ObjectIdentifier(SchemaV5.self),
        ])
        #expect(IronFlowMigrationPlan.stages.count == 4)
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
