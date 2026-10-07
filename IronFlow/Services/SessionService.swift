import Foundation
import SwiftData

/// Business rules for performed workouts (sessions) and their sets.
///
/// At most one session is active (`endedAt == nil`). Only the active session can be
/// changed; finished sessions are history and read-only.
@MainActor
struct SessionService {
    let context: ModelContext
    let now: @MainActor () -> Date

    init(context: ModelContext, now: @escaping @MainActor () -> Date = { Date.now }) {
        self.context = context
        self.now = now
    }

    /// The session in progress, if any. Used to resume after the app was closed.
    func activeSession() throws -> Session? {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt == nil })
        descriptor.fetchLimit = 2
        let sessions = try context.fetch(descriptor)
        guard sessions.count <= 1 else { throw SessionError.multipleActiveSessions }
        return sessions.first
    }

    /// Sessions in progress, the most recently started first. Normally at most one; should the
    /// store ever hold more, the screens show the first and the next once it is finished or discarded.
    nonisolated static var activeSessionsDescriptor: FetchDescriptor<Session> {
        FetchDescriptor<Session>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// Starts a session from a workout, copying names, muscle groups, order and targets.
    /// Later changes to the workout do not affect the session.
    @discardableResult
    func startSession(from workout: Workout) throws -> Session {
        try ensureNoActiveSession()

        let items = workout.orderedExercises
        guard !items.isEmpty else { throw WorkoutError.workoutHasNoExercises }
        var plan: [(exercise: Exercise, sets: [PlannedSet])] = []
        for item in items {
            guard let exercise = item.exercise else { throw WorkoutError.exerciseMissing }
            let sets = item.orderedPlannedSets
            guard !sets.isEmpty else { throw WorkoutError.plannedSetsMissing }
            plan.append((exercise, sets))
        }

        let timestamp = now()
        let session = Session(startedAt: timestamp, workoutNameSnapshot: workout.name)
        session.createdAt = timestamp
        session.updatedAt = timestamp
        context.insert(session)
        session.workout = workout

        for (exerciseIndex, entry) in plan.enumerated() {
            let performed = SessionExercise(
                sortIndex: exerciseIndex,
                exerciseNameSnapshot: entry.exercise.name,
                muscleGroupSnapshot: entry.exercise.muscleGroup
            )
            performed.createdAt = timestamp
            performed.updatedAt = timestamp
            context.insert(performed)
            performed.session = session
            performed.exercise = entry.exercise

            for (setIndex, planned) in entry.sets.enumerated() {
                let log = SetLog(
                    sortIndex: setIndex,
                    weightKg: planned.weightKg,
                    reps: nil,
                    targetWeightKg: planned.weightKg,
                    targetRepsMin: planned.repsMin,
                    targetRepsMax: planned.repsMax
                )
                log.createdAt = timestamp
                log.updatedAt = timestamp
                context.insert(log)
                log.sessionExercise = performed
            }
        }

        try context.saveOrRollback()
        return session
    }

    /// Starts a session without a planned workout ("treino livre"); exercises are added during it.
    @discardableResult
    func startFreeSession() throws -> Session {
        try ensureNoActiveSession()

        let timestamp = now()
        let session = Session(startedAt: timestamp, workoutNameSnapshot: "")
        session.createdAt = timestamp
        session.updatedAt = timestamp
        context.insert(session)
        try context.saveOrRollback()
        return session
    }

    /// Appends exercises to the active session, in the given order, each with one empty set.
    ///
    /// Changes only the session: the planned workout is never touched. An exercise cannot be in
    /// the session twice and an archived exercise cannot be added. All or nothing.
    @discardableResult
    func addExercises(_ exercises: [Exercise], to session: Session) throws -> [SessionExercise] {
        guard session.isActive else { throw SessionError.sessionNotActive }
        var usedIDs = Set(session.exercises.compactMap { $0.exercise?.id })
        for exercise in exercises {
            guard !exercise.isArchived else { throw WorkoutError.exerciseArchived }
            guard usedIDs.insert(exercise.id).inserted else { throw WorkoutError.exerciseAlreadyInWorkout }
        }
        guard !exercises.isEmpty else { return [] }

        let timestamp = now()
        let firstIndex = session.exercises.count
        let added = exercises.enumerated().map { offset, exercise in
            let performed = SessionExercise(
                sortIndex: firstIndex + offset,
                exerciseNameSnapshot: exercise.name,
                muscleGroupSnapshot: exercise.muscleGroup
            )
            performed.createdAt = timestamp
            performed.updatedAt = timestamp
            context.insert(performed)
            performed.session = session
            performed.exercise = exercise
            makeSetLog(sortIndex: 0, copying: nil, at: timestamp).sessionExercise = performed
            return performed
        }
        session.updatedAt = timestamp
        try context.saveOrRollback()
        return added
    }

    /// Appends a set to a performed exercise of the active session, with the load and targets of
    /// its last set and no repetitions. Changes only the session, never the planned workout.
    @discardableResult
    func addSetCopyingLast(to performed: SessionExercise) throws -> SetLog {
        guard let session = performed.session, session.isActive else { throw SessionError.sessionNotActive }

        let timestamp = now()
        let log = makeSetLog(sortIndex: performed.setLogs.count, copying: performed.orderedSetLogs.last, at: timestamp)
        log.sessionExercise = performed
        performed.updatedAt = timestamp
        session.updatedAt = timestamp
        try context.saveOrRollback()
        return log
    }

    /// Edits the values of a set without changing whether it is completed.
    /// A completed set must keep a repetition count.
    func updateSetValues(_ log: SetLog, weightKg: Double?, reps: Int?) throws {
        let session = try activeSession(of: log)
        try Validation.weight(weightKg)
        if let reps {
            try Validation.performedReps(reps)
        } else if log.isCompleted {
            throw SessionError.repsRequired
        }

        let timestamp = now()
        log.weightKg = weightKg
        log.reps = reps
        log.updatedAt = timestamp
        session.updatedAt = timestamp
        try context.saveOrRollback()
    }

    /// Records what was performed and marks the set as completed.
    func completeSet(_ log: SetLog, weightKg: Double?, reps: Int?) throws {
        let session = try activeSession(of: log)
        guard let reps else { throw SessionError.repsRequired }
        try Validation.performedReps(reps)
        try Validation.weight(weightKg)

        let timestamp = now()
        log.weightKg = weightKg
        log.reps = reps
        if !log.isCompleted {
            log.isCompleted = true
            log.completedAt = timestamp
        }
        log.updatedAt = timestamp
        session.updatedAt = timestamp
        try context.saveOrRollback()
    }

    /// Marks the set as not completed. The entered values are kept.
    func uncompleteSet(_ log: SetLog) throws {
        let session = try activeSession(of: log)
        guard log.isCompleted else { return }

        let timestamp = now()
        log.isCompleted = false
        log.completedAt = nil
        log.updatedAt = timestamp
        session.updatedAt = timestamp
        try context.saveOrRollback()
    }

    /// Ends the session. Sets that were not completed stay recorded as not done.
    /// A session without any completed set cannot be finished (it must be discarded instead).
    func finishSession(_ session: Session) throws {
        guard session.isActive else { throw SessionError.sessionNotActive }
        let hasCompletedSet = session.exercises.contains { performed in
            performed.setLogs.contains(where: \.isCompleted)
        }
        guard hasCompletedSet else { throw SessionError.noCompletedSets }

        let timestamp = now()
        session.endedAt = max(timestamp, session.startedAt)
        session.updatedAt = timestamp
        try context.saveOrRollback()
    }

    /// Deletes the active session and only its own data.
    func discardSession(_ session: Session) throws {
        guard session.isActive else { throw SessionError.sessionNotActive }

        context.delete(session)
        try context.saveOrRollback()
    }

    // MARK: - Private

    /// Only one session can be in progress; any session still open blocks a new one.
    private func ensureNoActiveSession() throws {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt == nil })
        descriptor.fetchLimit = 1
        guard try context.fetchCount(descriptor) == 0 else { throw SessionError.activeSessionExists }
    }

    /// A new, not completed set: the load and targets of `previous` when given, otherwise empty.
    private func makeSetLog(sortIndex: Int, copying previous: SetLog?, at timestamp: Date) -> SetLog {
        let log = SetLog(
            sortIndex: sortIndex,
            weightKg: previous?.weightKg,
            reps: nil,
            targetWeightKg: previous?.targetWeightKg,
            targetRepsMin: previous?.targetRepsMin,
            targetRepsMax: previous?.targetRepsMax
        )
        log.createdAt = timestamp
        log.updatedAt = timestamp
        context.insert(log)
        return log
    }

    private func activeSession(of log: SetLog) throws -> Session {
        guard let session = log.sessionExercise?.session, session.isActive else {
            throw SessionError.sessionNotActive
        }
        return session
    }
}
