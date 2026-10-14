import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// Stores written by every released schema version open with the current app and keep every value
/// and relationship. The stores are written by the models of their own version, whose fingerprints
/// are checked against the frozen ones first, so they are the stores those versions really wrote.
@MainActor
struct MigrationTests {
    @Test("A version 1 store keeps every value and relationship when the current app opens it")
    func v1StoreMigrates() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")
        var history: [String] = []
        var sessionID = UUID()

        do {
            let container = try makeStore(of: SchemaV1.self, at: storeURL)
            let context = container.mainContext
            let graph = SampleGraph.insert(into: context)
            HistoricalRecords.insert(into: context, workout: graph.workout, exercise: graph.benchPress)
            try context.save()
            history = try historySnapshot(context)
            sessionID = graph.session.id
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v1, "Not a version 1 store")

        do {
            let migrated = try ModelContainerFactory.makePersistent(at: storeURL)
            let context = migrated.mainContext

            #expect(try historySnapshot(context) == history)
            #expect(try bodyDataSnapshot(context).isEmpty)
            try expectHistoricalMeaning(in: context, sessionID: sessionID)

            // The tables added by version 2 work in the migrated store.
            let profile = ProfileService(context: context)
            try profile.recordWeight(80.5)
            try profile.setHeight(180)
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v2, "Store not migrated to version 2")

        // Closed and opened again: nothing was lost and the new data stays.
        let reopened = try ModelContainerFactory.makePersistent(at: storeURL)
        #expect(try historySnapshot(reopened.mainContext) == history)
        #expect(try ProfileService(context: reopened.mainContext).latestWeight()?.weightKg == 80.5)
        #expect(try ProfileService(context: reopened.mainContext).profile()?.heightCm == 180)
    }

    @Test("A version 2 store, with body data, keeps every value when the current app opens it")
    func v2StoreOpens() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")
        var history: [String] = []
        var bodyData: [String] = []
        var sessionID = UUID()

        do {
            let container = try makeStore(of: SchemaV2.self, at: storeURL)
            let context = container.mainContext
            let graph = SampleGraph.insert(into: context)
            HistoricalRecords.insert(into: context, workout: graph.workout, exercise: graph.benchPress)
            context.insert(BodyWeightEntry(weightKg: 81.25, measuredAt: SampleGraph.sessionStart))
            context.insert(BodyWeightEntry(weightKg: 80.5, measuredAt: SampleGraph.sessionEnd))
            let profile = UserProfile()
            profile.heightCm = 180
            context.insert(profile)
            try context.save()
            history = try historySnapshot(context)
            bodyData = try bodyDataSnapshot(context)
            sessionID = graph.session.id
        }
        #expect(try storeFingerprint(at: storeURL) == FrozenSchemaFingerprints.v2, "Not a version 2 store")

        let opened = try ModelContainerFactory.makePersistent(at: storeURL)
        let context = opened.mainContext
        #expect(try historySnapshot(context) == history)
        #expect(try bodyDataSnapshot(context) == bodyData)
        try expectHistoricalMeaning(in: context, sessionID: sessionID)
        #expect(try ProfileService(context: context).latestWeight()?.weightKg == 80.5)
        #expect(try ProfileService(context: context).profile()?.heightCm == 180)
        #expect(try ProfileService(context: context).profile()?.dailyCalorieGoalKcal == nil)
    }

    /// The same values read through the app's relationships and services, as the screens read them.
    private func expectHistoricalMeaning(in context: ModelContext, sessionID: UUID) throws {
        let workout = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        #expect(workout.orderedExercises.map { $0.exercise?.name } == ["Supino Reto", "Rosca Direta"])
        #expect(workout.orderedExercises[0].orderedPlannedSets.map(\.weightKg) == [20, 22.25])
        #expect(workout.orderedExercises[1].orderedPlannedSets.map(\.weightKg) == [nil])

        // A finished session of the plan: snapshots, completed and not completed sets.
        let session = try #require(try fetchSession(id: sessionID, in: context))
        #expect(session.workout?.id == workout.id)
        #expect(session.endedAt == SampleGraph.sessionEnd)
        #expect(session.orderedExercises.map(\.exerciseNameSnapshot) == ["Supino Reto", "Rosca Direta"])
        #expect(session.orderedExercises.map(\.muscleGroupSnapshot) == [.chest, .biceps])
        let logs = session.orderedExercises[0].orderedSetLogs
        #expect(logs.map(\.isCompleted) == [true, false])
        #expect(logs.map(\.reps) == [10, nil])
        #expect(logs.map(\.completedAt) == [SampleGraph.completedAt, nil])
        #expect(logs.map(\.targetWeightKg) == [20, 22.25])

        // A finished session whose workout and exercise were deleted stays readable.
        let orphan = try #require(try context.fetch(FetchDescriptor<Session>()).first { $0.startedAt == HistoricalRecords.oldSessionStart })
        #expect(orphan.workout == nil)
        #expect(orphan.workoutNameSnapshot == "Treino Antigo")
        #expect(orphan.orderedExercises.map { $0.exercise == nil } == [true])
        #expect(orphan.orderedExercises.map(\.muscleGroupSnapshot) == [.back])
        #expect(orphan.orderedExercises[0].orderedSetLogs.map(\.reps) == [15])

        // The session in progress is still the one to continue; archived exercises stay archived.
        let active = try #require(try SessionService(context: context).activeSession())
        #expect(active.workout?.id == workout.id)
        #expect(active.orderedExercises[0].orderedSetLogs.map(\.isCompleted) == [false])
        let archived = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isArchived }))
        #expect(archived.map(\.name) == ["Remada Antiga"])
    }
}
