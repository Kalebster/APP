import Foundation

/// Where the app keeps the user's interface preferences (not user data, which lives in the store).
enum AppPreferences {
    /// The standard preferences; UI tests get an empty, separate set at every launch, or, with a test
    /// store on disk (`-ui-store <name>`), a set of that store's own, kept when the app opens again and
    /// emptied only with `-ui-store-new`. Created once, on the main actor where the interface reads it.
    @MainActor static let store: UserDefaults = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") {
            var suiteName = "com.ironflow.app.ui-testing"
            var isNew = true
            if let name = UITestStore.name(in: arguments) {
                suiteName += ".\(name)"
                isNew = arguments.contains(UITestStore.newFlag)
            }
            if isNew {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            return UserDefaults(suiteName: suiteName) ?? .standard
        }
        #endif
        return .standard
    }()
}
