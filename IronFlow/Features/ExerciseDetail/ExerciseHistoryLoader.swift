import Foundation
import SwiftData

/// Reads the history of one exercise from the store: only the performed exercises of that exercise
/// (a predicate in the fetch), with their sets and sessions fetched together, and only finished sessions;
/// the session in progress never counts. Read once when the exercise screen opens.
@MainActor
struct ExerciseHistoryLoader {
    let context: ModelContext

    /// The finished sessions with the exercise, the oldest first, as `ExerciseHistory` reads them: the sets
    /// done of the exercise in each, numbered in order. Should the exercise be twice in a session, its
    /// sets are one session's.
    func history(of exercise: Exercise) throws -> ExerciseHistory {
        let exerciseID = exercise.id
        var descriptor = FetchDescriptor<SessionExercise>(predicate: #Predicate { $0.exercise?.id == exerciseID })
        descriptor.relationshipKeyPathsForPrefetching = [\.setLogs, \.session]
        let performed = try context.fetch(descriptor)

        var sessions: [UUID: Session] = [:]
        var setsBySession: [UUID: [SetLog]] = [:]
        for item in performed.sortedByPosition() {
            // Finished sessions only: the one in progress never counts.
            guard let session = item.session, session.endedAt != nil else { continue }
            sessions[session.id] = session
            setsBySession[session.id, default: []] += item.orderedSetLogs.filter(\.isCompleted)
        }
        let entries = sessions.values.map { session in
            ExerciseHistory.Entry(
                id: session.id,
                workoutName: SessionFormatting.name(session.workoutNameSnapshot),
                startedAt: session.startedAt,
                sets: (setsBySession[session.id] ?? []).enumerated().map { index, log in
                    ExerciseHistory.SetRecord(number: index + 1, type: log.setType, weightKg: log.weightKg, reps: log.reps)
                }
            )
        }
        return ExerciseHistory(entries: entries, isAssisted: DefaultExerciseMuscles.isAssisted(exercise))
    }

    /// The finished session with `id`, for its detail.
    func session(id: UUID) throws -> Session? {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
