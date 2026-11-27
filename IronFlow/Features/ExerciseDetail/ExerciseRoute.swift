import Foundation

/// A row of the Exercícios tab opens the screen of the exercise of the user's own with this id.
struct ExerciseRoute: Hashable {
    let exerciseID: UUID
}

/// A base's row of the Exercícios tab opens its screen on the library exercise with this key: the
/// combination done last, or the first of the base.
struct ExerciseBaseRoute: Hashable {
    let key: String
}
