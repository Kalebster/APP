import Foundation

/// What lets a normal launch skip the full check of the exercise library (`ExerciseLibrarySeeder.seedIfNeeded`):
/// the version of the library last checked in full, and whether an exercise of the user's own was created,
/// renamed, archived, restored or deleted since (its name may hide or free a library exercise). Kept with the
/// app's preferences, never in the store: it holds nothing of the person's, and a store without the library
/// (new or replaced) is checked in full all the same, by its count of library exercises.
@MainActor
struct LibraryCheckMarker {
    let store: UserDefaults

    /// The app's preferences (`AppPreferences.store`).
    static var app: LibraryCheckMarker {
        LibraryCheckMarker(store: AppPreferences.store)
    }

    private static let versionKey = "exerciseLibrary.checkedVersion"
    private static let pendingKey = "exerciseLibrary.checkPending"

    /// The library version last checked in full; `nil` before the first check.
    var checkedVersion: String? {
        store.string(forKey: Self.versionKey)
    }

    /// Whether an exercise of the user's own changed since the last full check.
    var isCheckPending: Bool {
        store.bool(forKey: Self.pendingKey)
    }

    /// After a full check of `version` that was saved (or had nothing to save).
    func recordCheck(of version: String) {
        store.set(version, forKey: Self.versionKey)
        store.set(false, forKey: Self.pendingKey)
    }

    /// The next launch checks the library in full.
    func requestCheck() {
        store.set(true, forKey: Self.pendingKey)
    }
}
