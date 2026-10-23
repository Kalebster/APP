import Foundation
import SwiftData

/// When a session being finished ends.
enum SessionEnd: Equatable, Sendable {
    /// The moment it is finished.
    case now
    /// The moment its last set was completed, for a session left open after the workout.
    case lastCompletedSet
}

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

    /// The single session in progress, if any.
    ///
    /// Throws `SessionError.multipleActiveSessions` when the store holds more than one session in
    /// progress, a state the app never creates (starting a session requires none in progress); it is
    /// reported as an inconsistency instead of silently picking one. Screens list the sessions in
    /// progress with `activeSessionsDescriptor`.
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

    /// Every finished session, the most recently started first.
    nonisolated static var finishedSessionsDescriptor: FetchDescriptor<Session> {
        FetchDescriptor<Session>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// How many finished sessions "Treinos recentes" shows.
    nonisolated static var recentSessionsLimit: Int { 3 }

    /// How long after its last completed set a session counts as left open after the workout:
    /// finishing it then offers the time of that set as its end.
    nonisolated static var forgottenSessionThreshold: TimeInterval { 3_600 }

    /// The latest finished sessions (`endedAt != nil`), the most recently started first, at most
    /// `recentSessionsLimit`. The limit is part of the query, so no more than that is ever read.
    nonisolated static var recentSessionsDescriptor: FetchDescriptor<Session> {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = recentSessionsLimit
        return descriptor
    }

    /// Starts a session from a workout, copying names, muscle groups, order, targets and set types.
    /// Later changes to the workout do not affect the session.
    ///
    /// The sets start empty: the planned load is kept as the set's target and offered in its empty
    /// field, with the values of the last time (see `LastPerformance`), and checking the set records it.
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
                    weightKg: nil,
                    reps: nil,
                    targetWeightKg: planned.weightKg,
                    targetRepsMin: planned.repsMin,
                    targetRepsMax: planned.repsMax,
                    setType: planned.setType
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

    /// Appends exercises to the active session, in the given order, each with one empty working set.
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

    /// Appends a working set to a performed exercise of the active session, with the load and targets
    /// of its last set and no repetitions. Changes only the session, never the planned workout.
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

    /// Removes a set of the active session; the sets after it move up. A performed exercise may be left
    /// without sets. Changes only the session, never the planned workout or the history.
    func removeSet(_ log: SetLog) throws {
        let session = try activeSession(of: log)

        let timestamp = now()
        if let performed = log.sessionExercise {
            SortIndexing.renumber(performed.orderedSetLogs.filter { $0.id != log.id }, at: timestamp)
            performed.updatedAt = timestamp
        }
        session.updatedAt = timestamp
        context.delete(log)
        try context.saveOrRollback()
    }

    /// Removes a performed exercise and its sets from the active session; the exercises after it move
    /// up. Changes only the session, never the planned workout or the history.
    func removeExercise(_ performed: SessionExercise) throws {
        guard let session = performed.session, session.isActive else { throw SessionError.sessionNotActive }

        let timestamp = now()
        SortIndexing.renumber(session.orderedExercises.filter { $0.id != performed.id }, at: timestamp)
        session.updatedAt = timestamp
        context.delete(performed)
        try context.saveOrRollback()
    }

    /// "Última vez" for the exercises of `session`: the sets done the last time each one was performed,
    /// by exercise id (see `LastPerformance.previousSets`). One query of the finished sessions, the most
    /// recently started first; older ones are read only while an exercise is still missing.
    func lastPerformances(for session: Session) throws -> [UUID: [PreviousSet]] {
        let exerciseIDs = Set(session.exercises.compactMap { $0.exercise?.id })
        guard !exerciseIDs.isEmpty else { return [:] }
        let finished = try context.fetch(Self.finishedSessionsDescriptor)
        return LastPerformance.previousSets(for: exerciseIDs, in: finished, excluding: session.id)
    }

    /// Changes the type of a set of the active session, done or not. Changes only the session, never
    /// the planned workout.
    func setType(_ setType: SetType, of log: SetLog) throws {
        let session = try activeSession(of: log)
        guard log.setType != setType else { return }

        let timestamp = now()
        log.setType = setType
        log.updatedAt = timestamp
        session.updatedAt = timestamp
        try context.saveOrRollback()
    }

    /// Edits the values of a set without changing whether it is completed.
    /// A completed set must keep a repetition count.
    func updateSetValues(_ log: SetLog, weightKg: Double?, reps: Int?) throws {
        let session = try activeSession(of: log)
        try Validation.performedWeight(weightKg)
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
        try Validation.performedWeight(weightKg)

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

    /// The end offered when the session is finished: the time its last set was completed, when that
    /// was more than `forgottenSessionThreshold` ago (the session was probably left open after the
    /// workout). `nil` otherwise. It is the time `finishSession(_:endingAt: .lastCompletedSet)` records.
    func suggestedEnd(for session: Session) -> Date? {
        guard session.isActive, let completion = lastCompletionTime(of: session) else { return nil }
        let timestamp = now()
        guard timestamp.timeIntervalSince(completion) > Self.forgottenSessionThreshold else { return nil }
        return endTime(of: session, at: completion, now: timestamp)
    }

    /// Ends the session, now or when its last set was completed. The end is never before the start
    /// nor after now. Sets that were not completed stay recorded as not done.
    /// A session without any completed set cannot be finished (it must be discarded instead).
    func finishSession(_ session: Session, endingAt end: SessionEnd = .now) throws {
        guard session.isActive else { throw SessionError.sessionNotActive }
        let hasCompletedSet = session.exercises.contains { performed in
            performed.setLogs.contains(where: \.isCompleted)
        }
        guard hasCompletedSet else { throw SessionError.noCompletedSets }

        let timestamp = now()
        // A completed set always has its completion time; should one ever lack it, the session ends now.
        let requested = switch end {
        case .now: timestamp
        case .lastCompletedSet: lastCompletionTime(of: session) ?? timestamp
        }
        session.endedAt = endTime(of: session, at: requested, now: timestamp)
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
        var descriptor = Self.activeSessionsDescriptor
        descriptor.fetchLimit = 1
        guard try context.fetchCount(descriptor) == 0 else { throw SessionError.activeSessionExists }
    }

    /// A new, not completed working set: the load and targets of `previous` when given, otherwise empty.
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

    /// When the most recently completed set of the session was completed; `nil` without one.
    private func lastCompletionTime(of session: Session) -> Date? {
        session.exercises.flatMap(\.setLogs).compactMap { $0.isCompleted ? $0.completedAt : nil }.max()
    }

    /// `date` kept between the start of the session and now; the start when the clock is behind it.
    private func endTime(of session: Session, at date: Date, now timestamp: Date) -> Date {
        min(max(date, session.startedAt), max(timestamp, session.startedAt))
    }

    private func activeSession(of log: SetLog) throws -> Session {
        guard let session = log.sessionExercise?.session, session.isActive else {
            throw SessionError.sessionNotActive
        }
        return session
    }
}
