import Foundation
import SwiftData

/// The only place that creates SwiftData containers.
///
/// Opening a store never deletes, moves, replaces or recreates it. If the store
/// cannot be opened, the error is thrown to the caller and the file is left untouched.
enum ModelContainerFactory {
    /// Location of the app's persistent store.
    static var defaultStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "IronFlow.store")
    }

    /// The app's persistent store on disk.
    static func makePersistent() throws -> ModelContainer {
        try makePersistent(at: defaultStoreURL)
    }

    /// A persistent store at `url`.
    static func makePersistent(at url: URL) throws -> ModelContainer {
        // Creates the parent folder only when it is missing; existing files are not touched.
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try makeContainer(configuration)
    }

    /// A new, isolated in-memory store. Each call returns an independent store.
    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            UUID().uuidString,
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try makeContainer(configuration)
    }

    private static var schema: Schema {
        Schema(versionedSchema: SchemaV1.self)
    }

    private static func makeContainer(_ configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: IronFlowMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
