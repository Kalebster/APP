import OSLog
import SwiftData
import SwiftUI

private let persistenceLogger = Logger(subsystem: "com.ironflow.app", category: "persistence")

@main
struct IronFlowApp: App {
    /// Result of opening the data store. On failure the store is left untouched
    /// and the app shows `PersistenceErrorView` instead of the main tabs.
    @State private var store: Result<ModelContainer, any Error>

    init() {
        _store = State(initialValue: Self.loadStore())
    }

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                RootView()
                    .modelContainer(container)
            case .failure(let error):
                PersistenceErrorView(error: error) {
                    // Only tries to open the same store again.
                    store = Self.loadStore()
                }
            }
        }
    }

    /// Opens the store and, when it opened, installs or updates the built-in exercise library
    /// before the tabs are shown.
    @MainActor
    private static func loadStore() -> Result<ModelContainer, any Error> {
        let result = openStore()
        if case .success(let container) = result {
            seedExerciseLibrary(in: container)
        }
        return result
    }

    /// A seeding failure does not block the app: the store is left as it was (the seeder
    /// rolls back) and seeding runs again on the next launch.
    @MainActor
    private static func seedExerciseLibrary(in container: ModelContainer) {
        do {
            let result = try ExerciseLibrarySeeder(context: container.mainContext).seed()
            if !result.skippedKeys.isEmpty {
                persistenceLogger.error("Library entries skipped because their id is in use: \(result.skippedKeys.joined(separator: ", "), privacy: .public)")
            }
        } catch {
            persistenceLogger.error("Could not seed the exercise library: \(String(describing: error), privacy: .private)")
        }
    }

    nonisolated private static func openStore() -> Result<ModelContainer, any Error> {
        let result = Result { try makeContainer() }
        if case .failure(let error) = result {
            persistenceLogger.error("Could not open the data store: \(String(describing: error), privacy: .private)")
        }
        return result
    }

    nonisolated private static func makeContainer() throws -> ModelContainer {
        #if DEBUG
        // Test hooks; compiled into Debug builds only.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-simulate-persistence-failure") {
            throw SimulatedPersistenceFailure()
        }
        if arguments.contains("-ui-testing") {
            return try ModelContainerFactory.makeInMemory()
        }
        #endif
        return try ModelContainerFactory.makePersistent()
    }
}

#if DEBUG
/// Error used by the `-simulate-persistence-failure` test hook.
private struct SimulatedPersistenceFailure: LocalizedError {
    var errorDescription: String? {
        "Simulated persistence failure (-simulate-persistence-failure)."
    }
}
#endif
