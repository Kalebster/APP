import Foundation

/// Where the app keeps the user's interface preferences (not user data, which lives in the store).
enum AppPreferences {
    /// The standard preferences; UI tests get an empty, separate set at every launch.
    static let store: UserDefaults = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            let suiteName = "com.ironflow.app.ui-testing"
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
            return UserDefaults(suiteName: suiteName) ?? .standard
        }
        #endif
        return .standard
    }()
}
