import Observation

/// What the root of the app shows over every tab for the screens below it: the short notices
/// ("Treino salvo", "Nome salvo"), one at a time, and an error from a screen that has already closed
/// (swiped back), whose own alert would never be seen. Kept by `RootView` and read from the
/// environment; a screen shown outside it (a preview) has none.
@MainActor
@Observable
final class RootFeedback {
    /// The notice at the top of the screen (`toast(_:)`).
    var toast: ToastMessage?
    /// The error in the root's alert.
    var errorMessage: String?

    /// Shows a short notice, in place of the one on screen.
    func show(_ text: String) {
        toast = ToastMessage(text)
    }
}
