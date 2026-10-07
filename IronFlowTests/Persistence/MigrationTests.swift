import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// A store written with an older schema version must open with the current one, keeping every record.
@MainActor
struct MigrationTests {
    @Test("A version 1 store on disk opens as version 2 with all its data and relationships")
    func v1StoreMigratesToV2() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")
        var sessionID = UUID()

        // Written exactly as version 1 of the app wrote it.
        do {
            let schemaV1 = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(
                for: schemaV1,
                configurations: [ModelConfiguration(schema: schemaV1, url: storeURL, cloudKitDatabase: .none)]
            )
            sessionID = SampleGraph.insert(into: container.mainContext).session.id
            try container.mainContext.save()
        }

        // Closed at the end of this block, so the check after it reads the file from disk.
        do {
            let migrated = try ModelContainerFactory.makePersistent(at: storeURL)
            let context = migrated.mainContext

            #expect(try count(Exercise.self, in: context) == 2)
            #expect(try count(Workout.self, in: context) == 1)
            #expect(try count(WorkoutExercise.self, in: context) == 2)
            #expect(try count(PlannedSet.self, in: context) == 3)
            #expect(try count(Session.self, in: context) == 1)
            #expect(try count(SessionExercise.self, in: context) == 2)
            #expect(try count(SetLog.self, in: context) == 3)
            #expect(try count(BodyWeightEntry.self, in: context) == 0)
            #expect(try count(UserProfile.self, in: context) == 0)

            let workout = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
            #expect(workout.orderedExercises.map { $0.exercise?.name } == ["Supino Reto", "Rosca Direta"])
            #expect(workout.orderedExercises[0].orderedPlannedSets.map(\.weightKg) == [20, 22.25])
            let session = try #require(try fetchSession(id: sessionID, in: context))
            #expect(session.workout?.id == workout.id)
            #expect(session.workoutNameSnapshot == "Push")
            #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Supino Reto", "Rosca Direta"])
            let logs = session.orderedExercises[0].orderedSetLogs
            #expect(logs.map(\.isCompleted) == [true, false])
            #expect(logs[0].reps == 10)
            #expect(logs[1].targetWeightKg == 22.25)

            // The new tables work in the migrated store, and the data stays after reopening it.
            let profile = ProfileService(context: context)
            try profile.recordWeight(80.5)
            try profile.setHeight(180)
        }

        let reopened = try ModelContainerFactory.makePersistent(at: storeURL)
        #expect(try ProfileService(context: reopened.mainContext).latestWeight()?.weightKg == 80.5)
        #expect(try ProfileService(context: reopened.mainContext).profile()?.heightCm == 180)
        #expect(try count(SetLog.self, in: reopened.mainContext) == 3)
    }
}
