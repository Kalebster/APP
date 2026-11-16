import Foundation
import OSLog
import SwiftData

private let persistenceLogger = Logger(subsystem: "com.ironflow.app", category: "persistence")

/// A model ordered inside its parent by an explicit `sortIndex`.
protocol SortIndexed: AnyObject {
    var sortIndex: Int { get set }
    var updatedAt: Date { get set }
}

extension WorkoutExercise: SortIndexed {}
extension PlannedSet: SortIndexed {}
extension SessionExercise: SortIndexed {}
extension SetLog: SortIndexed {}

enum SortIndexing {
    /// Sets `sortIndex` to 0...n-1 following the order of `items`.
    /// Items whose index changes get `updatedAt = timestamp`.
    static func renumber(_ items: [some SortIndexed], at timestamp: Date) {
        for (index, item) in items.enumerated() where item.sortIndex != index {
            item.sortIndex = index
            item.updatedAt = timestamp
        }
    }

    /// `items` reordered with the same semantics as SwiftUI's `move(fromOffsets:toOffset:)`.
    static func moved<Item>(_ items: [Item], fromOffsets source: IndexSet, toOffset destination: Int) throws -> [Item] {
        guard
            !source.isEmpty,
            source.allSatisfy({ items.indices.contains($0) }),
            (0...items.count).contains(destination)
        else {
            throw WorkoutError.invalidPosition
        }
        let moving = source.map { items[$0] }
        var result = items.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        result.insert(contentsOf: moving, at: destination - source.count(in: 0..<destination))
        return result
    }
}

extension ModelContext {
    /// Saves all pending changes. If saving fails, discards every unsaved change
    /// so the store keeps its previous state, and throws `SaveError`.
    ///
    /// The failure is logged, so it can be diagnosed: the error's type, domain and code are public; its
    /// description is private, as it may hold values the person typed.
    func saveOrRollback() throws {
        do {
            try save()
        } catch {
            rollback()
            let nsError = error as NSError
            let errorType = String(reflecting: type(of: error))
            persistenceLogger.error("Save failed and was rolled back: \(errorType, privacy: .public) \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public): \(String(describing: error), privacy: .private)")
            throw SaveError.saveFailed(String(describing: error))
        }
    }
}
