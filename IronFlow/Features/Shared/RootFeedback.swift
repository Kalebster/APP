import Observation

/// What the root of the app shows over every tab for the screens below it: an error from a screen
/// that has already closed (swiped back), whose own alert would never be seen. Kept by `RootView`
/// and read from the environment; a screen shown outside it (a preview) has none.
@MainActor
@Observable
final class RootFeedback {
    /// The error in the root's alert.
    var errorMessage: String?
}
