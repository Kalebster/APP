import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// The launch of the app with the library already installed (`ExerciseLibrarySeeder.seedIfNeeded`): the full
/// check runs only when the library or the seeder's rules changed, when an exercise of the user's own was
/// created, renamed, archived, restored or deleted, or when the store does not have the library; otherwise
/// the launch only counts the library exercises.
@MainActor
struct LibraryCheckTests {
    /// A marker on preferences of its own, emptied at the end of the test.
    @MainActor
    private final class Preferences {
        let suiteName = "IronFlowTests.libraryCheck.\(UUID().uuidString)"
        lazy var marker = LibraryCheckMarker(store: UserDefaults(suiteName: suiteName) ?? .standard)

        deinit {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
    }

    private func services(_ harness: ServiceTestHarness, _ preferences: Preferences) -> (ExerciseLibrarySeeder, ExerciseService) {
        (
            ExerciseLibrarySeeder(context: harness.context, now: harness.clock.now),
            ExerciseService(context: harness.context, now: harness.clock.now, libraryMarker: preferences.marker)
        )
    }

    @Test("The first launch checks the library in full and records it; the second, with nothing changed, changes and saves nothing")
    func secondLaunchWithoutChanges() throws {
        let harness = try ServiceTestHarness()
        let preferences = Preferences()
        let (seeder, _) = services(harness, preferences)

        let first = try #require(try seeder.seedIfNeeded(marker: preferences.marker))
        #expect(first.insertedKeys.count == 1_525)
        #expect(preferences.marker.checkedVersion == ExerciseLibrarySeeder.libraryVersion)
        #expect(!preferences.marker.isCheckPending)

        let before = try storeCounts(in: harness.context)
        #expect(try seeder.seedIfNeeded(marker: preferences.marker) == nil)
        #expect(try storeCounts(in: harness.context) == before)
        #expect(harness.context.hasChanges == false)
    }

    @Test("Renaming an exercise of the user's own makes the next launch check in full: the combination its old name hid comes back, and the launch after that skips again")
    func launchAfterRenaming() throws {
        let harness = try ServiceTestHarness()
        let preferences = Preferences()
        let (seeder, service) = services(harness, preferences)
        // An exercise of the user's own named like a combination, before the combination is installed.
        let own = try service.createCustomExercise(name: "supino reto (kettlebell)", muscleGroup: .chest)
        try seeder.seedIfNeeded(marker: preferences.marker)
        let combination = try #require(try harness.context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Supino Reto (Kettlebell)" })).first)
        #expect(combination.isArchived)
        #expect(try seeder.seedIfNeeded(marker: preferences.marker) == nil)

        try service.update(own, with: ExerciseDraft(name: "Meu Supino", group: .chest, equipment: .equipment(.kettlebell), primary: [.chest], secondary: []))
        #expect(preferences.marker.isCheckPending)
        #expect(!combination.isArchived)

        let check = try #require(try seeder.seedIfNeeded(marker: preferences.marker))
        #expect(check == ExerciseLibrarySeedResult())
        #expect(!preferences.marker.isCheckPending)
        #expect(try seeder.seedIfNeeded(marker: preferences.marker) == nil)
    }

    @Test("Creating, archiving, restoring and deleting an exercise of the user's own each make the next launch check in full; editing without renaming does not")
    func changesThatAskForACheck() throws {
        let harness = try ServiceTestHarness()
        let preferences = Preferences()
        let (seeder, service) = services(harness, preferences)
        try seeder.seedIfNeeded(marker: preferences.marker)

        func expectCheck(_ what: String, _ change: () throws -> Void) throws {
            try change()
            #expect(preferences.marker.isCheckPending, "\(what)")
            #expect(try seeder.seedIfNeeded(marker: preferences.marker) != nil, "\(what)")
            #expect(try seeder.seedIfNeeded(marker: preferences.marker) == nil, "\(what)")
        }
        let own = try service.createCustomExercise(name: "Remada Própria", muscleGroup: .upperBack)
        #expect(preferences.marker.isCheckPending)
        #expect(try seeder.seedIfNeeded(marker: preferences.marker) != nil)
        try expectCheck("archived") { try service.archive(own) }
        try expectCheck("restored") { try service.unarchive(own) }

        try service.update(own, with: ExerciseDraft(name: "Remada Própria", group: .upperBack, equipment: .other, primary: [.upperBack], secondary: []))
        #expect(!preferences.marker.isCheckPending, "Edited without renaming")

        try expectCheck("deleted") { try service.remove(own) }
    }

    @Test("Another library version, or a store without the library (new or replaced), is checked in full even with the marker recorded")
    func versionOrStoreChanged() throws {
        let preferences = Preferences()
        let first = try ServiceTestHarness()
        try services(first, preferences).0.seedIfNeeded(marker: preferences.marker)

        // A new store, with the marker of the old one: the library is installed.
        let second = try ServiceTestHarness()
        let installed = try #require(try services(second, preferences).0.seedIfNeeded(marker: preferences.marker))
        #expect(installed.insertedKeys.count == 1_525)

        // Another version recorded (an older library or other rules): checked in full, then recorded.
        preferences.marker.recordCheck(of: "0-older")
        #expect(try services(second, preferences).0.seedIfNeeded(marker: preferences.marker) != nil)
        #expect(preferences.marker.checkedVersion == ExerciseLibrarySeeder.libraryVersion)
    }

    @Test("A check that fails to save is not recorded: the next launch runs it again")
    func failedCheckIsNotRecorded() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let url = directory.appending(path: "IronFlow.store")
        let preferences = Preferences()
        do {
            let harness = ServiceTestHarness(container: try ModelContainerFactory.makePersistent(at: url))
            try services(harness, preferences).0.seedIfNeeded(marker: preferences.marker)
            // A combination hidden although its name is free: the next full check shows it, and has that to save.
            let combination = try #require(try harness.context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Supino Reto (Kettlebell)" })).first)
            combination.isArchived = true
            try harness.context.save()
        }
        preferences.marker.requestCheck()

        // The same store, read-only: saving the check is refused.
        let schema = ModelContainerFactory.schema
        let readOnly = try ModelContainer(
            for: schema,
            migrationPlan: IronFlowMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none)]
        )
        readOnly.mainContext.autosaveEnabled = false
        let seeder = ExerciseLibrarySeeder(context: readOnly.mainContext)
        #expect(throws: SaveError.self) { try seeder.seedIfNeeded(marker: preferences.marker) }
        #expect(preferences.marker.isCheckPending)
    }
}
