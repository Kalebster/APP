import Foundation

/// A model ordered inside its parent by `sortIndex`, with `createdAt` and `id` as tie-breakers.
protocol PositionOrdered {
    var sortIndex: Int { get }
    var createdAt: Date { get }
    var id: UUID { get }
}

extension WorkoutExercise: PositionOrdered {}
extension PlannedSet: PositionOrdered {}
extension SessionExercise: PositionOrdered {}
extension SetLog: PositionOrdered {}

extension Sequence where Element: PositionOrdered {
    /// Elements in position order: `sortIndex`, then `createdAt`, then `id`.
    func sortedByPosition() -> [Element] {
        sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id < rhs.id
        }
    }
}
