import Foundation
import SwiftData

/// When each exercise was last done: the start of the latest finished session with it, by the exercise's id
/// and, for a library exercise, by its key. Read once when a screen opens (the Exercícios tab, the picker,
/// an exercise screen), never while the person types. The session in progress never counts.
struct ExerciseLastDone: Equatable {
    var byID: [UUID: Date] = [:]
    var byKey: [String: Date] = [:]

    init() {}

    /// From the finished sessions, read whole: what `read(in:)` finds, the long way (its tests compare both).
    init(sessions: [Session]) {
        for session in sessions where session.endedAt != nil {
            for performed in session.exercises {
                guard let exercise = performed.exercise else { continue }
                if byID[exercise.id].map({ $0 < session.startedAt }) ?? true {
                    byID[exercise.id] = session.startedAt
                }
                if let key = exercise.libraryKey, !exercise.isCustom, byKey[key].map({ $0 < session.startedAt }) ?? true {
                    byKey[key] = session.startedAt
                }
            }
        }
    }

    /// Reads the store: for each exercise done at least once, only its latest finished session, which the
    /// store finds (sorted, one result), never the whole history. Reading every session with its exercises
    /// took 1,8 s with 3 years of 4 workouts a week (run 46100373787), every time the tab appeared.
    @MainActor
    static func read(in context: ModelContext) throws -> ExerciseLastDone {
        var lastDone = ExerciseLastDone()
        let done = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.sessionExercises.isEmpty }))
        for exercise in done {
            let exerciseID = exercise.id
            var latest = FetchDescriptor<Session>(
                predicate: #Predicate { session in
                    session.endedAt != nil && session.exercises.contains { $0.exercise?.id == exerciseID }
                },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            latest.fetchLimit = 1
            // Only in the session in progress: never done.
            guard let startedAt = try context.fetch(latest).first?.startedAt else { continue }
            lastDone.byID[exerciseID] = startedAt
            if let key = exercise.libraryKey, !exercise.isCustom, lastDone.byKey[key].map({ $0 < startedAt }) ?? true {
                lastDone.byKey[key] = startedAt
            }
        }
        return lastDone
    }

    /// The combination of `base` its screen and the choice sheet open on: the one done last, or the first of
    /// the library's (none done); a hidden one only when every other is hidden too.
    func openingCombination(of base: ExerciseBase, hiddenKeys: Set<String> = []) -> DefaultExercise? {
        let combinations = ExerciseBaseIndex.combinations[base.name] ?? []
        let shown = combinations.filter { !hiddenKeys.contains($0.key) }
        let candidates = shown.isEmpty ? combinations : shown
        let done = candidates.compactMap { entry in byKey[entry.key].map { (entry, $0) } }
        if let last = done.max(by: { $0.1 < $1.1 }) {
            return last.0
        }
        return candidates.first
    }
}

/// The library exercises of the store, by key, read in one fetch when a screen opens: the records a base's
/// rows choose between, and the hidden ones (their name is taken by an exercise of the user's own).
struct LibraryRecords {
    private(set) var byKey: [String: Exercise] = [:]
    /// The keys of the hidden library exercises, computed once.
    private(set) var hiddenKeys: Set<String> = []

    init() {}

    init(_ exercises: [Exercise]) {
        for exercise in exercises where !exercise.isCustom {
            if let key = exercise.libraryKey, byKey[key] == nil {
                byKey[key] = exercise
                if exercise.isArchived {
                    hiddenKeys.insert(key)
                }
            }
        }
    }

    @MainActor
    static func read(in context: ModelContext) throws -> LibraryRecords {
        LibraryRecords(try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom })))
    }

    /// The record of one library exercise, read on its own.
    @MainActor
    static func record(forKey key: String, in context: ModelContext) throws -> Exercise? {
        var descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.libraryKey == key && !$0.isCustom })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// The keys of the hidden library exercises, read on their own (they are few).
    @MainActor
    static func hiddenKeys(in context: ModelContext) throws -> Set<String> {
        let hidden = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.isArchived && !$0.isCustom }))
        return Set(hidden.compactMap(\.libraryKey))
    }
}
