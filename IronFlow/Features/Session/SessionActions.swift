/// The session actions the screens offer: start from a planned workout, start a free workout, and
/// open the session in progress.
///
/// `RootView` provides them and is the only place that starts a session, opens the session screen
/// and reports problems, so every entry point (Início and Treinos) behaves the same way.
struct SessionActions {
    /// Starts a session from the workout and opens it.
    let start: @MainActor (Workout) -> Void
    /// Starts a session without a planned workout and opens it.
    let startFree: @MainActor () -> Void
    /// Opens the session in progress.
    let open: @MainActor () -> Void
}
